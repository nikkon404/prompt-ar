import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/generation_state.dart';
import '../../repositories/model_repository.dart';
import '../../services/download_service.dart';
import '../../services/network_service.dart';
import 'ar_event.dart';
import 'ar_state.dart';

/// BLoC for managing AR model generation
class ARBloc extends Bloc<AREvent, ARState> {
  final ModelRepository _repository;
  final DownloadService _downloadService;
  final NetworkService _networkService;
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  ARNode? _currentModelNode;
  ARPlaneAnchor? _currentAnchor;

  ARBloc({
    ModelRepository? repository,
    DownloadService? downloadService,
    NetworkService? networkService,
  })  : _repository = repository ?? ModelRepository(),
        _downloadService = downloadService ?? DownloadService(),
        _networkService = networkService ?? NetworkService(),
        super(const ARState(generationState: GenerationState.initial)) {
    on<ARGenerate>(_onGenerate);
    on<ARReset>(_onReset);
    on<ARUpdatePrompt>(_onUpdatePrompt);
    on<ARInitialize>(_onInitialize);
    on<ARHandleTap>(_onHandleTap);
  }

  FutureOr<void> _onInitialize(ARInitialize event, Emitter<ARState> emit) {
    _arSessionManager = event.sessionManager;
    _arObjectManager = event.objectManager;
    _arAnchorManager = event.anchorManager;

    // Initialize AR session
    _arSessionManager?.onInitialize(
      showAnimatedGuide: false, // Hide instruction overlay
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handlePans: true,
      handleRotation: true,
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

      // Dispatch tap event to handle model placement
      add(ARHandleTap(hitTestResults));
    };

    debugPrint('ARView: AR session initialized');

    emit(state.copyWith(generationState: GenerationState.idle));
  }

  FutureOr<void> _onHandleTap(ARHandleTap event, Emitter<ARState> emit) async {
    if (_arObjectManager == null || _arAnchorManager == null) {
      debugPrint('ARView: AR managers not initialized');
      return;
    }

    final currentState = state;
    if (currentState.modelResponse?.localFilePath == null) {
      debugPrint('ARView: No model file path available');
      return;
    }

    final hitTestResults = event.hitTestResults;
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
      );

      debugPrint('🔍 Placing GLB model at anchor: ${newAnchor.name}');
      debugPrint('   Node type: ${node.type}');
      debugPrint('   URI: ${node.uri}');

      final didAddNode = await _arObjectManager!.addNode(node, planeAnchor: newAnchor);

      if (didAddNode == true) {
        _currentModelNode = node;
        debugPrint('✅ Model placed at anchor: ${newAnchor.name}');
      } else {
        debugPrint('❌ Failed to place model at anchor: ${newAnchor.name}');
      }
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

  Future<void> _onGenerate(
    ARGenerate event,
    Emitter<ARState> emit,
  ) async {
    if (event.prompt.trim().isEmpty) {
      return;
    }

    try {
      // Processing state - generating model on backend
      emit(state.copyWith(
        generationState: GenerationState.processing,
        currentPrompt: event.prompt,
      ));

      // Generate model from backend
      final response = await _repository.generateModel(event.prompt);
      emit(state.copyWith(
        generationState: GenerationState.downloading,
        modelResponse: response,
      ));

      // Downloading state - downloading GLB model directly
      // Brightness normalization is already applied to GLB during generation
      // Single file download (faster, simpler than GLTF zip)
      final downloadUrl = '${_networkService.baseUrl}/api/models/download/${response.modelId}';
      final localFilePath = await _downloadService.downloadModel(
        downloadUrl,
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
      add(const ARReset());
    }
  }

  Future<void> _onReset(
    ARReset event,
    Emitter<ARState> emit,
  ) async {
    // Clear model from AR scene when resetting
    clearModel();

    emit(state.copyWith(
      generationState: GenerationState.idle,
      errorMessage: null,
      clearModelResponse: true,
    ));
  }

  Future<void> _onUpdatePrompt(
    ARUpdatePrompt event,
    Emitter<ARState> emit,
  ) async {
    emit(state.copyWith(currentPrompt: event.prompt));
  }
}
