import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/camera/camera_bloc.dart';
import '../bloc/camera/camera_event.dart';
import '../bloc/camera/camera_state.dart';
import '../bloc/model/model_bloc.dart';
import '../bloc/model/model_event.dart';
import '../bloc/model/model_state.dart';
import '../models/generation_state.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/prompt_input_widget.dart';
import '../widgets/ar_view_widget.dart';

/// Main screen with camera view and prompt input
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize camera when screen loads
    context.read<CameraBloc>().add(const CameraInitialize());
  }

  String _getLoadingMessage(GenerationState state) {
    switch (state) {
      case GenerationState.processing:
        return 'Please wait...\nGenerating your 3D model...';
      case GenerationState.downloading:
        return 'Please wait...\nDownloading model...';
      case GenerationState.applying:
        return 'Please wait...\nApplying model to AR...';
      default:
        return 'Please wait...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelBloc, ModelState>(
      builder: (context, modelState) {
        // Show AR view when ready
        if (modelState.generationState == GenerationState.arReady &&
            modelState.modelResponse != null &&
            modelState.modelResponse!.localFilePath != null) {
          return ARViewWidget(
            modelFilePath: modelState.modelResponse!.localFilePath!,
            onClose: () {
              context.read<ModelBloc>().add(const ModelReset());
            },
          );
        }

        return Scaffold(
          body: BlocBuilder<CameraBloc, CameraState>(
            builder: (context, cameraState) {
              return Stack(
                children: [
                  // Camera preview
                  _buildCameraPreview(cameraState),

                  // Flip camera button
                  if (cameraState is CameraReady &&
                      cameraState.hasMultipleCameras &&
                      modelState.generationState == GenerationState.idle)
                    _buildFlipCameraButton(context),

                  // Loading overlay for processing, downloading, or applying
                  if (modelState.generationState == GenerationState.processing ||
                      modelState.generationState == GenerationState.downloading ||
                      modelState.generationState == GenerationState.applying)
                    _buildLoadingOverlay(modelState.generationState),

                  // Error overlay
                  if (modelState.generationState == GenerationState.error)
                    _buildErrorOverlay(context),

                  // Prompt input widget (floating at bottom) - only show when idle
                  if (modelState.generationState == GenerationState.idle ||
                      modelState.generationState == GenerationState.error)
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: PromptInputWidget(),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview(CameraState cameraState) {
    if (cameraState is CameraLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (cameraState is CameraError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Camera error: ${cameraState.message}',
              style: const TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (cameraState is CameraReady) {
      return CameraPreviewWidget(controller: cameraState.controller);
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Camera not available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipCameraButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.read<CameraBloc>().add(const CameraSwitchCamera());
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(GenerationState state) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 4,
            ),
            const SizedBox(height: 32),
            Text(
              _getLoadingMessage(state),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong. Please try again.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.read<ModelBloc>().add(const ModelReset());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
