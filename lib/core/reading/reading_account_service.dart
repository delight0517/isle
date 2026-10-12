import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ReadingAccountService {
  ReadingAccountService(
      {http.Client? client,
      Future<String?> Function(String)? read,
      Future<void> Function(String, String)? write,
      Future<void> Function(String)? remove})
      : _client = client ?? http.Client(),
        _read = read ?? ((key) => const FlutterSecureStorage().read(key: key)),
        _write = write ??
            ((key, value) =>
                const FlutterSecureStorage().write(key: key, value: value)),
        _remove =
            remove ?? ((key) => const FlutterSecureStorage().delete(key: key));
  final http.Client _client;
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  final Future<void> Function(String) _remove;
  static const _tokenKey = 'moa_reading_cloud_token',
      _userKey = 'moa_reading_cloud_user';
  static const _base = 'https://brainwire-f2gf.onrender.com';
  void close() => _client.close();
  Future<String?> username() => _read(_userKey);
  Future<void> logout() async {
    await _remove(_tokenKey);
    await _remove(_userKey);
  }

  Future<void> login(String username, String password) async {
    final response = await _client
        .post(Uri.parse('$_base/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body:
                jsonEncode({'username': username.trim(), 'password': password}))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('login_failed');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'], user = data['user']?['username'];
    if (token is! String || token.isEmpty || user is! String || user.isEmpty) {
      throw StateError('login_failed');
    }
    await _write(_tokenKey, token);
    await _write(_userKey, user);
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final token = await _read(_tokenKey);
    if (token == null || token.isEmpty) throw StateError('login_required');
    final response = await _client.get(
        Uri.parse('$_base/api/reading/$path').replace(queryParameters: query),
        headers: {
          'Authorization': 'Bearer $token'
        }).timeout(const Duration(seconds: 20));
    if (await _read(_tokenKey) != token) throw StateError('account_changed');
    if (response.statusCode == 401) throw StateError('login_required');
    if (response.statusCode != 200) throw StateError('unavailable');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> topics() async {
    final body = await _get('topics');
    final values = body['topics'];
    if (values is! List) throw StateError('unavailable');
    return values
        .whereType<Map>()
        .where(
            (v) => v['topic'] is String && (v['topic'] as String).length <= 100)
        .take(20)
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<List<Map<String, dynamic>>> videos(String topic) async {
    if (topic.trim().isEmpty || topic.length > 100) {
      throw StateError('invalid_topic');
    }
    final body = await _get('videos', query: {'topic': topic});
    final values = body['videos'];
    if (values is! List) throw StateError('unavailable');
    return values
        .whereType<Map>()
        .where((v) => safeVideo(v))
        .take(5)
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  Future<void> react(String id, String reaction) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ||
        !['favorite', 'hide', 'neutral'].contains(reaction)) {
      throw StateError('invalid_reaction');
    }
    final token = await _read(_tokenKey);
    final current = await _get('topics');
    if (token == null || await _read(_tokenKey) != token) {
      throw StateError('account_changed');
    }
    final response = await _client
        .post(Uri.parse('$_base/api/reading/video-feedback'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(
                {'rev': current['rev'], 'id': id, 'reaction': reaction}))
        .timeout(const Duration(seconds: 20));
    if (await _read(_tokenKey) != token) throw StateError('account_changed');
    if (response.statusCode != 200) throw StateError('feedback_failed');
    final saved = jsonDecode(response.body) as Map<String, dynamic>;
    if (saved['rev'] != (current['rev'] as int) + 1 ||
        saved['videoFeedback'] is! Map ||
        (reaction == 'neutral'
            ? (saved['videoFeedback'] as Map).containsKey(id)
            : saved['videoFeedback'][id] != reaction)) {
      throw StateError('feedback_failed');
    }
  }

  static bool safeVideo(Map value) {
    final id = value['id'], url = Uri.tryParse(value['url']?.toString() ?? '');
    return id is String &&
        RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) &&
        url != null &&
        url.scheme == 'https' &&
        url.host == 'www.youtube.com' &&
        url.path == '/watch' &&
        url.queryParameters['v'] == id &&
        value['title'] is String;
  }
}
