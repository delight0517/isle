import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/env.dart';
import '../../../core/utils/url_parser.dart';
import '../../../shared/widgets/isle_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/archive_provider.dart';

class ArchiveInputScreen extends ConsumerStatefulWidget {
  /// 공유 인텐트·딥링크로 전달된 초기 URL
  final String? initialUrl;
  const ArchiveInputScreen({super.key, this.initialUrl});

  @override
  ConsumerState<ArchiveInputScreen> createState() => _ArchiveInputScreenState();
}

class _ArchiveInputScreenState extends ConsumerState<ArchiveInputScreen> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String? _thumb;
  bool _fetching = false;
  bool _saving = false;
  bool _autoFetchedInitial = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUrl;
    if (u != null && u.isNotEmpty) {
      _urlCtrl.text = u;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoFetchedInitial) return;
      final raw = widget.initialUrl?.trim() ?? '';
      if (raw.isEmpty || !raw.startsWith('http')) return;
      _autoFetchedInitial = true;
      _fetchMeta();
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMeta() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _fetching = true);
    try {
      final meta = await UrlParser.fetchMeta(url);
      setState(() {
        _titleCtrl.text = meta.title;
        _thumb = meta.thumbnailUrl;
      });
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    if (url.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL과 제목을 확인해 주세요.')),
      );
      return;
    }
    if (!Env.isSupabaseConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase가 설정되지 않아 저장할 수 없습니다.')),
      );
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(archiveRepoProvider).insertManualArchive(
            userId: user.id,
            url: url,
            title: title,
            thumbnailUrl: _thumb,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('아카이브에 저장했습니다.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialUrl?.trim();
    final fromShare = initial != null && initial.isNotEmpty && initial.startsWith('http');
    return Scaffold(
      appBar: const IsleAppBar(title: 'URL로 아카이브'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            fromShare
                ? '공유된 링크로 미리보기를 불러왔습니다. 제목을 확인한 뒤 저장하세요.'
                : 'YouTube·브런치·기사 URL을 붙여넣고 미리보기 후 저장하세요.',
            style: IsleText.body(color: IsleColors.muted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _fetching ? null : _fetchMeta,
                child: _fetching
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('미리보기'),
              ),
            ],
          ),
          if (_thumb != null && _thumb!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: _thumb!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: IsleColors.ocean100),
                  errorWidget: (_, __, ___) => Container(
                    color: IsleColors.ocean100,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, color: IsleColors.muted),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('제목', style: IsleText.caption(color: IsleColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: IsleText.body(),
            maxLines: 3,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: IsleColors.ocean500),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('저장', style: IsleText.subtitle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
