// Web Deploy Manager — 인앱 자체 업데이트 (Isle)
// catalog/live/isle.json 폴링 · 플랫폼별 설치

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 원격 catalog/live/{id}.json 과 비교해 업데이트 설치.
class WdmAppUpdater extends ChangeNotifier {
  WdmAppUpdater({
    required this.appId,
    required this.catalogBaseUrl,
    this.checkInterval = const Duration(hours: 6),
  });

  final String appId;
  final String catalogBaseUrl;
  final Duration checkInterval;

  bool _checking = false;
  bool _installing = false;
  WdmLiveManifest? _remote;
  PackageInfo? _local;
  String? _error;
  DateTime? _lastCheckAt;

  bool get isChecking => _checking;
  bool get isInstalling => _installing;
  String? get error => _error;
  WdmLiveManifest? get remote => _remote;
  PackageInfo? get local => _local;
  DateTime? get lastCheckAt => _lastCheckAt;

  bool get hasUpdate {
    final r = _remote;
    final l = _local;
    if (r == null || l == null) return false;
    return WdmVersion.compare(
          localBuild: _localBuild(l),
          localSemver: l.version,
          remoteBuild: r.build,
          remoteSemver: r.version,
        ) <
        0;
  }

  String get manifestUrl {
    final base = catalogBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/catalog/live/$appId.json';
  }

  int _localBuild(PackageInfo info) {
    final raw = info.buildNumber.trim();
    return int.tryParse(raw) ?? 0;
  }

  bool shouldSkipBackgroundCheck() {
    final last = _lastCheckAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < checkInterval;
  }

  /// 인터넷에서 최신 manifest 확인.
  Future<bool> checkNow({bool force = false}) async {
    if (_checking) return hasUpdate;
    if (!force && shouldSkipBackgroundCheck() && _remote != null) {
      return hasUpdate;
    }
    _checking = true;
    _error = null;
    notifyListeners();
    try {
      _local = await PackageInfo.fromPlatform();
      final res = await http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      _remote = WdmLiveManifest.fromJson(json);
      _lastCheckAt = DateTime.now();
      return hasUpdate;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  String? downloadUrlForCurrentPlatform() {
    final r = _remote;
    if (r == null) return null;
    if (Platform.isAndroid && r.downloads['android']?.isNotEmpty == true) {
      return r.downloads['android'];
    }
    if (Platform.isIOS && r.downloads['ios']?.isNotEmpty == true) {
      return r.downloads['ios'];
    }
    if (Platform.isWindows && r.downloads['windows']?.isNotEmpty == true) {
      return r.downloads['windows'];
    }
    if (Platform.isMacOS && r.downloads['macos']?.isNotEmpty == true) {
      return r.downloads['macos'];
    }
    if (Platform.isLinux && r.downloads['linux']?.isNotEmpty == true) {
      return r.downloads['linux'];
    }
    return r.downloads.values.cast<String?>().firstWhere(
          (u) => u != null && u.trim().isNotEmpty,
          orElse: () => null,
        );
  }

  /// 한 번 탭으로 업데이트 (플랫폼별).
  Future<bool> installUpdate() async {
    final url = downloadUrlForCurrentPlatform();
    if (url == null || url.trim().isEmpty) {
      _error = '이 플랫폼용 다운로드 링크가 없습니다.';
      notifyListeners();
      return false;
    }
    if (_installing) return false;
    _installing = true;
    _error = null;
    notifyListeners();
    try {
      final lower = url.toLowerCase();
      if (Platform.isAndroid && lower.endsWith('.apk')) {
        return await _downloadAndOpenFile(url, suffix: '.apk');
      }
      if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
          _isDirectInstallerUrl(lower)) {
        return await _downloadAndOpenFile(url, suffix: _installerSuffix(lower));
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('브라우저를 열 수 없습니다');
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  static bool _isDirectInstallerUrl(String lower) {
    return lower.endsWith('.exe') ||
        lower.endsWith('.msi') ||
        lower.endsWith('.dmg') ||
        lower.endsWith('.pkg') ||
        lower.endsWith('.deb') ||
        lower.endsWith('.appimage');
  }

  static String _installerSuffix(String lower) {
    for (final ext in ['.appimage', '.msi', '.exe', '.dmg', '.pkg', '.deb']) {
      if (lower.endsWith(ext)) return ext;
    }
    return '.bin';
  }

  Future<bool> _downloadAndOpenFile(String url, {required String suffix}) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 10));
    if (res.statusCode != 200) {
      throw HttpException('다운로드 실패 HTTP ${res.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/wdm_update_$appId$suffix');
    await file.writeAsBytes(res.bodyBytes, flush: true);
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

  /// Material 다이얼로그 — 새 버전 있으면 표시.
  Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
    final found = await checkNow();
    if (!context.mounted || !found) return;
    await _showUpdateDialog(context);
  }

  Future<void> showUpdateDialog(BuildContext context) async {
    if (!hasUpdate) return;
    await _showUpdateDialog(context);
  }

  Future<void> _showUpdateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !kReleaseMode,
      builder: (ctx) => AlertDialog(
        title: const Text('업데이트 가능'),
        content: Text(
          '새 버전 ${_remote?.versionLabel ?? ''} 이(가) 있습니다.\n'
          '지금 ${_local?.version ?? ''}+${_local?.buildNumber ?? ''} → 업데이트할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await installUpdate();
            },
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }
}

class WdmLiveManifest {
  WdmLiveManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.build,
    required this.versionLabel,
    required this.downloads,
  });

  final String id;
  final String name;
  final String version;
  final int build;
  final String versionLabel;
  final Map<String, String> downloads;

  factory WdmLiveManifest.fromJson(Map<String, dynamic> json) {
    final raw = json['downloads'];
    final map = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          map[k.toString()] = v.toString().trim();
        }
      });
    }
    return WdmLiveManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      build: json['build'] as int? ?? 0,
      versionLabel: json['versionLabel'] as String? ?? '',
      downloads: map,
    );
  }
}

abstract final class WdmVersion {
  /// 음수 = remote가 더 새김, 0 = 같음, 양수 = local이 더 새김
  static int compare({
    required int localBuild,
    required String localSemver,
    required int remoteBuild,
    required String remoteSemver,
  }) {
    if (localBuild != remoteBuild) return localBuild.compareTo(remoteBuild);
    return _compareSemver(localSemver, remoteSemver);
  }

  static int _compareSemver(String a, String b) {
    final pa = _semver(a);
    final pb = _semver(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static List<int> _semver(String v) {
    return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }
}
