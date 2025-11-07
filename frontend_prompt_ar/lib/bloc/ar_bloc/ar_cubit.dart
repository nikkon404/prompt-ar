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
import '../../repositories/model_repository.dart';
import '../../services/network_service.dart';
import 'ar_state.dart';

/// Cubit for managing AR model generation
class ARCubit extends Cubit<ARState> {
  final ModelRepository _repository;
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  ARNode? _currentModelNode;
  ARPlaneAnchor? _currentAnchor;

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

    // Set tap handler for placing models (only works when model is ready)
    _arSessionManager?.onPlaneOrPointTap = (hitTestResults) {
      final currentState = state;
      if (currentState.generationState != GenerationState.arReady ||
          currentState.modelResponse == null ||
          currentState.modelResponse?.localFilePath == null) {
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

    // Find the first plane hit test result
    final planeHitTestResult = hitTestResults.firstWhere(
      (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.first,
    );

    // Create ARPlaneAnchor at the tap location
    final newAnchor = ARPlaneAnchor(
      transformation: planeHitTestResult.worldTransform,
    );

    // Remove existing anchor and model if any
    if (_currentAnchor != null) {
      _arAnchorManager!.removeAnchor(_currentAnchor!);
      _currentAnchor = null;
    }
    if (_currentModelNode != null) {
      _arObjectManager!.removeNode(_currentModelNode!);
      _currentModelNode = null;
    }

    // Add anchor
    final didAddAnchor = await _arAnchorManager!.addAnchor(newAnchor);

    if (didAddAnchor == true) {
      _currentAnchor = newAnchor;

      // Place GLB model at anchor
      final node = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: currentState.modelResponse!.localFilePath!, // e.g., "tiger.glb"
        scale: vector.Vector3(16, 16, 16),
        position: vector.Vector3(0.0, 0.0, 0.0),
      );

      debugPrint('🔍 Placing GLB model at anchor: ${newAnchor.name}');
      debugPrint('   Node type: ${node.type}');
      debugPrint('   URI: ${node.uri}');

      final didAddNode =
          await _arObjectManager!.addNode(node, planeAnchor: newAnchor);

      if (didAddNode == true) {
        _currentModelNode = node;
        emit(state.copyWith(isModelPlaced: true));
        debugPrint('✅ Model placed at anchor: ${newAnchor.name}');
      } else {
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

      // Small delay for UI feedback
      await Future.delayed(const Duration(milliseconds: 500));

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

      // Auto reset after error
      await Future.delayed(const Duration(seconds: 3));
      reset();
    }
  }

  /// Clear the current model from AR scene
  void clearModel() {
    if (_currentModelNode != null && _arObjectManager != null) {
      _arObjectManager!.removeNode(_currentModelNode!);
      _currentModelNode = null;
    }
    if (_currentAnchor != null && _arAnchorManager != null) {
      _arAnchorManager!.removeAnchor(_currentAnchor!);
      _currentAnchor = null;
    }
    debugPrint('ARView: Model cleared from scene');
  }

  /// Dispose AR resources
  void disposeAR() {
    clearModel();
    _arSessionManager?.dispose();
  }

  /// Reset AR state to idle
  Future<void> reset() async {
    // Clear model from AR scene when resetting
    clearModel();

    emit(state.copyWith(
      generationState: GenerationState.idle,
      errorMessage: null,
      clearModelResponse: true,
      isModelPlaced: false,
    ));
  }

  // change selected mode
  void updateMode(GenerationMode mode) {
    emit(state.copyWith(generationMode: mode));
  }
}
