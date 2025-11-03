import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/model_response.dart';
import '../models/generation_state.dart';
import '../repositories/model_repository.dart';

/// Provider for ModelRepository
final modelRepositoryProvider = Provider<ModelRepository>((ref) {
  return ModelRepository();
});

/// Provider for generation state
final generationStateProvider = StateNotifierProvider<GenerationStateNotifier, GenerationState>((ref) {
  return GenerationStateNotifier();
});

/// Provider for the generated model response
final modelResponseProvider = StateProvider<ModelResponse?>((ref) => null);

/// State notifier for managing generation state
class GenerationStateNotifier extends StateNotifier<GenerationState> {
  GenerationStateNotifier() : super(GenerationState.idle);

  void setLoading() {
    state = GenerationState.loading;
  }

  void setSuccess() {
    state = GenerationState.success;
  }

  void setError() {
    state = GenerationState.error;
  }

  void reset() {
    state = GenerationState.idle;
  }
}

/// Provider for prompt input
final promptProvider = StateProvider<String>((ref) => '');

