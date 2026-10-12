import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BlueCloudAccountException implements Exception {
  const BlueCloudAccountException(this.code);
  final String code;
}

/// MOA sign-in for the shared BlueCloud account used by Auto Pomodoro.
/// Passwords are sent only for the login request and are never persisted.
class BlueCloudAccountService {
  BlueCloudAccountService({
    http.Client? client,
    FlutterSecureStorage? storage,
    Future<String?> Function(String key)? readSecret,
    Future<void> Function(String key, String value)? writeSecret,
    Future<void> Function(String key)? deleteSecret,
    Future<Map<String, dynamic>?> Function(Uri url)? googleAuth,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _readSecret = readSecret,
        _writeSecret = writeSecret,
        _deleteSecret = deleteSecret,
        _googleAuth = googleAuth;

  static const apiBase = 'https://brainwire-f2gf.onrender.com';
  static const _tokenKey = 'moa_bluecloud_token';
  static const _usernameKey = 'moa_bluecloud_username';
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<String?> Function(String key)? _readSecret;
  final Future<void> Function(String key, String value)? _writeSecret;
  final Future<void> Function(String key)? _deleteSecret;
  final Future<Map<String, dynamic>?> Function(Uri url)? _googleAuth;
  static const _googleAuthChannel =
      MethodChannel('com.isle.app/bluecloud_auth');

  void close() => _client.close();

  Future<String?> _read(String key) async {
    try {
      return await (_readSecret?.call(key) ?? _storage.read(key: key));
    } catch (_) {
      throw const BlueCloudAccountException('secure_storage');
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await (_writeSecret?.call(key, value) ??
          _storage.write(key: key, value: value));
    } catch (_) {
      throw const BlueCloudAccountException('secure_storage');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await (_deleteSecret?.call(key) ?? _storage.delete(key: key));
    } catch (_) {
      throw const BlueCloudAccountException('secure_storage');
    }
  }

  Future<String?> username() => _read(_usernameKey);
  Future<bool> get isLoggedIn async =>
      (await _read(_tokenKey))?.isNotEmpty == true;

  Future<void> login(
      {required String username, required String password}) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$apiBase/api/auth/login'),
            headers: const {
              'Content-Type': 'application/json',
              'x-cloud-app': 'isle',
            },
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 50));
    } catch (_) {
      throw const BlueCloudAccountException('network');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BlueCloudAccountException('credentials');
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['token'];
      final user = body['user'];
      final signedInName = user is Map ? user['username'] : null;
      if (token is! String ||
          token.isEmpty ||
          signedInName is! String ||
          signedInName.isEmpty) {
        throw const BlueCloudAccountException('response');
      }
      await _write(_tokenKey, token);
      await _write(_usernameKey, signedInName);
    } on BlueCloudAccountException {
      rethrow;
    } catch (_) {
      throw const BlueCloudAccountException('response');
    }
  }

  /// Uses Brainwire's first-party Google→BlueCloud sign-in and stores only the
  /// resulting BlueCloud bearer token and canonical username.
  Future<void> loginWithGoogle() async {
    final url = Uri.https(Uri.parse(apiBase).host, '/cloud.html', {
      'app': 'isle',
      'redirect_scheme': 'moa',
    });
    Map<String, dynamic>? response;
    try {
      response = await (_googleAuth?.call(url) ??
          _googleAuthChannel.invokeMapMethod<String, dynamic>('signIn', {
            'url': url.toString(),
          }));
    } on PlatformException catch (error) {
      throw BlueCloudAccountException(
        error.code == 'cancelled' ? 'google_cancelled' : 'google_auth',
      );
    } catch (_) {
      throw const BlueCloudAccountException('google_auth');
    }
    final token = response?['token'];
    if (token is! String || token.isEmpty) {
      throw const BlueCloudAccountException('google_auth');
    }

    late final http.Response verified;
    try {
      verified = await _client.get(
        Uri.parse('$apiBase/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-cloud-app': 'isle',
        },
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const BlueCloudAccountException('network');
    }
    if (verified.statusCode == 401) {
      throw const BlueCloudAccountException('credentials');
    }
    if (verified.statusCode < 200 || verified.statusCode >= 300) {
      throw const BlueCloudAccountException('unavailable');
    }
    try {
      final user = jsonDecode(verified.body) as Map<String, dynamic>;
      final signedInName = user['username'];
      if (signedInName is! String || signedInName.isEmpty) {
        throw const BlueCloudAccountException('response');
      }
      await _write(_usernameKey, signedInName);
      try {
        await _write(_tokenKey, token);
      } catch (_) {
        await _delete(_usernameKey);
        rethrow;
      }
    } on BlueCloudAccountException {
      rethrow;
    } catch (_) {
      throw const BlueCloudAccountException('response');
    }
  }

  Future<void> logout() async {
    await _delete(_tokenKey);
    await _delete(_usernameKey);
  }

  /// Reads Auto Pomodoro's read-only app snapshot. MOA never writes to it.
  Future<Map<String, dynamic>> fetchPomodoroSnapshot() async {
    final token = await _read(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const BlueCloudAccountException('login_required');
    }
    late final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$apiBase/api/cloud-state/pomodoroCloud'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-cloud-app': 'isle',
        },
      ).timeout(const Duration(seconds: 50));
    } catch (_) {
      throw const BlueCloudAccountException('network');
    }
    if (response.statusCode == 401) {
      await logout();
      throw const BlueCloudAccountException('login_required');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BlueCloudAccountException('unavailable');
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final state = body['state'];
      if (state is! Map) throw const BlueCloudAccountException('no_snapshot');
      final root = Map<String, dynamic>.from(state);
      final candidates = [
        root['pomodoroCloud'],
        root['macSnapshot'],
        root['windowsSnapshot'],
        root['winSnapshot'],
        root['pcSnapshot'],
        root['iosSnapshot'],
        root['snapshot'],
      ];
      for (final candidate in candidates) {
        if (candidate is Map) {
          final snapshot = Map<String, dynamic>.from(candidate);
          if (snapshot['lockSchedule'] is List ||
              (snapshot['settings'] is Map &&
                  (snapshot['settings'] as Map)['lockSchedule'] is List)) {
            return snapshot;
          }
        }
      }
      if (root['lockSchedule'] is List) return root;
      throw const BlueCloudAccountException('no_snapshot');
    } on BlueCloudAccountException {
      rethrow;
    } catch (_) {
      throw const BlueCloudAccountException('response');
    }
  }

  /// Reads Auto Pomodoro's current authenticated wake/sleep event. This slot is
  /// separate from `pomodoroCloud`; MOA only reads it and never writes to it.
  Future<Map<String, dynamic>> fetchPomodoroWakeEvent() async {
    final token = await _read(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const BlueCloudAccountException('login_required');
    }
    late final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$apiBase/api/cloud-state/pomodoroWake'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-cloud-app': 'isle',
        },
      ).timeout(const Duration(seconds: 50));
    } catch (_) {
      throw const BlueCloudAccountException('network');
    }
    if (response.statusCode == 401) {
      await logout();
      throw const BlueCloudAccountException('login_required');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BlueCloudAccountException('unavailable');
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final state = body['state'];
      if (state == null) return <String, dynamic>{};
      if (state is! Map) throw const BlueCloudAccountException('response');
      return Map<String, dynamic>.from(state);
    } on BlueCloudAccountException {
      rethrow;
    } catch (_) {
      throw const BlueCloudAccountException('response');
    }
  }

  /// Read the opt-in 4VPN Mac snapshot. MOA does not write into the 4VPN slot.
  Future<Map<String, dynamic>> fetchFourVpnRulesSnapshot() async {
    final token = await _read(_tokenKey);
    if (token == null || token.isEmpty) {
      throw const BlueCloudAccountException('login_required');
    }
    late final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$apiBase/api/cloud-state/fourVpnRules'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-cloud-app': 'isle',
        },
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const BlueCloudAccountException('network');
    }
    if (response.statusCode == 401) {
      await logout();
      throw const BlueCloudAccountException('login_required');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BlueCloudAccountException('unavailable');
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final state = body['state'];
      if (state == null) return <String, dynamic>{};
      if (state is! Map) throw const BlueCloudAccountException('response');
      return Map<String, dynamic>.from(state);
    } on BlueCloudAccountException {
      rethrow;
    } catch (_) {
      throw const BlueCloudAccountException('response');
    }
  }
}
