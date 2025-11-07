import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prompt_ar/models/generation_mode.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/generation_state.dart';
import '../../models/model_response.dart';
import '../../repositories/model_repository.dart';
import '../../services/network_service.dart';
import 'ar_state.dart';

/// Cubit for managing AR model generation
class ARCubit extends Cubit<ARState> {
  final ModelRepository _repository;
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  // Track multiple models in the scene - keyed by model ID
  final Map<String, ARNode> _placedModelNodes = {};
  final Map<String, ARPlaneAnchor> _placedAnchors = {};

  ARCubit({
    ModelRepository? repository,
    NetworkService? networkService,
  })  : _repository = repository ?? ModelRepository(),
        super(const ARState());

  /// Initialize AR session with managers
  Future<void> initialize({
    required ARSessionManager sessionManager,
    required ARObjectManager objectManager,
    required ARAnchorManager anchorManager,
  }) async {
    _arSessionManager = sessionManager;
    _arObjectManager = objectManager;
    _arAnchorManager = anchorManager;

    // Initialize AR session
    _arSessionManager?.onInitialize(
      showAnimatedGuide: false,
      showFeaturePoints: false,
      showPlanes: false,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handlePans: true,
      handleRotation: true,
      handleTaps: true,
    );

    // Initialize object manager
    _arObjectManager?.onInitialize();

    // Set tap handler for placing models (works when model is ready or when idle with modelResponse)
    _arSessionManager?.onPlaneOrPointTap = (hitTestResults) {
      final currentState = state;
      // Allow placing if:
      // 1. Model is ready (arReady state), OR
      // 2. State is idle but we have a modelResponse (can place same model again)
      final canPlace =
          (currentState.generationState == GenerationState.arReady ||
                  (currentState.generationState == GenerationState.idle &&
                      currentState.modelResponse != null)) &&
              currentState.modelResponse?.localFilePath != null;

      if (!canPlace) {
        debugPrint('ARView: Tap ignored - model not ready');
        return;
      }

      // Call handleTap method directly
      handleTap(hitTestResults);
    };

    debugPrint('ARView: AR session initialized');

    emit(state.copyWith(generationState: GenerationState.idle));
  }

  /// Handle tap event on AR plane
  Future<void> handleTap(List<ARHitTestResult> hitTestResults) async {
    if (_arObjectManager == null || _arAnchorManager == null) {
      debugPrint('ARView: AR managers not initialized');
      return;
    }

    final currentState = state;
    if (currentState.modelResponse?.localFilePath == null) {
      debugPrint('ARView: No model file path available');
      return;
    }
    if (hitTestResults.isEmpty) return;

    final baseModelId = currentState.modelResponse!.modelId;
    final modelFilePath = currentState.modelResponse!.localFilePath!;

    // Generate unique ID for this placement (allows same model to be placed multiple times)
    final placementId =
        '${baseModelId}_${DateTime.now().millisecondsSinceEpoch}';

    // Find the first plane hit test result
    final planeHitTestResult = hitTestResults.firstWhere(
      (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.first,
    );

    // Create ARPlaneAnchor at the tap location
    final newAnchor = ARPlaneAnchor(
      transformation: planeHitTestResult.worldTransform,
    );

    // Add anchor
    final didAddAnchor = await _arAnchorManager!.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      // Store anchor for this model placement
      _placedAnchors[placementId] = newAnchor;

      // Place GLB model at anchor
      final node = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: modelFilePath,
        scale: vector.Vector3(16, 16, 16),
        position: vector.Vector3(0.0, 0.0, 0.0),
      );

      debugPrint('🔍 Placing GLB model at anchor: ${newAnchor.name}');
      debugPrint('   Base Model ID: $baseModelId');
      debugPrint('   Placement ID: $placementId');
      debugPrint('   Node type: ${node.type}');
      debugPrint('   URI: ${node.uri}');

      final didAddNode =
          await _arObjectManager!.addNode(node, planeAnchor: newAnchor);

      if (didAddNode == true) {
        // Store node for this model placement
        _placedModelNodes[placementId] = node;

        // Add placement ID to placed models list
        final updatedPlacedModels = List<String>.from(state.placedModelIds)
          ..add(placementId);

        // Reset to idle so user can add more models, but keep the modelResponse
        // so it can be placed again if needed
        emit(state.copyWith(
          generationState: GenerationState.idle,
          placedModelIds: updatedPlacedModels,
        ));
        debugPrint('✅ Model placed at anchor: ${newAnchor.name}');
        debugPrint('   Total models in scene: ${updatedPlacedModels.length}');
      } else {
        // Remove anchor if node placement failed
        _arAnchorManager!.removeAnchor(newAnchor);
        _placedAnchors.remove(placementId);
        debugPrint('❌ Failed to place model at anchor: ${newAnchor.name}');
      }
    }
  }

  /// Generate model from prompt
  Future<void> generate(String prompt) async {
    try {
      // Processing state - generating model on backend
      emit(state.copyWith(
        generationState: GenerationState.generating,
        currentPrompt: prompt,
      ));

      // Generate model from backend
      final response = await _repository.generateModel(
        prompt: prompt,
        mode: state.generationMode.name,
      );
      // Downloading state - downloading GLB model directly
      emit(state.copyWith(
        generationState: GenerationState.downloading,
        modelResponse: response,
      ));

      final localFilePath = await _repository.downloadModel(
        response.modelId,
      );

      // Update response with local file path
      final responseWithLocalPath = response.copyWith(
        localFilePath: localFilePath,
      );

      // AR Ready state - model file is ready to display
      emit(state.copyWith(
        generationState: GenerationState.arReady,
        modelResponse: responseWithLocalPath,
      ));
    } catch (e) {
      emit(state.copyWith(
        generationState: GenerationState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Clear all models from AR scene
  void clearAllModels() {
    if (_arObjectManager != null) {
      for (final node in _placedModelNodes.values) {
        _arObjectManager!.removeNode(node);
      }
      _placedModelNodes.clear();
    }
    if (_arAnchorManager != null) {
      for (final anchor in _placedAnchors.values) {
        _arAnchorManager!.removeAnchor(anchor);
      }
      _placedAnchors.clear();
    }
    emit(state.copyWith(
      placedModelIds: [],
      currentPrompt: '',
      modelResponse: null,
      generationState: GenerationState.idle,
    ));
    debugPrint('ARView: All models cleared from scene');
  }

  /// Dispose AR resources
  void disposeAR() {
    clearAllModels();
    _arSessionManager?.dispose();
  }

  /// Reset AR state to idle (clears current model response but keeps placed models)
  Future<void> reset() async {
    emit(state.copyWith(
      generationState: GenerationState.idle,
      errorMessage: null,
      clearModelResponse: true,
    ));
  }

  /// Clear all placed models from scene
  void clearScene() {
    clearAllModels();
    emit(state.copyWith(
      placedModelIds: [],
    ));
  }

  // change selected mode
  void updateMode(GenerationMode mode) {
    emit(state.copyWith(generationMode: mode));
  }

  /// Fetch list of downloaded models from repository and update state
  Future<void> fetchDownloadedModels() async {
    try {
      final models = await _repository.getDownloadedModels();
      emit(state.copyWith(downloadedModels: models));
    } catch (e) {
      debugPrint('ARCubit: Error fetching downloaded models: $e');
      emit(state.copyWith(downloadedModels: []));
    }
  }

  /// Load an existing downloaded model
  Future<void> loadExistingModel(String modelId) async {
    try {
      emit(state.copyWith(
        generationState: GenerationState.initial,
      ));
      // Create a mock response for the existing model
      final response = ModelResponse(
        modelId: modelId,
        downloadUrl: '', // Not needed for local models
        prompt: 'Loaded from storage', // Could store prompt if available
        status: 'completed',
        message: 'Model loaded from local storage',
        localFilePath: modelId,
      );

      // Small delay for UI feedback
      await Future.delayed(const Duration(milliseconds: 500));

      // AR Ready state - model file is ready to display
      emit(state.copyWith(
        generationState: GenerationState.arReady,
        modelResponse: response,
      ));
    } catch (e) {
      emit(state.copyWith(
        generationState: GenerationState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Delete a downloaded model
  Future<void> deleteModel(String modelId) async {
    try {
      final deleted = await _repository.deleteModel(modelId);
      if (deleted) {
        //  remove from state list and emit
        final updatedModels =
            state.downloadedModels?.where((m) => m != modelId).toList();
        emit(state.copyWith(downloadedModels: updatedModels));
        debugPrint('ARCubit: Model deleted: $modelId');
      } else {
        debugPrint('ARCubit: Failed to delete model: $modelId');
      }
    } catch (e) {
      debugPrint('ARCubit: Error deleting model: $e');
    }
  }
}
