import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isle/core/platform/blue_cloud_account_service.dart';

void main() {
  test('reports secure storage failures without leaking platform details',
      () async {
    final service = BlueCloudAccountService(
      client: MockClient((_) async => http.Response('{}', 200)),
      readSecret: (_) async => throw StateError('keychain detail'),
    );

    await expectLater(
      service.username(),
      throwsA(isA<BlueCloudAccountException>().having(
        (error) => error.code,
        'code',
        'secure_storage',
      )),
    );
  });

  test('logs in with the shared account API and stores only token and username',
      () async {
    final secrets = <String, String>{};
    late http.Request captured;
    final service = BlueCloudAccountService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'token': 'test-token',
            'user': {'username': 'tester'}
          }),
          200,
        );
      }),
      readSecret: (key) async => secrets[key],
      writeSecret: (key, value) async => secrets[key] = value,
      deleteSecret: (key) async => secrets.remove(key),
    );

    await service.login(username: ' tester ', password: 'test-password');

    expect(captured.url.path, '/api/auth/login');
    expect(captured.headers['x-cloud-app'], 'isle');
    expect(jsonDecode(captured.body), {
      'username': 'tester',
      'password': 'test-password',
    });
    expect(await service.username(), 'tester');
    expect(await service.isLoggedIn, isTrue);
    expect(secrets.values, contains('test-token'));
    expect(secrets.values, isNot(contains('test-password')));
  });

  test('Google callback is verified as a BlueCloud user before storing token',
      () async {
    final secrets = <String, String>{};
    late Uri authUrl;
    late http.Request request;
    final service = BlueCloudAccountService(
      client: MockClient((value) async {
        request = value;
        return http.Response(jsonEncode({'username': 'bluecloud-user'}), 200);
      }),
      googleAuth: (url) async {
        authUrl = url;
        return {'token': 'bluecloud-token'};
      },
      readSecret: (key) async => secrets[key],
      writeSecret: (key, value) async => secrets[key] = value,
    );

    await service.loginWithGoogle();

    expect(authUrl.host, 'brainwire-f2gf.onrender.com');
    expect(authUrl.path, '/cloud.html');
    expect(authUrl.queryParameters['redirect_scheme'], 'moa');
    expect(request.url.path, '/api/auth/me');
    expect(request.headers['authorization'], 'Bearer bluecloud-token');
    expect(request.headers['x-cloud-app'], 'isle');
    expect(await service.username(), 'bluecloud-user');
    expect(await service.isLoggedIn, isTrue);
    expect(secrets.values, contains('bluecloud-token'));
  });

  test('does not store a Google callback token rejected by BlueCloud',
      () async {
    final secrets = <String, String>{};
    final service = BlueCloudAccountService(
      client: MockClient((_) async => http.Response('{}', 401)),
      googleAuth: (_) async => {'token': 'expired-token'},
      readSecret: (key) async => secrets[key],
      writeSecret: (key, value) async => secrets[key] = value,
    );

    await expectLater(
      service.loginWithGoogle(),
      throwsA(isA<BlueCloudAccountException>().having(
        (error) => error.code,
        'code',
        'credentials',
      )),
    );
    expect(secrets, isEmpty);
  });

  test('reads Pomodoro state with bearer auth and never sends a write',
      () async {
    final secrets = <String, String>{
      'moa_bluecloud_token': 'test-token',
    };
    late http.Request captured;
    final service = BlueCloudAccountService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'state': {
              'pomodoroCloud': {
                'lockSchedule': [
                  {'enabled': true, 'startMin': 1320, 'endMin': 420},
                ],
              },
            },
          }),
          200,
        );
      }),
      readSecret: (key) async => secrets[key],
      writeSecret: (key, value) async => secrets[key] = value,
      deleteSecret: (key) async => secrets.remove(key),
    );

    final snapshot = await service.fetchPomodoroSnapshot();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/cloud-state/pomodoroCloud');
    expect(captured.headers['authorization'], 'Bearer test-token');
    expect(snapshot['lockSchedule'], isA<List>());
    expect(secrets['moa_bluecloud_token'], 'test-token');
  });

  test('reads the authenticated Auto Pomodoro wake slot', () async {
    final service = BlueCloudAccountService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/cloud-state/pomodoroWake');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.headers['x-cloud-app'], 'isle');
        return http.Response(
          jsonEncode({
            'state': {
              'wakeEvent': {
                'id': 'wake-1',
                'source': 'user-confirmed',
                'wakeAt': 1791692400000,
              },
            },
          }),
          200,
        );
      }),
      readSecret: (key) async =>
          key == 'moa_bluecloud_token' ? 'test-token' : null,
    );

    expect((await service.fetchPomodoroWakeEvent())['wakeEvent'], isA<Map>());
  });

  test('reads 4VPN rules with the shared bearer token and performs no write',
      () async {
    final secrets = <String, String>{
      'moa_bluecloud_token': 'test-token',
      'moa_bluecloud_username': 'tester',
    };
    late http.Request captured;
    final service = BlueCloudAccountService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'state': {
              'schemaVersion': 1,
              'source': '4vpn-mac',
              'generatedAt': '2026-10-12T01:00:00Z',
            },
          }),
          200,
        );
      }),
      readSecret: (key) async => secrets[key],
      deleteSecret: (key) async => secrets.remove(key),
    );

    final snapshot = await service.fetchFourVpnRulesSnapshot();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/cloud-state/fourVpnRules');
    expect(captured.headers['authorization'], 'Bearer test-token');
    expect(captured.headers['x-cloud-app'], 'isle');
    expect(snapshot['source'], '4vpn-mac');
    expect(secrets['moa_bluecloud_token'], 'test-token');
  });

  test('clears an expired shared session when 4VPN rules return 401', () async {
    final secrets = <String, String>{
      'moa_bluecloud_token': 'expired-token',
      'moa_bluecloud_username': 'tester',
    };
    final service = BlueCloudAccountService(
      client: MockClient((_) async => http.Response('{}', 401)),
      readSecret: (key) async => secrets[key],
      deleteSecret: (key) async => secrets.remove(key),
    );

    await expectLater(
      service.fetchFourVpnRulesSnapshot(),
      throwsA(isA<BlueCloudAccountException>().having(
        (error) => error.code,
        'code',
        'login_required',
      )),
    );
    expect(secrets, isEmpty);
  });
}
