import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Network service for handling all API calls to the backend
class NetworkService {
  final http.Client _client;
  late final String _baseUrl;
  late final String _generateEndpoint;
  late final String _downloadEndpoint;
  late final String _modelsEndpoint;
  late final Duration _generationTimeout;
  late final Duration _downloadTimeout;

  NetworkService({
    http.Client? client,
  }) : _client = client ?? http.Client() {
    _initializeFromEnv();
  }

  /// Initialize configuration from environment variables
  void _initializeFromEnv() {
    _baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:8000';
    _generateEndpoint = dotenv.env['API_ENDPOINT_GENERATE'] ?? '/api/models/generate';
    _downloadEndpoint = dotenv.env['API_ENDPOINT_DOWNLOAD'] ?? '/api/models/download';
    _modelsEndpoint = dotenv.env['API_ENDPOINT_MODELS'] ?? '/api/models';
    
    final genTimeout = int.tryParse(dotenv.env['GENERATION_TIMEOUT'] ?? '600') ?? 600;
    final dlTimeout = int.tryParse(dotenv.env['DOWNLOAD_TIMEOUT'] ?? '300') ?? 300;
    
    _generationTimeout = Duration(seconds: genTimeout);
    _downloadTimeout = Duration(seconds: dlTimeout);
  }

  /// Get the base URL
  String get baseUrl => _baseUrl;

  /// Build full URL from endpoint path
  String buildUrl(String endpoint) {
    if (endpoint.startsWith('http')) {
      return endpoint;
    }
    // Remove leading slash if present
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$_baseUrl/$cleanEndpoint';
  }

  /// Make a POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(buildUrl(endpoint));
    final defaultHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: defaultHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? _generationTimeout);

      return response;
    } catch (e) {
      if (e is TimeoutException) {
        throw NetworkException('Request timed out', 408);
      }
      throw NetworkException('Network error: ${e.toString()}', 0);
    }
  }

  /// Make a GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(buildUrl(endpoint));
    final defaultHeaders = {
      ...?headers,
    };

    try {
      final response = await _client
          .get(uri, headers: defaultHeaders)
          .timeout(timeout ?? _downloadTimeout);

      return response;
    } catch (e) {
      if (e is TimeoutException) {
        throw NetworkException('Request timed out', 408);
      }
      throw NetworkException('Network error: ${e.toString()}', 0);
    }
  }

  /// Generate model endpoint
  String get generateEndpoint => _generateEndpoint;

  /// Download model endpoint (needs model_id parameter)
  String downloadEndpoint(String modelId) => '$_downloadEndpoint/$modelId';

  /// Models list endpoint
  String get modelsEndpoint => _modelsEndpoint;

  /// Generation timeout
  Duration get generationTimeout => _generationTimeout;

  /// Download timeout
  Duration get downloadTimeout => _downloadTimeout;

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}

/// Custom exception for network errors
class NetworkException implements Exception {
  final String message;
  final int statusCode;

  NetworkException(this.message, this.statusCode);

  @override
  String toString() => 'NetworkException: $message (Status: $statusCode)';
}

