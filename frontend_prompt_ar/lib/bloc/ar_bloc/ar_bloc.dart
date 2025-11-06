import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/generation_state.dart';
import '../../repositories/model_repository.dart';
import '../../services/download_service.dart';
import 'ar_event.dart';
import 'ar_state.dart';

/// BLoC for managing AR model generation
class ARBloc extends Bloc<AREvent, ARState> {
  final ModelRepository _repository;
  final DownloadService _downloadService;
  ARKitController? _arkitController;
  ARKitNode? _currentModelNode;

  ARBloc({
    ModelRepository? repository,
    DownloadService? downloadService,
  })  : _repository = repository ?? ModelRepository(),
        _downloadService = downloadService ?? DownloadService(),
        super(const ARState(generationState: GenerationState.initial)) {
    on<ARGenerate>(_onGenerate);
    on<ARReset>(_onReset);
    on<ARUpdatePrompt>(_onUpdatePrompt);
    on<ARInitialize>(_onInitialize);
  }

  FutureOr<void> _onInitialize(ARInitialize event, Emitter<ARState> emit) {
    _arkitController = event.controller;

    // Set tap handler for placing models (only works when model is ready)
    _arkitController?.onARTap = (ar) {
      final currentState = state;
      if (currentState.generationState != GenerationState.arReady ||
          currentState.modelResponse == null ||
          currentState.modelResponse?.localFilePath == null) {
        debugPrint('ARView: Tap ignored - model not ready');
        return;
      }

      final point = ar.firstWhereOrNull(
        (o) => o.type == ARKitHitTestResultType.featurePoint,
      );
      if (point != null) {
        handleARTap(point, currentState.modelResponse!.localFilePath!);
      }
    };

    // Add lighting to make models brighter
    if (_arkitController != null) {
      _addLightingToScene(_arkitController!);
    }

    debugPrint('ARView: AR session initialized');

    emit(state.copyWith(generationState: GenerationState.idle));
  }

  /// Add directional lighting to the AR scene
  void _addLightingToScene(ARKitController arkitController) {
    // Add a directional light pointing down to simulate overhead lighting
    final light = ARKitLight(
      type: ARKitLightType.directional,
      color: Colors.white,
    );

    // Set intensity to make it bright
    light.intensity.value = 2000; // High intensity for brightness

    final lightNode = ARKitNode(
      light: light,
      position: vector.Vector3(0, 2, 0), // Position light above the scene
      eulerAngles:
          vector.Vector3(-1.5708, 0, 0), // Rotate to point down (90 degrees)
      name: 'directional_light',
    );

    arkitController.add(lightNode);
    debugPrint(
        '💡 Added directional light to AR scene (intensity: ${light.intensity.value})');
  }

  /// Handle AR tap event to place model
  void handleARTap(ARKitTestResult point, String localFilePath) {
    if (_arkitController == null) {
      debugPrint('ARView: ARKit controller not initialized');
      return;
    }

    final position = vector.Vector3(
      point.worldTransform.getColumn(3).x,
      point.worldTransform.getColumn(3).y,
      point.worldTransform.getColumn(3).z,
    );

    // Remove existing model if any
    if (_currentModelNode != null) {
      _arkitController!.remove(_currentModelNode!.name);
      _currentModelNode = null;
    }

    // Extract just the filename from the full path
    // ARKit expects just the filename when using AssetType.documents
    final fileName = localFilePath.split('/').last;

    debugPrint('ARView: Creating ARKitGltfNode from local file');
    debugPrint('ARView: Local file path: $localFilePath');
    debugPrint('ARView: File name: $fileName');

    // Create GLB node from local file path
    final node = ARKitGltfNode(
      assetType: AssetType.documents,
      url: fileName,
      scale: vector.Vector3(0.7, 0.7, 0.7),
      position: position,
    );

    _arkitController!.add(node);
    _currentModelNode = node;
    debugPrint('✅ Model placed on plane at: $position');
  }

  /// Clear the current model from AR scene
  void clearModel() {
    if (_currentModelNode != null && _arkitController != null) {
      _arkitController!.remove(_currentModelNode!.name);
      _currentModelNode = null;
      debugPrint('ARView: Model cleared from scene');
    }
  }

  /// Dispose AR resources
  void disposeAR() {
    clearModel();
    _arkitController?.dispose();
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

      // Downloading state - downloading model file
      final localFilePath = await _downloadService.downloadModel(
        response.downloadUrl,
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
