import 'dart:async';
import 'dart:convert';
import '../models/model_response.dart';
import '../services/network_service.dart';

/// Repository for handling 3D model generation API calls
class ModelRepository {
  final NetworkService _networkService;

  ModelRepository({
    NetworkService? networkService,
  }) : _networkService = networkService ?? NetworkService();

  /// Generate a 3D model from a text prompt
  Future<ModelResponse> generateModel(String prompt) async {
    try {
      final response = await _networkService.post(
        _networkService.generateEndpoint,
        body: {
          'prompt': prompt,
        },
        timeout: _networkService.generationTimeout,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final modelResponse = ModelResponse.fromJson(json);

        // Store the prompt in the response for reference
        return ModelResponse(
          modelId: modelResponse.modelId,
          downloadUrl: _buildFullUrl(modelResponse.downloadUrl),
          prompt: prompt,
          status: modelResponse.status,
          message: modelResponse.message,
        );
      } else {
        final errorBody = response.body;
        throw Exception('Failed to generate model: ${response.statusCode} - $errorBody');
      }
    } on NetworkException catch (e) {
      if (e.statusCode == 408) {
        throw Exception('Model generation timed out. Please try again.');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error generating model: ${e.toString()}');
    }
  }

  /// Build full URL from relative path
  String _buildFullUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    // Use network service to build full URL
    return _networkService.buildUrl(path);
  }
}

