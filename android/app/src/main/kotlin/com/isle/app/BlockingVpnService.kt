package com.isle.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

/// 웹사이트 시스템 차단 — 로컬 VpnService DNS sinkhole (전 브라우저 적용, 루트 불필요).
///
/// iOS Safari Content Blocker 의 Android 등가. 가상 DNS 서버(10.111.0.1)로 향하는
/// DNS 질의만 tun 으로 라우팅해 가로채고, 차단 도메인이면 NXDOMAIN, 아니면 업스트림(8.8.8.8)에
/// 그대로 전달한다. **fail-open**: 파싱/전달 실패 시 차단하지 않음 → 정상 트래픽은 절대 끊기지 않음.
///
/// ⚠️ 실기기 검증 필요(베타). DoH/DoT 를 쓰는 앱·브라우저는 우회 가능(접근성 차단과 동일한 best-effort).
class BlockingVpnService : VpnService() {
    private var vpn: ParcelFileDescriptor? = null
    private var worker: Thread? = null
    @Volatile private var running = false
    private var blocked: Set<String> = emptySet()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopVpn()
            return START_NOT_STICKY
        }
        blocked = BlockingStore.webTargetSet(this)
        if (blocked.isEmpty()) {
            stopVpn()
            return START_NOT_STICKY
        }
        startForegroundNotification()
        if (!running) establish()
        return START_STICKY
    }

    private fun establish() {
        try {
            val builder = Builder()
                .setSession("Isle 웹 차단")
                .addAddress(VIRTUAL_CLIENT, 32)
                .addDnsServer(VIRTUAL_DNS)
                .addRoute(VIRTUAL_DNS, 32)
            builder.setBlocking(true)
            // Isle 자신은 VPN 우회 (인앱 WebView 영향 방지).
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {
            }
            val pfd = builder.establish() ?: return
            vpn = pfd
            running = true
            worker = Thread { loop(pfd) }.apply { isDaemon = true; start() }
        } catch (_: Exception) {
            stopVpn()
        }
    }

    private fun loop(pfd: ParcelFileDescriptor) {
        val input = FileInputStream(pfd.fileDescriptor)
        val output = FileOutputStream(pfd.fileDescriptor)
        val buffer = ByteArray(32767)
        while (running) {
            val len = try {
                input.read(buffer)
            } catch (_: Exception) {
                break
            }
            if (len <= 0) continue
            try {
                handlePacket(buffer, len, output)
            } catch (_: Exception) {
                // fail-open: 어떤 오류든 해당 질의만 무시 (정상 트래픽 영향 없음).
            }
        }
    }

    /// IPv4 + UDP/53 만 처리. 그 외는 무시(우리 /32 라우팅이라 DNS 만 도착).
    private fun handlePacket(packet: ByteArray, length: Int, output: FileOutputStream) {
        if (length < 28) return
        val version = (packet[0].toInt() shr 4) and 0xF
        if (version != 4) return
        val ihl = (packet[0].toInt() and 0xF) * 4
        if (ihl < 20 || length < ihl + 8) return
        val protocol = packet[9].toInt() and 0xFF
        if (protocol != 17) return // UDP

        val udpStart = ihl
        val dstPort = ((packet[udpStart + 2].toInt() and 0xFF) shl 8) or (packet[udpStart + 3].toInt() and 0xFF)
        if (dstPort != 53) return

        val dnsStart = udpStart + 8
        val dnsLen = length - dnsStart
        if (dnsLen < 12) return

        val qname = parseQName(packet, dnsStart, length) ?: return
        val isBlocked = blocked.any { domain ->
            qname == domain || qname.endsWith(".$domain")
        }

        if (isBlocked) {
            val resp = buildBlockedResponse(packet, ihl, length) ?: return
            output.write(resp)
            output.flush()
        } else {
            forwardUpstream(packet, ihl, length, output)
        }
    }

    /// DNS 질문 섹션의 QNAME 을 소문자 도메인 문자열로 (예: "www.youtube.com").
    private fun parseQName(packet: ByteArray, dnsStart: Int, length: Int): String? {
        var pos = dnsStart + 12 // header 12바이트 이후 question
        val sb = StringBuilder()
        var guard = 0
        while (pos < length && guard++ < 128) {
            val len = packet[pos].toInt() and 0xFF
            if (len == 0) break
            if (len and 0xC0 != 0) return null // 압축 포인터 — 질의엔 없음
            pos++
            if (pos + len > length) return null
            if (sb.isNotEmpty()) sb.append('.')
            for (i in 0 until len) {
                sb.append((packet[pos + i].toInt() and 0xFF).toChar())
            }
            pos += len
        }
        return if (sb.isEmpty()) null else sb.toString().lowercase()
    }

    /// 차단 응답(NXDOMAIN) 생성 — 주소·포트 스왑, QR=1·RCODE=3, UDP 체크섬 0(IPv4 합법).
    private fun buildBlockedResponse(req: ByteArray, ihl: Int, length: Int): ByteArray? {
        val dnsStart = ihl + 8
        val dnsLen = length - dnsStart
        if (dnsLen < 12) return null
        val out = req.copyOf(length)

        // IP 주소 스왑 (src ↔ dst): 12..15 = src, 16..19 = dst
        for (i in 0 until 4) {
            val t = out[12 + i]; out[12 + i] = out[16 + i]; out[16 + i] = t
        }
        // UDP 포트 스왑: src(ihl..ihl+1) ↔ dst(ihl+2..ihl+3)
        run {
            val a = ihl
            val t0 = out[a]; out[a] = out[a + 2]; out[a + 2] = t0
            val t1 = out[a + 1]; out[a + 1] = out[a + 3]; out[a + 3] = t1
        }
        // DNS flags: QR=1, RA=1, RCODE=3 (NXDOMAIN) → 0x8183
        out[dnsStart + 2] = 0x81.toByte()
        out[dnsStart + 3] = 0x83.toByte()
        // ANCOUNT/NSCOUNT/ARCOUNT = 0 (질문만 echo)
        for (i in 6..11) out[dnsStart + i] = 0
        // UDP 체크섬 0 (IPv4 선택적)
        out[ihl + 6] = 0; out[ihl + 7] = 0
        // IP 헤더 체크섬 재계산
        writeIpChecksum(out, ihl)
        return out
    }

    /// 비차단 질의는 업스트림 DNS 로 전달하고 응답을 앱에게 되돌려줌 (protected 소켓).
    private fun forwardUpstream(req: ByteArray, ihl: Int, length: Int, output: FileOutputStream) {
        val dnsStart = ihl + 8
        val dnsLen = length - dnsStart
        if (dnsLen < 12) return
        val query = req.copyOfRange(dnsStart, length)

        val socket = DatagramSocket()
        try {
            protect(socket)
            socket.soTimeout = 5000
            val upstream = InetAddress.getByName(UPSTREAM_DNS)
            socket.send(DatagramPacket(query, query.size, upstream, 53))
            val respBuf = ByteArray(4096)
            val respPacket = DatagramPacket(respBuf, respBuf.size)
            socket.receive(respPacket)
            val answer = respBuf.copyOf(respPacket.length)
            val out = wrapResponse(req, ihl, answer)
            output.write(out)
            output.flush()
        } catch (_: Exception) {
            // fail-open: 전달 실패 → 무응답(앱이 재시도). 다른 트래픽 영향 없음.
        } finally {
            socket.close()
        }
    }

    /// 업스트림 DNS 응답(answer)을 IPv4/UDP 패킷으로 감싸 앱(원래 src)에게 반환.
    private fun wrapResponse(req: ByteArray, ihl: Int, answer: ByteArray): ByteArray {
        val totalLen = ihl + 8 + answer.size
        val out = ByteArray(totalLen)
        // IP 헤더 복사 후 길이·주소·체크섬 갱신
        System.arraycopy(req, 0, out, 0, ihl)
        out[2] = ((totalLen shr 8) and 0xFF).toByte()
        out[3] = (totalLen and 0xFF).toByte()
        // src ↔ dst 스왑
        for (i in 0 until 4) {
            out[12 + i] = req[16 + i]
            out[16 + i] = req[12 + i]
        }
        // UDP 헤더: 포트 스왑, 길이, 체크섬 0
        val u = ihl
        out[u] = req[u + 2]; out[u + 1] = req[u + 3]   // src port = 원래 dst(53)
        out[u + 2] = req[u]; out[u + 3] = req[u + 1]    // dst port = 원래 src
        val udpLen = 8 + answer.size
        out[u + 4] = ((udpLen shr 8) and 0xFF).toByte()
        out[u + 5] = (udpLen and 0xFF).toByte()
        out[u + 6] = 0; out[u + 7] = 0
        System.arraycopy(answer, 0, out, ihl + 8, answer.size)
        writeIpChecksum(out, ihl)
        return out
    }

    private fun writeIpChecksum(packet: ByteArray, ihl: Int) {
        packet[10] = 0; packet[11] = 0
        var sum = 0L
        var i = 0
        while (i < ihl) {
            val word = ((packet[i].toInt() and 0xFF) shl 8) or (packet[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        while (sum shr 16 != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        val checksum = sum.inv().toInt() and 0xFFFF
        packet[10] = ((checksum shr 8) and 0xFF).toByte()
        packet[11] = (checksum and 0xFF).toByte()
    }

    private fun startForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Isle 웹 차단", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Isle · 웹사이트 차단 켜짐")
            .setContentText("차단 도메인을 필터링하는 중입니다")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun stopVpn() {
        running = false
        try { worker?.interrupt() } catch (_: Exception) {}
        worker = null
        try { vpn?.close() } catch (_: Exception) {}
        vpn = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        try { vpn?.close() } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }

    companion object {
        private const val VIRTUAL_CLIENT = "10.111.0.2"
        private const val VIRTUAL_DNS = "10.111.0.1"
        private const val UPSTREAM_DNS = "8.8.8.8"
        private const val CHANNEL_ID = "isle_web_block"
        private const val NOTIFICATION_ID = 41002
        const val ACTION_STOP = "com.isle.app.STOP_WEB_BLOCK"

        fun start(context: Context) {
            val intent = Intent(context, BlockingVpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, BlockingVpnService::class.java).setAction(ACTION_STOP),
            )
        }
    }
}
