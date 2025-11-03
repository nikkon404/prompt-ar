import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Widget for displaying camera preview
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(controller),
    );
  }
}

