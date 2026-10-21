class ApiConfig {
  ApiConfig._();
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );
  /// Live API by default. Local testing only:
  /// `flutter run --dart-define=API_BASE_URL=http://localhost:5001/api`
  static const String _override = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return 'https://buildtrack-api.nurofin.com/api';
  }
}
