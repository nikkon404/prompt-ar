import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/generation_state.dart';
import '../../repositories/model_repository.dart';
import 'model_event.dart';
import 'model_state.dart';

/// BLoC for managing model generation
class ModelBloc extends Bloc<ModelEvent, ModelState> {
  final ModelRepository _repository;

  ModelBloc({ModelRepository? repository})
      : _repository = repository ?? ModelRepository(),
        super(const ModelState()) {
    on<ModelGenerate>(_onGenerate);
    on<ModelReset>(_onReset);
    on<ModelUpdatePrompt>(_onUpdatePrompt);
  }

  Future<void> _onGenerate(
    ModelGenerate event,
    Emitter<ModelState> emit,
  ) async {
    if (event.prompt.trim().isEmpty) {
      return;
    }

    try {
      // Processing state
      emit(state.copyWith(
        generationState: GenerationState.processing,
        currentPrompt: event.prompt,
      ));

      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Downloading state
      emit(state.copyWith(
        generationState: GenerationState.downloading,
      ));

      // Generate model (currently returns dummy response)
      final response = await _repository.generateModel(event.prompt);

      // Applying state
      emit(state.copyWith(
        generationState: GenerationState.applying,
        modelResponse: response,
      ));

      await Future.delayed(const Duration(seconds: 1));

      // AR Ready state
      emit(state.copyWith(
        generationState: GenerationState.arReady,
      ));
    } catch (e) {
      emit(state.copyWith(
        generationState: GenerationState.error,
        errorMessage: e.toString(),
      ));

      // Auto reset after error
      await Future.delayed(const Duration(seconds: 3));
      add(const ModelReset());
    }
  }

  Future<void> _onReset(
    ModelReset event,
    Emitter<ModelState> emit,
  ) async {
    emit(state.copyWith(
      generationState: GenerationState.idle,
      errorMessage: null,
    ));
  }

  Future<void> _onUpdatePrompt(
    ModelUpdatePrompt event,
    Emitter<ModelState> emit,
  ) async {
    emit(state.copyWith(currentPrompt: event.prompt));
  }
}

