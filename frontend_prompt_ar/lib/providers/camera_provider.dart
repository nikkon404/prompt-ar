import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for available cameras list
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  try {
    final cameras = await availableCameras();
    return cameras;
  } catch (e) {
    return [];
  }
});

/// State notifier for managing camera controller and switching
class CameraControllerNotifier extends StateNotifier<AsyncValue<CameraController?>> {
  CameraControllerNotifier(this.cameras, this.currentCameraIndex) : super(const AsyncValue.loading()) {
    _initializeCamera();
  }

  final List<CameraDescription> cameras;
  int currentCameraIndex;

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    if (currentCameraIndex >= cameras.length) {
      currentCameraIndex = 0;
    }

    try {
      final camera = cameras[currentCameraIndex];
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      state = AsyncValue.data(controller);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> switchCamera() async {
    if (cameras.length <= 1) {
      return; // Can't switch if there's only one camera
    }

    // Save current controller before disposing
    final currentController = state.valueOrNull;

    // Set state to loading first
    state = const AsyncValue.loading();

    // Dispose previous controller
    if (currentController != null) {
      await currentController.dispose();
    }

    // Switch to next camera
    currentCameraIndex = (currentCameraIndex + 1) % cameras.length;
    await _initializeCamera();
  }

  @override
  void dispose() {
    final controller = state.valueOrNull;
    controller?.dispose();
    super.dispose();
  }
}

/// Provider for camera controller with switching capability
final cameraControllerProvider = StateNotifierProvider<CameraControllerNotifier, AsyncValue<CameraController?>>((ref) {
  final camerasAsync = ref.watch(availableCamerasProvider);
  
  return camerasAsync.when(
    data: (cameras) {
      // Start with back camera if available, otherwise first camera
      int initialIndex = 0;
      if (cameras.isNotEmpty) {
        final backCameraIndex = cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        if (backCameraIndex != -1) {
          initialIndex = backCameraIndex;
        }
      }
      return CameraControllerNotifier(cameras, initialIndex);
    },
    loading: () => CameraControllerNotifier([], 0),
    error: (_, __) => CameraControllerNotifier([], 0),
  );
});

/// Legacy provider for backward compatibility (deprecated, use cameraControllerProvider)
final cameraProvider = FutureProvider<CameraController?>((ref) async {
  final controllerAsync = ref.watch(cameraControllerProvider);
  return controllerAsync.valueOrNull;
});

