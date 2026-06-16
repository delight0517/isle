import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isle/core/navigation/share_link_router.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('isle_test_hive');
    Hive.init(dir.path);
    await Hive.openBox<String>('isle_cache');
  });

  test('ShareLinkRouter routes YouTube https link to in-app browser', () {
    const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    final route = ShareLinkRouter.inAppRouteForUrl(url);
    expect(route, isNotNull);
    expect(route!, contains('/youtube/browser'));
    expect(route, contains('url='));
  });

  test('ShareLinkRouter routes isle://youtube scheme', () {
    final route = ShareLinkRouter.routeFromIncomingUri(
      Uri.parse('isle://youtube?url=https://youtu.be/dQw4w9WgXcQ'),
    );
    expect(route, isNotNull);
    expect(route!, contains('/youtube'));
  });

  testWidgets('Material smoke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Isle'))),
    );
    expect(find.text('Isle'), findsOneWidget);
  });
}
