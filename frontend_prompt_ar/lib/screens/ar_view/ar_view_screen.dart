import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import '../../bloc/ar_bloc/ar_cubit.dart';
import '../../bloc/ar_bloc/ar_state.dart';
import '../../models/generation_state.dart';
import 'widgets/ar_loading_overlay.dart';
import 'widgets/ar_error_overlay.dart';
import 'widgets/ar_instruction_text.dart';
import 'widgets/bottom/bottom_widget.dart';

class ARViewPage extends StatefulWidget {
  const ARViewPage({super.key});

  @override
  State<ARViewPage> createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
  @override
  void dispose() {
    if (context.mounted) {
      context.read<ARCubit>().disposeAR();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PromptAR'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // ask for confirmation
            final confirmed = await showDialog(
              context: context,
              builder: (context) => AlertDialog.adaptive(
                title: const Text('Confirmation'),
                content: const Text(
                    'Are you sure you want to go back? This will clear the current model from the AR scene.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            if (confirmed && context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: BlocProvider(
        create: (context) => ARCubit(),
        child: BlocConsumer<ARCubit, ARState>(
          // show info dialof once  state is ready and previous state was not ready
          listenWhen: (previous, current) =>
              (previous.generationState != GenerationState.arReady &&
                  current.generationState == GenerationState.arReady),

          listener: (context, state) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog.adaptive(
                content: const Column(
                  children: [
                    // success icon
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 30,
                    ),
                    SizedBox(height: 10),
                    Text(
                        'The 3D model has been loaded into the AR scene. Tap on a detected surface to place the model.'),
                    SizedBox(height: 16),
                    Icon(
                      Icons.touch_app_outlined,
                      color: Colors.white,
                      size: 70,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
          builder: (context, arState) {
            return Stack(
              children: [
                // AR View (using ar_flutter_plugin_2)
                ARView(
                  onARViewCreated: (
                    ARSessionManager sessionManager,
                    ARObjectManager objectManager,
                    ARAnchorManager anchorManager,
                    ARLocationManager locationManager,
                  ) {
                    context.read<ARCubit>().initialize(
                          sessionManager: sessionManager,
                          objectManager: objectManager,
                          anchorManager: anchorManager,
                        );
                  },
                  planeDetectionConfig:
                      PlaneDetectionConfig.horizontalAndVertical,
                ),

                const ARInstructionText(),

                // Loading overlay
                if ([
                  GenerationState.generating,
                  GenerationState.downloading,
                  GenerationState.initial,
                ].contains(arState.generationState))
                  ARLoadingOverlay(
                    state: arState.generationState,
                    mode: arState.generationMode,
                    prompt: arState.currentPrompt,
                  ),

                // Error overlay
                if (arState.generationState == GenerationState.error)
                  ARErrorOverlay(errorMessage: arState.errorMessage),

                // Prompt input at bottom (always visible except when loading or error)
                if ([
                  GenerationState.arReady,
                  GenerationState.idle,
                ].contains(arState.generationState))
                  const BottomWidget(),

                // top right section with a clear scene button
                const _ClearAllButton(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      top: size.height * 0.038,
      right: size.width * 0.03,
      child: BlocBuilder<ARCubit, ARState>(
        buildWhen: (previous, current) =>
            //   build only when placedModelIds length changes from 0 to non-zero or vice versa
            previous.placedModelIds.isEmpty &&
                current.placedModelIds.isNotEmpty ||
            previous.placedModelIds.isNotEmpty &&
                current.placedModelIds.isEmpty,
        builder: (context, state) {
          if (state.placedModelIds.isEmpty) {
            return const SizedBox.shrink();
          }
          return CircleAvatar(
            child: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Scene',
              onPressed: () async {
                final cubit = context.read<ARCubit>();
                final state = cubit.state;
                final confirmed = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog.adaptive(
                    title: const Text('Clear Scene'),
                    content: Text(
                      'This will clear all ${state.placedModelIds.length} item(s) from the scene?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  cubit.clearScene();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
