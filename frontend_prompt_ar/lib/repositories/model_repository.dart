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
  /// Creates folder structure: documentsDir/modelId/
  /// Saves model as: modelId/model.glb
  /// Creates info.json with modelId, prompt, and timestamp
  /// Returns the relative path for use with NodeType.fileSystemAppFolderGLB
  /// Path format: "modelId/model.glb" (relative to documents folder)
  /// Uses Documents directory instead of Caches for better ARKit access on iOS
  Future<String> downloadModel(String modelId, String prompt) async {
    try {
      debugPrint(
          'DownloadService: Starting GLB download for modelId: $modelId');
      // Use application documents directory - ARKit has better access to this on iOS
      final documentsDir = await getApplicationDocumentsDirectory();

      // Create folder structure: documentsDir/modelId/
      final modelFolder = Directory(path.join(documentsDir.path, modelId));
      if (!await modelFolder.exists()) {
        await modelFolder.create(recursive: true);
        debugPrint('DownloadService: Created folder: ${modelFolder.path}');
      }

      // Download the file using network service
      final response = await _networkService.get(
        _networkService.downloadEndpoint(modelId),
      );

      if (response.statusCode == 200) {
        // Save the model file as model.glb inside the modelId folder
        final modelFilePath = path.join(modelFolder.path, 'model.glb');
        final modelFile = File(modelFilePath);
        await modelFile.writeAsBytes(response.bodyBytes);

        // Verify model file was saved correctly
        if (await modelFile.exists()) {
          final fileSize = await modelFile.length();
          debugPrint(
              'DownloadService: GLB model saved successfully. Size: $fileSize bytes');

          if (fileSize == 0) {
            throw Exception('Downloaded file is empty');
          }

          // Create info.json file
          final infoJson = {
            'model_id': modelId,
            'prompt': prompt,
            'timestamp': DateTime.now().toIso8601String(),
          };
          final infoFilePath = path.join(modelFolder.path, 'info.json');
          final infoFile = File(infoFilePath);
          await infoFile.writeAsString(jsonEncode(infoJson));
          debugPrint('DownloadService: Created info.json: $infoFilePath');

          // Return relative path for use with fileSystemAppFolderGLB
          // Path is relative to documents folder: "modelId/model.glb"
          final relativePath = path.join(modelId, 'model.glb');
          debugPrint(
              'DownloadService: Use path: "$relativePath" with NodeType.fileSystemAppFolderGLB');
          return relativePath;
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
  /// Looks for folders containing model.glb and info.json
  /// Reads info.json to populate ModelResponse objects
  /// Returns list of ModelResponse sorted by timestamp descending (latest first)
  Future<List<ModelResponse>> getDownloadedModels() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(documentsDir.path);

      if (!await dir.exists()) {
        return [];
      }

      final entries = dir.listSync();
      final modelResponses = <ModelResponse>[];

      // Collect ModelResponse objects from folders
      for (final entry in entries.whereType<Directory>()) {
        try {
          final modelGlbPath = path.join(entry.path, 'model.glb');
          final infoJsonPath = path.join(entry.path, 'info.json');
          final modelGlbFile = File(modelGlbPath);
          final infoJsonFile = File(infoJsonPath);

          // Check if folder contains both model.glb and info.json
          if (await modelGlbFile.exists() && await infoJsonFile.exists()) {
            // Read and parse info.json
            final infoJsonContent = await infoJsonFile.readAsString();
            final infoJson = jsonDecode(infoJsonContent) as Map<String, dynamic>;
            
            final modelId = infoJson['model_id'] as String? ?? 
                           path.basename(entry.path); // Fallback to folder name
            final prompt = infoJson['prompt'] as String? ?? '';
            final timestampStr = infoJson['timestamp'] as String?;
            final timestamp = timestampStr != null 
                ? DateTime.parse(timestampStr) 
                : null;
            
            // Create ModelResponse with local file path
            final localFilePath = path.join(modelId, 'model.glb');
            
            final modelResponse = ModelResponse(
              modelId: modelId,
              downloadUrl: '', // Not needed for local models
              prompt: prompt,
              status: 'completed',
              message: 'Model loaded from local storage',
              localFilePath: localFilePath,
              locationType: ModelLocationType.documentsFolder,
              timestamp: timestamp,
            );
            
            modelResponses.add(modelResponse);
          }
        } catch (e) {
          debugPrint(
              'ModelRepository: Error reading folder ${entry.path}: $e');
        }
      }

      // Sort by timestamp descending (latest first), fallback to folder name if no timestamp
      modelResponses.sort((a, b) {
        if (a.timestamp != null && b.timestamp != null) {
          return b.timestamp!.compareTo(a.timestamp!);
        } else if (a.timestamp != null) {
          return -1; // a has timestamp, b doesn't - a comes first
        } else if (b.timestamp != null) {
          return 1; // b has timestamp, a doesn't - b comes first
        } else {
          return b.modelId.compareTo(a.modelId); // Fallback to modelId comparison
        }
      });

      debugPrint(
          'ModelRepository: Found ${modelResponses.length} downloaded models (sorted by timestamp)');
      return modelResponses;
    } catch (e) {
      debugPrint('ModelRepository: Error getting downloaded models: $e');
      return [];
    }
  }

  /// Delete a model folder from local storage
  /// Deletes the entire folder: documentsDir/modelId/
  /// modelId should be just the folder name (e.g., "abc")
  Future<bool> deleteModel(String modelId) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      // Remove .glb extension if present (for backward compatibility)
      final folderName = modelId.endsWith('.glb')
          ? modelId.substring(0, modelId.length - 4)
          : modelId;
      final folderPath = path.join(documentsDir.path, folderName);
      final folder = Directory(folderPath);

      if (await folder.exists()) {
        // Delete the entire folder and its contents
        await folder.delete(recursive: true);
        debugPrint('ModelRepository: Deleted model folder: $folderPath');
        return true;
      } else {
        debugPrint('ModelRepository: Model folder not found: $folderPath');
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
