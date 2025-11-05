import 'package:equatable/equatable.dart';

/// Events for Camera BLoC
abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize camera
class CameraInitialize extends CameraEvent {
  const CameraInitialize();
}

/// Switch camera (front/back)
class CameraSwitchCamera extends CameraEvent {
  const CameraSwitchCamera();
}

/// Dispose camera
class CameraDispose extends CameraEvent {
  const CameraDispose();
}

