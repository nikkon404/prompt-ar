import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration loaded from .env file
class AppConfig {
  /// Backend API base URL
  static String get backendBaseUrl =>
      dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:8000';

  /// API Endpoints
  static String get generateEndpoint =>
      dotenv.env['API_ENDPOINT_GENERATE'] ?? '/api/models/generate';

  static String get downloadEndpoint =>
      dotenv.env['API_ENDPOINT_DOWNLOAD'] ?? '/api/models/download';

  static String get modelsEndpoint =>
      dotenv.env['API_ENDPOINT_MODELS'] ?? '/api/models';

  /// Timeout durations
  static Duration get generationTimeout {
    final seconds = int.tryParse(dotenv.env['GENERATION_TIMEOUT'] ?? '600') ?? 600;
    return Duration(seconds: seconds);
  }

  static Duration get downloadTimeout {
    final seconds = int.tryParse(dotenv.env['DOWNLOAD_TIMEOUT'] ?? '300') ?? 300;
    return Duration(seconds: seconds);
  }

  /// Build full URL from endpoint
  static String buildUrl(String endpoint) {
    if (endpoint.startsWith('http')) {
      return endpoint;
    }
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$backendBaseUrl/$cleanEndpoint';
  }
}
