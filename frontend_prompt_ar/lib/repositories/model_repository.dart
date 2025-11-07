import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../models/model_response.dart';
import '../services/network_service.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Repository for handling 3D model generation API calls
class ModelRepository {
  final NetworkService _networkService;

  ModelRepository({
    NetworkService? networkService,
  }) : _networkService = networkService ?? NetworkService();

  /// Generate a 3D model from a text prompt
  Future<ModelResponse> generateModel({
    required String prompt,
    required String mode,
  }) async {
    try {
      final response = await _networkService.post(
        _networkService.generateEndpoint,
        body: {
          'prompt': prompt,
          'mode': mode,
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
        throw Exception(
            'Failed to generate model: ${response.statusCode} - $errorBody');
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

  /// Download a GLB model file from URL and save it to documents directory
  /// Returns the relative path for use with NodeType.fileSystemAppFolderGLB
  /// Path format: "modelId.glb" (relative to documents folder)
  /// Uses Documents directory instead of Caches for better ARKit access on iOS
  Future<String> downloadModel(String modelId) async {
    try {
      debugPrint(
          'DownloadService: Starting GLB download for modelId: $modelId');
      // Use application documents directory - ARKit has better access to this on iOS
      final documentsDir = await getApplicationDocumentsDirectory();

      // Use GLB extension - AR plugins handle GLB on all platforms
      final fileName = '$modelId.glb';
      final filePath = path.join(documentsDir.path, fileName);

      debugPrint('DownloadService: Downloading GLB model to $filePath');

      // Download the file using network service
      final response = await _networkService.get(
        _networkService.downloadEndpoint(modelId),
      );

      if (response.statusCode == 200) {
        // Save the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Verify file was saved correctly
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint(
              'DownloadService: GLB model saved successfully. Size: $fileSize bytes');

          if (fileSize == 0) {
            throw Exception('Downloaded file is empty');
          }

          // Return relative path for use with fileSystemAppFolderGLB
          // Path is relative to documents folder: "modelId.glb"
          debugPrint(
              'DownloadService: Use path: "$fileName" with NodeType.fileSystemAppFolderGLB');
          return fileName;
        } else {
          throw Exception('File was not saved correctly');
        }
      } else {
        throw Exception('Failed to download model: ${response.statusCode}');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Download timed out. Please check your connection.');
      }
      throw Exception('Error downloading model: ${e.toString()}');
    }
  }
}
