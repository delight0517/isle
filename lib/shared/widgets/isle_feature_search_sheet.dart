import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/navigation/isle_feature_catalog.dart';
import 'isle_sheet.dart';

/// 기능 검색 — 「포모도로」「쇼츠」 등으로 숨은 기능 찾기
Future<void> showIsleFeatureSearch(
  BuildContext context, {
  String initialQuery = '',
}) {
  return showIsleModalSheet<void>(
    context: context,
    builder: (ctx) => _FeatureSearchBody(initialQuery: initialQuery),
  );
}

class _FeatureSearchBody extends StatefulWidget {
  const _FeatureSearchBody({required this.initialQuery});
  final String initialQuery;

  @override
  State<_FeatureSearchBody> createState() => _FeatureSearchBodyState();
}

class _FeatureSearchBodyState extends State<_FeatureSearchBody> {
  late final TextEditingController _ctrl;
  List<IsleFeatureEntry> _hits = const [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _hits = IsleFeatureCatalog.search(widget.initialQuery);
    _ctrl.addListener(_onQuery);
  }

  void _onQuery() {
    setState(() => _hits = IsleFeatureCatalog.search(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onQuery);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('기능 찾기', style: IsleText.subtitle()),
          const SizedBox(height: 4),
          Text(
            '포모도로 · 쇼츠 · 스케줄… 필요한 것만 검색하세요',
            style: IsleText.caption(color: IsleColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '예: 포모도로, 카카오 쇼츠',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 12),
          ..._hits.map((e) => ListTile(
                leading: Text(e.emoji, style: const TextStyle(fontSize: 28)),
                title: Text(e.title, style: IsleText.body()),
                subtitle: Text(e.subtitle, style: IsleText.caption(color: IsleColors.muted)),
                onTap: () {
                  Navigator.pop(context);
                  context.push(e.route);
                },
              )),
          if (_hits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '다른 단어로 검색해 보세요 (휴식, 릴, 차단)',
                style: IsleText.caption(color: IsleColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
