import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isle/core/platform/blue_cloud_account_service.dart';
import 'package:isle/core/platform/moa_four_vpn_rules_service.dart';

void main() {
  late Directory directory;
  final now = DateTime.utc(2026, 10, 12, 1);
  Map<String, dynamic> document({
    String? generatedAt,
    bool enabled = true,
    List<String> domains = const ['example.com'],
    List<String> parts = const ['/blocked-path'],
    List<String> exceptions = const ['safe.example.com'],
  }) =>
      {
        'schemaVersion': 1,
        '_rev': 4,
        'source': '4vpn-mac',
        'generatedAt': generatedAt ?? now.toIso8601String(),
        'timeZone': 'Asia/Seoul',
        'systemBlockEnabled': enabled,
        'blockedDomains': domains,
        'blockedUrlParts': parts,
        'exceptions': exceptions,
        'blockedVideos': <String>[],
        'blockedChannels': <String>[],
        'blockedKeywords': <String>[],
        'rules': <Map<String, dynamic>>[
          {
            'id': 'rule-1',
            'pattern': 'example.com',
            'kind': 'host',
            'enabled': true,
            'scheduleId': 'schedule-1',
          },
        ],
        'schedules': <Map<String, dynamic>>[
          {
            'id': 'schedule-1',
            'name': 'Night',
            'enabled': true,
            'blockAlways': false,
            'slotsJSON': '[]',
            'calendarSlotsJSON': '[]',
            'dailyCapMinutes': null,
            'usageBudgetPolicyJSON': '{}',
          },
        ],
      };

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = Directory.systemTemp.createTempSync('moa_four_vpn_rules_test');
    Hive.init(directory.path);
    await Hive.openBox<String>('isle_cache');
  });

  setUp(() async {
    await Hive.box<String>('isle_cache').clear();
    await MoaFourVpnRulesService.setEnabled(false);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    directory.deleteSync(recursive: true);
  });

  test('blocks matching host suffix and URL fragment with host exceptions', () {
    final rules = MoaFourVpnRulesSnapshot.parse(document(), now: now)!;
    expect(rules.revision, 4);
    expect(rules.timeZone, 'Asia/Seoul');
    expect(rules.rules.single['scheduleId'], 'schedule-1');
    expect(rules.schedules.single['name'], 'Night');
    expect(rules.blocksUrl('https://shop.example.com/item'), isTrue);
    expect(rules.blocksUrl('https://other.net/blocked-path?q=1'), isTrue);
    expect(rules.blocksUrl('https://safe.example.com/item'), isFalse);
    expect(rules.blocksUrl('https://notexample.com/item'), isFalse);
  });

  test('fails open for disabled, stale, future, or unsupported snapshots', () {
    expect(
        MoaFourVpnRulesSnapshot.parse(document(enabled: false), now: now)!
            .blocksUrl('https://example.com'),
        isFalse);
    expect(
        MoaFourVpnRulesSnapshot.parse(
          document(
              generatedAt:
                  now.subtract(const Duration(minutes: 4)).toIso8601String()),
          now: now,
        ),
        isNull);
    expect(
        MoaFourVpnRulesSnapshot.parse(
          document(
              generatedAt:
                  now.add(const Duration(minutes: 2)).toIso8601String()),
          now: now,
        ),
        isNull);
    expect(
        MoaFourVpnRulesSnapshot.parse({...document(), 'schemaVersion': 2},
            now: now),
        isNull);
    expect(MoaFourVpnRulesSnapshot.parse({...document(), '_rev': 0}, now: now),
        isNull);
    expect(
        MoaFourVpnRulesSnapshot.parse({...document(), 'blockedDomains': 'bad'},
            now: now),
        isNull);
    expect(
      MoaFourVpnRulesSnapshot.parse({
        ...document(),
        'schedules': <Object>['bad']
      }, now: now),
      isNull,
    );
  });

  test('authenticated refresh keeps the highest cloud revision locally',
      () async {
    final generatedAt = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> responseFor(int revision) => {
          'state': {
            ...document(generatedAt: generatedAt),
            '_rev': revision,
          },
        };
    await MoaFourVpnRulesService.setEnabled(true);

    final newest = BlueCloudAccountService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/cloud-state/fourVpnRules');
        expect(request.headers['authorization'], 'Bearer shared-token');
        return http.Response(jsonEncode(responseFor(4)), 200);
      }),
      readSecret: (_) async => 'shared-token',
    );
    expect(await MoaFourVpnRulesService.refresh(account: newest), isTrue);
    newest.close();
    expect(MoaFourVpnRulesService.current()?.revision, 4);

    final older = BlueCloudAccountService(
      client: MockClient(
          (_) async => http.Response(jsonEncode(responseFor(3)), 200)),
      readSecret: (_) async => 'shared-token',
    );
    expect(await MoaFourVpnRulesService.refresh(account: older), isFalse);
    older.close();
    expect(MoaFourVpnRulesService.current()?.revision, 4);
  });

  test('drops a cached snapshot when BlueCloud account changes or signs out',
      () async {
    final generatedAt = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> responseFor(int revision) => {
          'state': {...document(generatedAt: generatedAt), '_rev': revision},
        };
    String? username = 'alice';
    Future<BlueCloudAccountService> account(int revision) async =>
        BlueCloudAccountService(
          client: MockClient((_) async =>
              http.Response(jsonEncode(responseFor(revision)), 200)),
          readSecret: (key) async => key.endsWith('username')
              ? username
              : 'shared-token',
        );
    await MoaFourVpnRulesService.setEnabled(true);
    final alice = await account(4);
    expect(await MoaFourVpnRulesService.refresh(account: alice), isTrue);
    alice.close();
    expect(MoaFourVpnRulesService.current()?.revision, 4);

    username = 'bob';
    final bob = await account(2);
    expect(await MoaFourVpnRulesService.refresh(account: bob), isTrue);
    bob.close();
    expect(MoaFourVpnRulesService.current()?.revision, 2);

    username = null;
    final signedOut = await account(5);
    expect(await MoaFourVpnRulesService.refresh(account: signedOut), isFalse);
    signedOut.close();
    expect(MoaFourVpnRulesService.current(), isNull);
    expect(Hive.box<String>('isle_cache').get('moa_four_vpn_rules_cache_v1'),
        isNull);
  });
}
