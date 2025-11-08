import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

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

        // Store the prompt in the response for reference
        return ModelResponse(
          modelId: json['model_id'] as String,
          downloadUrl: _buildFullUrl(json['download_url'] as String),
          prompt: prompt,
          status: json['status'] as String,
          message: json['message'] as String? ?? 'Model generated successfully',
          locationType: ModelLocationType.documentsFolder,
        );
      } else {
        final errorBody = response.body;
        debugPrint(errorBody);
        throw Exception(
            'Failed to generate model: ${response.statusCode} - $errorBody');
      }
    } on TimeoutException {
      debugPrint("Timeout");
      throw Exception('Model generation timed out. Please try again.');
    } on NetworkException catch (e) {
      debugPrint("Network Exception: ${e.statusCode}");
      debugPrint(" ${e.message}");
      if (e.statusCode == 408) {
        throw Exception('Model generation timed out. Please try again.');
      }
      throw Exception('Network error has occurred. Please try again.');
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

  /// Get list of asset GLB files from assets folder
  /// Reads dynamically from AssetManifest.json
  Future<List<String>> getAssetModels() async {
    try {
      final assetModels = <String>[];

      // Load AssetManifest.json which contains all asset paths
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);

      // Filter for GLB files in the assets folder
      for (final assetPath in manifestMap.keys) {
        if (assetPath.startsWith('assets/') && assetPath.endsWith('.glb')) {
          assetModels.add(assetPath);
          debugPrint('ModelRepository: Found asset model: $assetPath');
        }
      }

      // Sort alphabetically for consistency
      assetModels.sort();

      debugPrint('ModelRepository: Found ${assetModels.length} asset models');
      return assetModels;
    } catch (e) {
      debugPrint('ModelRepository: Error getting asset models: $e');
      return [];
    }
  }

  /// Get list of all downloaded models from documents directory
  /// Returns list of model IDs (filenames without .glb extension)
  /// Sorted by creation date descending (latest first)
  /// Also checks and loads asset models in memory
  Future<List<String>> getDownloadedModels() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(documentsDir.path);

      if (!await dir.exists()) {
        return [];
      }

      final files = dir.listSync();
      final modelFiles = <Map<String, dynamic>>[];

      // Collect files with their modification times
      for (final file in files.whereType<File>()) {
        if (file.path.endsWith('.glb')) {
          try {
            final stat = await file.stat();
            final fileName = path.basename(file.path);
            modelFiles.add({
              'fileName': fileName,
              'modified': stat.modified,
            });
          } catch (e) {
            debugPrint(
                'ModelRepository: Error getting stat for ${file.path}: $e');
          }
        }
      }

      // Sort by modification time descending (latest first)
      modelFiles.sort((a, b) =>
          (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));

      final sortedFileNames =
          modelFiles.map((item) => item['fileName'] as String).toList();

      debugPrint(
          'ModelRepository: Found ${sortedFileNames.length} downloaded models (sorted by date)');
      return sortedFileNames;
    } catch (e) {
      debugPrint('ModelRepository: Error getting downloaded models: $e');
      return [];
    }
  }

  /// Delete a model file from local storage
  /// modelId can be either just the ID or the full filename (e.g., "modelId.glb")
  Future<bool> deleteModel(String modelId) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      // Handle both formats: "modelId" or "modelId.glb"
      final fileName = modelId.endsWith('.glb') ? modelId : '$modelId.glb';
      final filePath = path.join(documentsDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        debugPrint('ModelRepository: Deleted model file: $filePath');
        return true;
      } else {
        debugPrint('ModelRepository: Model file not found: $filePath');
        return false;
      }
    } catch (e) {
      debugPrint('ModelRepository: Error deleting model: $e');
      return false;
    }
  }

  //health check
  Future<bool> checkHealth() async {
    try {
      final response = await _networkService.get(
        _networkService.healthEndpoint,
        timeout: const Duration(seconds: 4),
      );
      if (response.statusCode == 200) {
        debugPrint('ModelRepository: Health check successful');
      } else {
        debugPrint(
            'ModelRepository: Health check failed with status: ${response.statusCode}');
        debugPrint(response.body);
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ModelRepository: Health check failed: $e');
      return false;
    }
  }
}
