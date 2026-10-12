import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/reading_strings.dart';
import '../../../core/reading/reading_account_service.dart';
import '../../../core/youtube/youtube_content_open_guard.dart';

class ReadingTopicsScreen extends StatefulWidget {
  const ReadingTopicsScreen({super.key, this.service});
  final ReadingAccountService? service;
  @override
  State<ReadingTopicsScreen> createState() => _ReadingTopicsScreenState();
}

class _ReadingTopicsScreenState extends State<ReadingTopicsScreen> {
  late final ReadingAccountService _service;
  final _username = TextEditingController(),
      _password = TextEditingController();
  String? _user, _selected, _error;
  bool _busy = true;
  int _epoch = 0;
  List<Map<String, dynamic>> _topics = [], _videos = [];
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ReadingAccountService();
    _load();
  }

  @override
  void dispose() {
    _epoch++;
    _service.close();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _videos = [];
      _selected = null;
    });
    try {
      final user = await _service.username();
      final topics =
          user == null ? <Map<String, dynamic>>[] : await _service.topics();
      if (mounted && epoch == _epoch) {
        setState(() {
          _user = user;
          _topics = topics;
        });
      }
    } catch (error) {
      if (error.toString().contains('login_required')) await _service.logout();
      if (mounted && epoch == _epoch) setState(() => _error = 'unavailable');
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_busy || _username.text.trim().isEmpty || _password.text.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.login(_username.text, _password.text);
      _password.clear();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'login_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(String topic) async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _selected = topic;
      _videos = [];
      _error = null;
    });
    try {
      final videos = await _service.videos(topic);
      if (mounted && epoch == _epoch) setState(() => _videos = videos);
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _error = 'unavailable');
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _react(String id, String reaction) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.react(id, reaction);
      if (!mounted) return;
      final s = ReadingStrings.of(context);
      if (reaction == 'hide') {
        setState(() => _videos.removeWhere((video) => video['id'] == id));
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t('feedback_saved')),
          action: reaction == 'hide'
              ? SnackBarAction(
                  label: s.t('undo'),
                  onPressed: () async {
                    await _react(id, 'neutral');
                    if (mounted && _selected != null) await _choose(_selected!);
                  })
              : null));
    } catch (_) {
      if (mounted) setState(() => _error = 'unavailable');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _lastMentionedLabel(Map<String, dynamic> topic, ReadingStrings s) {
    final raw = topic['lastMentionedAt'];
    if (raw is! String) return null;
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return null;
    final formatted = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return s.t('last_mentioned', args: {'date': formatted});
  }

  void _open(String url, {String? title, String? author}) {
    if (!YoutubeContentOpenGuard.showDenialOrAllow(context,
        url: url, videoTitle: title, channelName: author)) {
      return;
    }
    context.push('/youtube/browser?url=${Uri.encodeComponent(url)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ReadingStrings.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(s.t('title'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(s.t('intro')),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.t(_error!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_user == null) ...[
            TextField(
                controller: _username,
                decoration: InputDecoration(labelText: s.t('username')),
                autofillHints: const [AutofillHints.username]),
            TextField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: s.t('password')),
                autofillHints: const [AutofillHints.password]),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ? null : _login, child: Text(s.t('login'))),
          ] else ...[
            Text(s.t('account', args: {'user': _user!})),
            Wrap(spacing: 12, children: [
              TextButton(
                  onPressed: _busy ? null : _load, child: Text(s.t('refresh'))),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          ++_epoch;
                          await _service.logout();
                          if (mounted) {
                            setState(() {
                              _user = null;
                              _topics = [];
                              _videos = [];
                              _selected = null;
                              _error = null;
                            });
                          }
                        },
                  child: Text(s.t('logout'))),
            ]),
            const Divider(height: 36),
            Text(s.t('media_recommendations'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_topics.isEmpty && !_busy) Text(s.t('no_topics')),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _topics.map((topic) {
                  final lastMentioned = _lastMentionedLabel(topic, s);
                  return ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topic['topic'] as String),
                        if (lastMentioned != null)
                          Text(lastMentioned,
                              style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                    selected: _selected == topic['topic'],
                    onSelected:
                        _busy ? null : (_) => _choose(topic['topic'] as String),
                  );
                }).toList()),
            const SizedBox(height: 20),
            if (_selected != null) ...[
              Text(_selected!, style: Theme.of(context).textTheme.titleLarge),
              Text(s.t('saved_sources'),
                  style: Theme.of(context).textTheme.bodySmall),
              if (_videos.isEmpty && !_busy)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.t('no_videos'))),
              for (final video in _videos)
                Card(
                    child: ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(video['title'] as String),
                        trailing: PopupMenuButton<String>(
                            enabled: !_busy,
                            onSelected: (reaction) =>
                                _react(video['id'] as String, reaction),
                            itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'favorite',
                                      child: Text(s.t('favorite'))),
                                  PopupMenuItem(
                                      value: 'hide', child: Text(s.t('hide')))
                                ]),
                        subtitle: Text(video['author']?.toString() ?? ''),
                        onTap: () => _open(video['url'] as String,
                            title: video['title'] as String,
                            author: video['author']?.toString()))),
              OutlinedButton.icon(
                  onPressed: () => _open(Uri.https('www.youtube.com',
                      '/results', {'search_query': _selected!}).toString()),
                  icon: const Icon(Icons.search),
                  label: Text(s.t('search'))),
            ],
          ],
        ]));
  }
}
