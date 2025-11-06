import 'package:equatable/equatable.dart';
import '../../models/generation_state.dart';
import '../../models/model_response.dart';

/// States for AR BLoC
class ARState extends Equatable {
  final GenerationState generationState;
  final ModelResponse? modelResponse;
  final String currentPrompt;
  final String? errorMessage;

  const ARState({
    this.generationState = GenerationState.idle,
    this.modelResponse,
    this.currentPrompt = '',
    this.errorMessage,
  });

  ARState copyWith({
    GenerationState? generationState,
    ModelResponse? modelResponse,
    String? currentPrompt,
    String? errorMessage,
    bool clearModelResponse = false,
  }) {
    return ARState(
      generationState: generationState ?? this.generationState,
      modelResponse: clearModelResponse ? null : (modelResponse ?? this.modelResponse),
      currentPrompt: currentPrompt ?? this.currentPrompt,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        generationState,
        modelResponse,
        currentPrompt,
        errorMessage,
      ];
}

