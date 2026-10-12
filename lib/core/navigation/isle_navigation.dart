import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'isle_navigator_key.dart';

/// [AppVersionOverlay] 등 GoRouter 하위가 아닌 위젯에서도 안전하게 이동
class IsleNavigation {
  IsleNavigation._();

  static BuildContext? get _rootContext => isleNavigatorKey.currentContext;

  static void _trace(String message) {
    debugPrint(message);
    developer.log(message, name: 'IsleNav');
  }

  static GoRouter? _router([BuildContext? from]) {
    if (from != null) {
      final r = GoRouter.maybeOf(from);
      if (r != null) return r;
    }
    final ctx = _rootContext;
    if (ctx == null) return null;
    return GoRouter.maybeOf(ctx);
  }

  static bool push(String location, {Object? extra, BuildContext? from}) {
    final r = _router(from);
    if (r == null) return false;
    _trace('[IsleNav] push -> $location');
    r.push(location, extra: extra);
    return true;
  }

  static bool pushReplacement(
    String location, {
    Object? extra,
    BuildContext? from,
  }) {
    final r = _router(from);
    if (r == null) return false;
    _trace('[IsleNav] pushReplacement -> $location');
    r.pushReplacement(location, extra: extra);
    return true;
  }

  static bool go(String location, {BuildContext? from}) {
    final r = _router(from);
    if (r == null) return false;
    _trace('[IsleNav] go -> $location');
    r.go(location);
    return true;
  }

  static bool pop<T extends Object?>({
    T? result,
    BuildContext? from,
  }) {
    final r = _router(from);
    if (r == null) return false;
    if (r.canPop()) {
      _trace('[IsleNav] pop');
      r.pop(result);
      return true;
    }
    return false;
  }
}
