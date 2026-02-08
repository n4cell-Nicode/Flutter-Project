class ApiConfig {
  // For web testing in Chrome (localhost)
  static const String baseUrl = 'http://localhost/backend/api';

  /// Base URL for uploaded product images (backend root, not /api).
  static String get uploadsBaseUrl =>
      baseUrl.replaceAll(RegExp(r'/api/?$'), '');

  // For Android emulator later, use:
  // static const String baseUrl = 'http://10.0.2.2/backend/api';
}