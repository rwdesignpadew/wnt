abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'WNT_API_URL',
    defaultValue: 'https://kacper.host831247.xce.pl/api',
  );

  static const requestTimeout = Duration(seconds: 25);
}
