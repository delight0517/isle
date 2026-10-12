/// Kept as a migration shim for existing bootstrap call sites.
/// API credentials must be entered through the user's secure settings flow;
/// never embed or seed provider keys in an application binary.
class DevApiKeySeeder {
  DevApiKeySeeder._();

  static Future<void> seedIfEmpty() async {}
}
