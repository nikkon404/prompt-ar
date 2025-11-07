import 'package:equatable/equatable.dart';
import 'package:prompt_ar/models/generation_mode.dart';
import '../../models/generation_state.dart';
import '../../models/model_response.dart';

/// States for AR BLoC
class ARState extends Equatable {
  final GenerationState generationState;
  final ModelResponse? modelResponse;
  final String currentPrompt;
  final String? errorMessage;
  final GenerationMode generationMode;
  final bool isCameraEnabled; // Whether camera is currently enabled
  final List<String>? downloadedModels; // List of downloaded model IDs
  final List<String>
      placedModelIds; // List of model IDs that are placed in the scene
  const ARState({
    this.generationState = GenerationState.initial,
    this.modelResponse,
    this.currentPrompt = '',
    this.errorMessage,
    this.generationMode = GenerationMode.basic,
    this.isCameraEnabled = true, // Camera is enabled by default
    this.downloadedModels,
    this.placedModelIds = const [],
  });

  ARState copyWith({
    GenerationState? generationState,
    ModelResponse? modelResponse,
    String? currentPrompt,
    String? errorMessage,
    bool clearModelResponse = false,
    GenerationMode? generationMode,
    bool? isCameraEnabled,
    List<String>? downloadedModels,
    List<String>? placedModelIds,
  }) {
    return ARState(
      generationState: generationState ?? this.generationState,
      modelResponse:
          clearModelResponse ? null : (modelResponse ?? this.modelResponse),
      currentPrompt: currentPrompt ?? this.currentPrompt,
      errorMessage: errorMessage,
      generationMode: generationMode ?? this.generationMode,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      downloadedModels: downloadedModels ?? this.downloadedModels,
      placedModelIds: placedModelIds ?? this.placedModelIds,
    );
  }

  //  getter for isModelPlaced check if placedModelIds is not empty
  bool get isModelPlaced => placedModelIds.isNotEmpty;

  @override
  List<Object?> get props => [
        generationState,
        modelResponse,
        currentPrompt,
        errorMessage,
        isModelPlaced,
        generationMode,
        isCameraEnabled,
        downloadedModels,
        placedModelIds,
      ];
}
