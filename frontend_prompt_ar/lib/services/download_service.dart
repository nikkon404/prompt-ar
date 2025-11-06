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

  /// Download a GLB model file from URL and save it to documents directory
  /// Returns the relative path for use with NodeType.fileSystemAppFolderGLB
  /// Path format: "modelId.glb" (relative to documents folder)
  /// Uses Documents directory instead of Caches for better ARKit access on iOS
  Future<String> downloadModel(String downloadUrl, String modelId) async {
    try {
      debugPrint(
          'DownloadService: Starting GLB download for modelId: $modelId from $downloadUrl');
      // Use application documents directory - ARKit has better access to this on iOS
      final documentsDir = await getApplicationDocumentsDirectory();

      // Use GLB extension - AR plugins handle GLB on all platforms
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
