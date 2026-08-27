abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'WNT_API_URL',
    defaultValue: 'https://panel.wodanatelefon.pl/api',
  );

  static const requestTimeout = Duration(seconds: 60);
}
