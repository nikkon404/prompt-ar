import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:equatable/equatable.dart';

/// Events for AR BLoC
abstract class AREvent extends Equatable {
  const AREvent();

  @override
  List<Object?> get props => [];
}

/// Generate model from prompt
class ARGenerate extends AREvent {
  final String prompt;

  const ARGenerate(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

/// Reset AR state to idle
class ARReset extends AREvent {
  const ARReset();
}

/// Update prompt text
class ARUpdatePrompt extends AREvent {
  final String prompt;

  const ARUpdatePrompt(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

/// Update prompt text
class ARInitialize extends AREvent {
  final ARKitController controller;
  const ARInitialize(this.controller);

  @override
  List<Object?> get props => [controller];
}
