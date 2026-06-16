import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/youtube/youtube_focus_clipboard.dart';
import '../../../core/youtube/youtube_limit_gate.dart';
import '../../../core/youtube/youtube_focus_time_store.dart';
import '../../../shared/widgets/app_version_badge.dart';
import 'widgets/youtube_focus_home_switch_dialog.dart';

/// 몰입 MVP — 검색창 하나 + 안내 문구
class YoutubeFocusHomeScreen extends StatefulWidget {
  const YoutubeFocusHomeScreen({super.key, this.standalone = false});

  /// `main_youtube_focus.dart` 전용 빌드
  final bool standalone;

  @override
  State<YoutubeFocusHomeScreen> createState() => _YoutubeFocusHomeScreenState();
}

class _YoutubeFocusHomeScreenState extends State<YoutubeFocusHomeScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showYoutubeFocusHomeSwitchDialog(context);
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search() {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    if (!YoutubeLimitGate.guard(context)) return;
    context.push('/youtube-focus/results?q=${Uri.encodeComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final hint = isDark ? Colors.white54 : Colors.black45;
    final fieldBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: widget.standalone
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: fg),
                onPressed: () => context.pop(),
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Isle',
                      style: IsleText.title(color: fg).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '알고리즘 제로',
                      style: IsleText.caption(color: hint),
                    ),
                    const SizedBox(height: 48),
                    Material(
                      elevation: 0,
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(28),
                      child: TextField(
                        controller: _query,
                        focusNode: _focus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        style: IsleText.body(color: fg),
                        decoration: InputDecoration(
                          hintText: '오늘 얻고 싶은 지식은?',
                          hintStyle: IsleText.body(color: hint),
                          prefixIcon: Icon(Icons.search, color: hint),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: IsleSize.minTouchTarget / 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '오늘 당신이 얻고자 하는 지식은 무엇인가요? '
                      '검색어를 입력하면 알고리즘 없이 순수 결과만 보여드립니다.',
                      textAlign: TextAlign.center,
                      style: IsleText.caption(color: hint).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => YoutubeFocusClipboard.pasteAndOpenReadFirst(context),
                      icon: const Icon(Icons.content_paste_go),
                      label: const Text('복사한 URL로 요약 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: fg,
                        side: BorderSide(color: hint),
                        minimumSize: const Size.fromHeight(IsleSize.minTouchTarget),
                      ),
                    ),
                    if (YoutubeFocusTimeStore.todaySavedSeconds > 0) ...[
                      const SizedBox(height: 20),
                      Text(
                        '오늘 아낀 시간 · ${YoutubeFocusTimeStore.formatSavedLabel()}',
                        style: IsleText.caption(color: hint),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: IsleSize.minTouchTarget,
                      child: FilledButton(
                        onPressed: _search,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('검색'),
                      ),
                    ),
                    if (!widget.standalone) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/youtube'),
                        child: Text(
                          '기존 유튜브 허브로',
                          style: IsleText.caption(color: hint),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Positioned(
              right: 8,
              bottom: 8,
              child: AppVersionBadge(),
            ),
            if (widget.standalone)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    tooltip: '설정·차단',
                    icon: Icon(Icons.settings_outlined, color: fg),
                    onPressed: () => context.push('/youtube-focus/more'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
