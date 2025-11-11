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
    try {
      _arSessionManager = sessionManager;
      _arObjectManager = objectManager;
      _arAnchorManager = anchorManager;

      // Initialize AR session
      try {
        await _arSessionManager?.onInitialize(
          showAnimatedGuide: false,
          showFeaturePoints: false,
          showPlanes: false,
          customPlaneTexturePath: null,
          showWorldOrigin: false,
          handlePans: true,
          handleRotation: true,
          handleTaps: true,
        );
      } catch (e) {
        debugPrint('ARView: Failed to initialize AR session: $e');
        emit(state.copyWith(
          generationState: GenerationState.error,
          errorMessage:
              'AR is not available on this device. ARCore requires a physical Android device and cannot run on emulators.',
        ));
        return;
      }

      // Initialize object manager
      try {
        await _arObjectManager?.onInitialize();
      } catch (e) {
        debugPrint('ARView: Failed to initialize AR object manager: $e');
        emit(state.copyWith(
          generationState: GenerationState.error,
          errorMessage:
              'AR is not available on this device. ARCore requires a physical Android device and cannot run on emulators.',
        ));
        return;
      }

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

      // Set node tap handler for selecting nodes and showing settings dialog
      // Keep it simple - the plugin handles pan/rotate gestures automatically
      _arObjectManager?.onNodeTap = (List<String> nodeNames) {
        debugPrint('ARView: onNodeTap called with nodeNames: $nodeNames');

        if (nodeNames.isEmpty) return;

        final tappedNode = _placedModelNodes[nodeNames.first];
        emit(state.copyWith(tappedNode: tappedNode));
      };

      // Set pan end handler to update node transform
      // Update the transform directly to match what the plugin provides
      _arObjectManager?.onPanEnd = (String nodeName, Matrix4 transform) {
        final node = _placedModelNodes[nodeName];
        if (node != null) {
          // Update the transform directly - this preserves all properties correctly
          node.transform = transform;
          debugPrint(
              'ARCubit: Updated transform (position) for node $nodeName');
        }
      };

      // Set rotation end handler to update node transform
      // Update the transform directly to match what the plugin provides
      _arObjectManager?.onRotationEnd = (String nodeName, Matrix4 transform) {
        final node = _placedModelNodes[nodeName];
        if (node != null) {
          // Update the transform directly - this preserves all properties correctly
          node.transform = transform;
          debugPrint(
              'ARCubit: Updated transform (rotation) for node $nodeName');
        }
      };

      debugPrint('ARView: AR session initialized');

      emit(state.copyWith(generationState: GenerationState.idle));
      final isRunning = await _repository.checkHealth();
      if (!isRunning) {
        emit(state.copyWith(
            generationState: GenerationState.error,
            errorMessage:
                'Failed to connect with the server, can only render local 3d models'));
      }
    } catch (e) {
      debugPrint('ARView: Unexpected error during AR initialization: $e');
      emit(state.copyWith(
        generationState: GenerationState.error,
        errorMessage:
            'Failed to initialize AR: ${e.toString()}. ARCore requires a physical Android device and cannot run on emulators.',
      ));
    }
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

    final model = currentState.modelResponse;
    if (model == null) {
      debugPrint('ARView: No model available to place');
      return;
    }
    final baseModelId = currentState.modelResponse!.modelId;
    final modelFilePath = currentState.modelResponse!.localFilePath!;
    final isDownloaded = currentState.modelResponse!.locationType ==
        ModelLocationType.documentsFolder;

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

      final size =
          isDownloaded ? 30.0 : 0.6; // Larger size for downloaded models
      // Place GLB model at anchor
      final node = ARNode(
        type: isDownloaded
            ? NodeType.fileSystemAppFolderGLB
            : NodeType.localGLTF2,
        uri: modelFilePath,
        scale: vector.Vector3.all(size),
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
        _placedModelNodes[node.name] = node;

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
      clearModelResponse: true,
      clearTappedNode: true,
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

  /// Fetch list of downloaded models and asset models from repository and update state
  Future<void> fetchDownloadedModels() async {
    try {
      final models = await _repository.getDownloadedModels();
      final assetModels = await _repository.getAssetModels();
      emit(state.copyWith(
        downloadedModels: models,
        assetModels: assetModels,
      ));
    } catch (e) {
      debugPrint('ARCubit: Error fetching downloaded models: $e');
      emit(state.copyWith(downloadedModels: [], assetModels: []));
    }
  }

  /// Load an existing downloaded model
  Future<void> loadExistingModel(String modelId, ModelLocationType type) async {
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
        locationType: type,
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

  /// Clear selected node
  void clearSelectedNode() {
    emit(state.copyWith(clearTappedNode: true));
  }

  /// Update node scale
  void updateNodeScale(String nodeName, vector.Vector3 updatedScale) {
    final node = _placedModelNodes[nodeName];
    if (node != null) {
      node.scale = updatedScale;
      _placedModelNodes[nodeName] = node;
    }
    return;
  }
}
