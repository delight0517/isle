import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/guard/isle_content_block_guard.dart';
import '../../core/services/isle_external_launch_guard.dart';
import '../../core/constants/app_typography.dart';
import '../../core/guard/isle_playback_guard.dart';

/// WebView 재생·로드 실패 시 회색 빈 화면 대신 복구 패널
class WebPlaybackRecoveryOverlay extends StatelessWidget {
  const WebPlaybackRecoveryOverlay({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onGoHome,
    this.onSkipRecovery,
    this.onSignIn,
    this.currentUrl,
  });

  final IslePlaybackRecoveryState state;
  final VoidCallback onRetry;
  final VoidCallback onGoHome;
  final VoidCallback? onSkipRecovery;
  final VoidCallback? onSignIn;
  final String? currentUrl;

  Future<void> _openExternal(BuildContext context) async {
    final url = currentUrl?.trim();
    if (url == null || !url.startsWith('http')) return;
    if (IsleContentBlockGuard.denyUrl(url) != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(IsleContentBlockGuard.denyUrl(url)!)),
        );
      }
      return;
    }
    await IsleExternalLaunchGuard.launch(context, url);
  }

  bool get _canOpenExternal {
    final url = currentUrl?.trim();
    if (url == null || !url.startsWith('http')) return false;
    return IsleContentBlockGuard.denyUrl(url) == null;
  }

  @override
  Widget build(BuildContext context) {
    if (!state.showOverlay && !state.showRecoveringOverlay) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF0F0F0F),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_disabled, size: 56, color: IsleColors.gold500),
                const SizedBox(height: 16),
                Text(
                  state.phase == IslePlaybackPhase.recovering
                      ? '자동 복구 중'
                      : '재생을 불러오지 못했어요',
                  style: IsleText.subtitle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message ??
                      'YouTube가 일시적으로 막혔을 수 있어요. '
                      '다시 시도하거나 Safari/Chrome에서 열어 보세요.',
                  style: IsleText.body(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (state.phase == IslePlaybackPhase.recovering) ...[
                  const CircularProgressIndicator(color: IsleColors.gold500),
                  const SizedBox(height: 20),
                  if (onSkipRecovery != null)
                    TextButton(
                      onPressed: onSkipRecovery,
                      child: const Text('건너뛰고 계속', style: TextStyle(color: Colors.white70)),
                    ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                    style: FilledButton.styleFrom(
                      backgroundColor: IsleColors.gold500,
                      foregroundColor: IsleColors.ocean900,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  if (state.suggestSignIn && onSignIn != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: onSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Google / YouTube 로그인'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onGoHome,
                    icon: const Icon(Icons.home_outlined, color: Colors.white),
                    label: const Text('홈으로'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_canOpenExternal)
                    TextButton.icon(
                      onPressed: () => _openExternal(context),
                      icon: const Icon(Icons.open_in_browser, color: Colors.white70),
                      label: const Text('브라우저에서 열기', style: TextStyle(color: Colors.white70)),
                    ),
                  if (state.errorCode != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCodeChip(code: state.errorCode!),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCodeChip extends StatelessWidget {
  const _ErrorCodeChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report_outlined, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('오류 코드가 복사되었습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, color: Colors.white38, size: 14),
                  SizedBox(width: 4),
                  Text('복사', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
