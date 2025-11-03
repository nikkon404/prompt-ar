import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/model_provider.dart';

/// Service for handling model generation business logic
class ModelService {
  final Ref ref;

  ModelService(this.ref);

  /// Generate a model from the current prompt
  Future<void> generateModel() async {
    final prompt = ref.read(promptProvider);
    
    if (prompt.isEmpty) {
      return;
    }

    final repository = ref.read(modelRepositoryProvider);
    final stateNotifier = ref.read(generationStateProvider.notifier);

    try {
      stateNotifier.setLoading();
      
      final response = await repository.generateModel(prompt);
      
      ref.read(modelResponseProvider.notifier).state = response;
      stateNotifier.setSuccess();
      
      // Reset to idle after a delay
      Future.delayed(const Duration(seconds: 2), () {
        stateNotifier.reset();
      });
    } catch (e) {
      stateNotifier.setError();
      
      // Reset to idle after a delay
      Future.delayed(const Duration(seconds: 2), () {
        stateNotifier.reset();
      });
    }
  }
}

/// Provider for ModelService
final modelServiceProvider = Provider<ModelService>((ref) {
  return ModelService(ref);
});

