import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'isle_navigator_key.dart';

/// [AppVersionOverlay] 등 GoRouter 하위가 아닌 위젯에서도 안전하게 이동
class IsleNavigation {
  IsleNavigation._();

  static BuildContext? get _rootContext => isleNavigatorKey.currentContext;

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
    r.push(location, extra: extra);
    return true;
  }

  static bool go(String location, {BuildContext? from}) {
    final r = _router(from);
    if (r == null) return false;
    r.go(location);
    return true;
  }

  static bool pop<T extends Object?>([T? result, BuildContext? from]) {
    final r = _router(from);
    if (r == null) return false;
    if (r.canPop()) {
      r.pop(result);
      return true;
    }
    return false;
  }
}
