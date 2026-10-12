import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isle/core/navigation/isle_navigation.dart';
import 'package:isle/core/navigation/isle_navigator_key.dart';
import 'package:isle/core/navigation/schedule_overlay_navigation.dart';
import 'package:isle/core/navigation/schedule_sheet_navigation.dart';

void main() {
  testWidgets('overlay limit settings replaces locked browser route', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: isleNavigatorKey,
      initialLocation: '/hub',
      routes: [
        GoRoute(
          path: '/hub',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Hub'),
                FilledButton(
                  onPressed: () => context.push('/youtube/browser'),
                  child: const Text('Open browser'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/youtube/browser',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Locked browser'),
                FilledButton(
                  onPressed: () => IsleNavigation.pushReplacement(
                    '/youtube/limits',
                    from: context,
                  ),
                  child: const Text('Open limits'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/youtube/limits',
          builder: (context, state) => const Scaffold(
            body: Text('Limits settings'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Hub'), findsOneWidget);

    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    expect(find.text('Locked browser'), findsOneWidget);

    await tester.tap(find.text('Open limits'));
    await tester.pumpAndSettle();
    expect(find.text('Limits settings'), findsOneWidget);
    expect(find.text('Locked browser'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('bottom sheet limit action pushes above locked browser route', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: isleNavigatorKey,
      initialLocation: '/hub',
      routes: [
        GoRoute(
          path: '/hub',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Hub'),
                FilledButton(
                  onPressed: () => context.push('/youtube/browser'),
                  child: const Text('Open browser'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/youtube/browser',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Locked browser'),
                FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: FilledButton(
                        onPressed: () => dismissSheetThenPush(
                          sheetContext,
                          context,
                          '/youtube/limits',
                        ),
                        child: const Text('Sheet limits'),
                      ),
                    ),
                  ),
                  child: const Text('Open sheet'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/youtube/limits',
          builder: (context, state) => const Scaffold(
            body: Text('Limits settings'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    expect(find.text('Locked browser'), findsOneWidget);

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet limits'), findsOneWidget);

    await tester.tap(find.text('Sheet limits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Limits settings'), findsOneWidget);
    expect(find.text('Locked browser'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Locked browser'), findsOneWidget);
  });

  testWidgets('overlay schedule settings replaces locked browser route', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: isleNavigatorKey,
      initialLocation: '/hub',
      routes: [
        GoRoute(
          path: '/hub',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Hub'),
                FilledButton(
                  onPressed: () => context.push('/youtube/browser'),
                  child: const Text('Open browser'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/youtube/browser',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Locked browser'),
                FilledButton(
                  onPressed: () => openBlockScheduleFromOverlay(context),
                  child: const Text('Open schedules'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/block/schedules',
          builder: (context, state) => const Scaffold(
            body: Text('Schedule settings'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Hub'), findsOneWidget);

    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    expect(find.text('Locked browser'), findsOneWidget);

    await tester.tap(find.text('Open schedules'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule settings'), findsOneWidget);
    expect(find.text('Locked browser'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('IsleNavigation.pop accepts named from context', (tester) async {
    final router = GoRouter(
      navigatorKey: isleNavigatorKey,
      initialLocation: '/hub',
      routes: [
        GoRoute(
          path: '/hub',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Hub'),
                FilledButton(
                  onPressed: () => context.push('/overlay'),
                  child: const Text('Open overlay'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/overlay',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Overlay'),
                FilledButton(
                  onPressed: () => IsleNavigation.pop(from: context),
                  child: const Text('Close overlay'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open overlay'));
    await tester.pumpAndSettle();
    expect(find.text('Overlay'), findsOneWidget);

    await tester.tap(find.text('Close overlay'));
    await tester.pumpAndSettle();
    expect(find.text('Hub'), findsOneWidget);
    expect(find.text('Overlay'), findsNothing);
  });
}
