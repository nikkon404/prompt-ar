import 'package:equatable/equatable.dart';
import '../../models/generation_state.dart';
import '../../models/model_response.dart';

/// States for Model BLoC
class ModelState extends Equatable {
  final GenerationState generationState;
  final ModelResponse? modelResponse;
  final String currentPrompt;
  final String? errorMessage;

  const ModelState({
    this.generationState = GenerationState.idle,
    this.modelResponse,
    this.currentPrompt = '',
    this.errorMessage,
  });

  ModelState copyWith({
    GenerationState? generationState,
    ModelResponse? modelResponse,
    String? currentPrompt,
    String? errorMessage,
  }) {
    return ModelState(
      generationState: generationState ?? this.generationState,
      modelResponse: modelResponse ?? this.modelResponse,
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

