import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'network_service.dart';

/// Service for downloading and storing 3D model files
class DownloadService {
  final NetworkService _networkService;

  DownloadService({
    NetworkService? networkService,
  }) : _networkService = networkService ?? NetworkService();

  /// Download a model file from URL and save it to documents directory
  /// Returns the local file path
  /// Uses Documents directory instead of Caches for better ARKit access on iOS
  Future<String> downloadModel(String downloadUrl, String modelId) async {
    try {
      debugPrint(
          'DownloadService: Starting download for modelId: $modelId from $downloadUrl');
      // Use application documents directory - ARKit has better access to this on iOS
      final documentsDir = await getApplicationDocumentsDirectory();

      // Use GLB extension - model_viewer_plus handles GLB on all platforms
      final fileName = '$modelId.glb';
      final filePath = path.join(documentsDir.path, fileName);

      debugPrint('DownloadService: Downloading GLB model to $filePath');

      // Download the file using network service
      final response = await _networkService.get(
        downloadUrl,
      );

      if (response.statusCode == 200) {
        // Save the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Verify file was saved correctly
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint(
              'DownloadService: Model saved successfully. Size: $fileSize bytes');

          if (fileSize == 0) {
            throw Exception('Downloaded file is empty');
          }

          return filePath;
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

  /// Check if a model file exists locally
  Future<bool> modelExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Delete a model file
  Future<void> deleteModel(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get all downloaded model files from temp directory
  Future<List<String>> getDownloadedModels() async {
    final tempDir = await getTemporaryDirectory();
    final modelsDir = Directory(path.join(tempDir.path, 'models'));

    if (!await modelsDir.exists()) {
      return [];
    }

    final files = modelsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.glb'))
        .map((file) => file.path)
        .toList();

    return files;
  }

  /// Clear all cached models from temp directory
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final modelsDir = Directory(path.join(tempDir.path, 'models'));

      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
