import 'package:equatable/equatable.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';

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

/// Initialize AR session with managers
class ARInitialize extends AREvent {
  final ARSessionManager sessionManager;
  final ARObjectManager objectManager;
  final ARAnchorManager anchorManager;
  final ARLocationManager locationManager;

  const ARInitialize({
    required this.sessionManager,
    required this.objectManager,
    required this.anchorManager,
    required this.locationManager,
  });

  @override
  List<Object?> get props => [sessionManager, objectManager, anchorManager, locationManager];
}

/// Handle tap event on AR plane
class ARHandleTap extends AREvent {
  final List<ARHitTestResult> hitTestResults;

  const ARHandleTap(this.hitTestResults);

  @override
  List<Object?> get props => [hitTestResults];
}
