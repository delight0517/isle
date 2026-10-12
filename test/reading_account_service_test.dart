import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isle/core/reading/reading_account_service.dart';
import 'package:isle/core/localization/reading_strings.dart';
import 'package:isle/features/reading/presentation/reading_topics_screen.dart';

void main() {
  test(
      'existing Cloud login stores token only; topics and safe videos use same account',
      () async {
    final storage = <String, String>{};
    final requests = <http.Request>[];
    final service = ReadingAccountService(
        read: (k) async => storage[k],
        write: (k, v) async {
          storage[k] = v;
        },
        remove: (k) async {
          storage.remove(k);
        },
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/login')) {
            return http.Response(
                '{"token":"fixture-token","user":{"username":"fixture-user"}}',
                200);
          }
          if (r.url.path.endsWith('/topics')) {
            return http.Response(
                '{"rev":1,"topics":[{"topic":"Reread"}]}', 200);
          }
          if (r.url.path.endsWith('/video-feedback')) {
            return http.Response(
                '{"rev":2,"videoFeedback":{"abcdefghijk":"favorite"}}', 200);
          }
          return http.Response(
              jsonEncode({
                'videos': [
                  {
                    'id': 'abcdefghijk',
                    'url': 'https://www.youtube.com/watch?v=abcdefghijk',
                    'title': 'Fixture video'
                  },
                  {
                    'id': 'abcdefghijk',
                    'url': 'https://evil.example/watch?v=abcdefghijk',
                    'title': 'Unsafe'
                  }
                ]
              }),
              200);
        }));
    await service.login('fixture-user', 'fixture-password');
    expect(storage.values, contains('fixture-token'));
    expect(storage.values, isNot(contains('fixture-password')));
    expect((await service.topics()).single['topic'], 'Reread');
    expect((await service.videos('Reread')).single['title'], 'Fixture video');
    expect(requests.last.headers['Authorization'], 'Bearer fixture-token');
    await service.react('abcdefghijk', 'favorite');
    expect(jsonDecode(requests.last.body),
        {'rev': 1, 'id': 'abcdefghijk', 'reaction': 'favorite'});
    await service.logout();
    expect(storage, isEmpty);
    service.close();
  });
  test('account switch during response discards previous account data',
      () async {
    String? token = 'first';
    final service = ReadingAccountService(
        read: (k) async => token,
        client: MockClient((r) async {
          token = 'second';
          return http.Response(
              '{"topics":[{"topic":"private first topic"}]}', 200);
        }));
    await expectLater(service.topics(), throwsStateError);
    service.close();
  });

  testWidgets('MOA topic screen is for media discovery, not reading/PDF',
      (tester) async {
    final service = ReadingAccountService(
      read: (key) async =>
          key == 'moa_reading_cloud_token' ? 'fixture-token' : 'fixture-user',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/topics')) {
          return http.Response(
              '{"rev":1,"topics":[{"topic":"Reread","lastMentionedAt":"2026-10-10T00:00:00Z"}]}',
              200);
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: ReadingTopicsScreen(
        service: service,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Videos for your learning topics'), findsOneWidget);
    expect(find.text('Recommended videos'), findsOneWidget);
    expect(find.textContaining('Discover videos related'), findsOneWidget);
    expect(
        find.byKey(const Key('brainwire-reading-studio-link')), findsNothing);
    expect(find.byKey(const Key('reading-magazine-composer')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Reread'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Last diary entry · 2026-10-10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('all reading UI labels resolve in every supported locale', () {
    for (final lang in ['ko', 'en', 'ja', 'zh', 'he']) {
      final s = ReadingStrings(lang);
      for (final key in [
        'title',
        'intro',
        'media_recommendations',
        'username',
        'password',
        'login',
        'logout',
        'refresh',
        'no_topics',
        'last_mentioned',
        'no_videos',
        'search',
        'saved_sources',
        'unavailable',
        'login_failed',
      ]) {
        expect(s.t(key), isNot(key));
      }
      expect(s.t('account', args: {'user': 'fixture'}), contains('fixture'));
    }
  });
}
