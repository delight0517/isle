import 'dart:async';

import 'package:flutter/foundation.dart';

/// [GoRouter.refreshListenable]용 — 인증 스트림마다 리다이렉트 재평가
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
    notifyListeners();
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
