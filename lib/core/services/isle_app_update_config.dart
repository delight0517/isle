/// Web Deploy Manager OTA — Isle catalog (focusgate-landing.vercel.app)
abstract final class IsleAppUpdateConfig {
  static const appId = 'isle';
  static const appDisplayName = 'Isle';
  static const catalogBaseUrl = 'https://focusgate-landing.vercel.app';

  static String get manifestUrl =>
      '$catalogBaseUrl/catalog/live/$appId.json';
}
