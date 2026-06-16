import 'package:flutter/material.dart';

import '../../../../core/block_schedule/quick_block_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/platform/isle_apple_platform.dart';

/// 6VPN Quick Block — 1·3·6·11·24시간 (조기 해제 없음, 세션 만료까지).
class QuickBlockBar extends StatefulWidget {
  const QuickBlockBar({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<QuickBlockBar> createState() => _QuickBlockBarState();
}

class _QuickBlockBarState extends State<QuickBlockBar> {
  bool _busy = false;
  List<QuickBlockSession> _active = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await QuickBlockService.ensureOpen();
    await QuickBlockService.pruneExpired();
    if (!mounted) return;
    setState(() => _active = QuickBlockService.activeSessions());
  }

  Future<void> _start(int hours) async {
    setState(() => _busy = true);
    await QuickBlockService.start(hours: hours);
    await _reload();
    widget.onChanged?.call();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$hours시간 빠른 차단이 시작됐어요. 만료 전까지 해제할 수 없어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!IsleApplePlatform.isScreenTimeHost) return const SizedBox.shrink();

    return Card(
      color: IsleColors.ocean100.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('빠른 차단', style: IsleText.subtitle(color: IsleColors.ocean900)),
            Text(
              '지금부터 N시간 — 스케줄·Screen Time 즉시 ON (조기 취소 없음)',
              style: IsleText.caption(color: IsleColors.muted),
            ),
            if (_active.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._active.map((s) {
                final left = s.endsAt.difference(DateTime.now());
                final h = left.inHours;
                final m = left.inMinutes % 60;
                return Text(
                  '진행 중 · ${s.hours}h 세션 · 남은 $h시간 $m분',
                  style: IsleText.body(color: IsleColors.ocean700),
                );
              }),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in const [1, 3, 6, 11, 24])
                  ActionChip(
                    label: Text('${h}h'),
                    onPressed: _busy || _active.isNotEmpty ? null : () => _start(h),
                  ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
