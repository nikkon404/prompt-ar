import 'package:equatable/equatable.dart';
import '../../models/generation_state.dart';
import '../../models/model_response.dart';

/// States for AR BLoC
class ARState extends Equatable {
  final GenerationState generationState;
  final ModelResponse? modelResponse;
  final String currentPrompt;
  final String? errorMessage;
  final bool isModelPlaced; // Whether model has been placed in AR scene

  const ARState({
    this.generationState = GenerationState.idle,
    this.modelResponse,
    this.currentPrompt = '',
    this.errorMessage,
    this.isModelPlaced = false,
  });

  ARState copyWith({
    GenerationState? generationState,
    ModelResponse? modelResponse,
    String? currentPrompt,
    String? errorMessage,
    bool clearModelResponse = false,
    bool? isModelPlaced,
  }) {
    return ARState(
      generationState: generationState ?? this.generationState,
      modelResponse: clearModelResponse ? null : (modelResponse ?? this.modelResponse),
      currentPrompt: currentPrompt ?? this.currentPrompt,
      errorMessage: errorMessage,
      isModelPlaced: isModelPlaced ?? this.isModelPlaced,
    );
  }

  @override
  List<Object?> get props => [
        generationState,
        modelResponse,
        currentPrompt,
        errorMessage,
        isModelPlaced,
      ];
}

