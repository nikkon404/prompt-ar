import 'package:equatable/equatable.dart';

/// Events for Model BLoC
abstract class ModelEvent extends Equatable {
  const ModelEvent();

  @override
  List<Object?> get props => [];
}

/// Generate model from prompt
class ModelGenerate extends ModelEvent {
  final String prompt;

  const ModelGenerate(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

/// Reset model state to idle
class ModelReset extends ModelEvent {
  const ModelReset();
}

/// Update prompt text
class ModelUpdatePrompt extends ModelEvent {
  final String prompt;

  const ModelUpdatePrompt(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

