class AppConfig {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://obroh-backend-zoeqld5lsa-uc.a.run.app/api',
  );

  static String get apiBaseUrl => _defaultApiBaseUrl;
  static String get apiBaseUrlIos => _defaultApiBaseUrl;

  static String get uploadsBaseUrl => apiBaseUrl.replaceAll('/api', '');

  static const Duration httpTimeout = Duration(seconds: 30);
  static const Duration pollInterval = Duration(seconds: 30);
}
