import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';

/// States for Camera BLoC
abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class CameraInitial extends CameraState {
  const CameraInitial();
}

/// Camera is loading/initializing
class CameraLoading extends CameraState {
  const CameraLoading();
}

/// Camera is ready with controller
class CameraReady extends CameraState {
  final CameraController controller;
  final List<CameraDescription> availableCameras;
  final int currentCameraIndex;

  const CameraReady({
    required this.controller,
    required this.availableCameras,
    required this.currentCameraIndex,
  });

  @override
  List<Object?> get props => [controller, availableCameras, currentCameraIndex];

  bool get hasMultipleCameras => availableCameras.length > 1;
}

/// Camera error state
class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}

