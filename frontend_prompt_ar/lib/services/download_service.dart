import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import 'network_service.dart';

/// Service for downloading and storing 3D model files
class DownloadService {
  final NetworkService _networkService;

  DownloadService({
    NetworkService? networkService,
  }) : _networkService = networkService ?? NetworkService();

  /// Download a model file from URL and save it locally
  /// Returns the local file path
  Future<String> downloadModel(String downloadUrl, String modelId) async {
    try {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(directory.path, 'models'));
      
      // Create models directory if it doesn't exist
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // Determine file extension from URL or default to .glb
      final fileExtension = downloadUrl.toLowerCase().contains('.glb') ? '.glb' : '.glb';
      final fileName = 'model_$modelId$fileExtension';
      final filePath = path.join(modelsDir.path, fileName);

      // Download the file using network service
      final response = await _networkService.get(
        downloadUrl,
        timeout: AppConfig.downloadTimeout,
      );

      if (response.statusCode == 200) {
        // Save the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
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

  /// Get all downloaded model files
  Future<List<String>> getDownloadedModels() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(directory.path, 'models'));
    
    if (!await modelsDir.exists()) {
      return [];
    }

    final files = modelsDir.listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.glb'))
        .map((file) => file.path)
        .toList();
    
    return files;
  }
}
