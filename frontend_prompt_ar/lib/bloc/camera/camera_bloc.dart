import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'camera_event.dart';
import 'camera_state.dart';

/// BLoC for managing camera functionality
class CameraBloc extends Bloc<CameraEvent, CameraState> {
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  CameraController? _controller;

  CameraBloc() : super(const CameraInitial()) {
    on<CameraInitialize>(_onInitialize);
    on<CameraSwitchCamera>(_onSwitchCamera);
    on<CameraDispose>(_onDispose);
  }

  Future<void> _onInitialize(
    CameraInitialize event,
    Emitter<CameraState> emit,
  ) async {
    emit(const CameraLoading());

    try {
      // Get available cameras
      _availableCameras = await availableCameras();

      if (_availableCameras.isEmpty) {
        emit(const CameraError('No cameras available'));
        return;
      }

      // Find back camera index, default to 0
      _currentCameraIndex = _availableCameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex == -1) {
        _currentCameraIndex = 0;
      }

      // Initialize camera controller
      await _initializeController();

      emit(CameraReady(
        controller: _controller!,
        availableCameras: _availableCameras,
        currentCameraIndex: _currentCameraIndex,
      ));
    } catch (e) {
      emit(CameraError('Failed to initialize camera: $e'));
    }
  }

  Future<void> _onSwitchCamera(
    CameraSwitchCamera event,
    Emitter<CameraState> emit,
  ) async {
    if (_availableCameras.length <= 1) {
      return; // Can't switch if only one camera
    }

    emit(const CameraLoading());

    try {
      // Dispose current controller
      await _controller?.dispose();

      // Switch to next camera
      _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;

      // Initialize new controller
      await _initializeController();

      emit(CameraReady(
        controller: _controller!,
        availableCameras: _availableCameras,
        currentCameraIndex: _currentCameraIndex,
      ));
    } catch (e) {
      emit(CameraError('Failed to switch camera: $e'));
    }
  }

  Future<void> _onDispose(
    CameraDispose event,
    Emitter<CameraState> emit,
  ) async {
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializeController() async {
    final camera = _availableCameras[_currentCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  @override
  Future<void> close() {
    _controller?.dispose();
    return super.close();
  }
}

