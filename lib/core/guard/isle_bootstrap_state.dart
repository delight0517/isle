/// `main()` 부트스트랩 일부 실패 시에도 runApp — 복구 UI용
class IsleBootstrapState {
  IsleBootstrapState._();

  static bool degraded = false;
  static final List<String> failures = [];

  static void markFailure(String label) {
    degraded = true;
    if (!failures.contains(label)) failures.add(label);
  }

  static String get summary => failures.isEmpty
      ? ''
      : failures.join(', ');
}
