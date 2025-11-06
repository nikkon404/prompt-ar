import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_event.dart';
import '../../bloc/ar_bloc/ar_bloc.dart';
import '../../bloc/ar_bloc/ar_state.dart';
import '../../models/generation_state.dart';
import 'widgets/ar_loading_overlay.dart';
import 'widgets/ar_error_overlay.dart';
import 'widgets/ar_instruction_text.dart';
import 'widgets/ar_prompt_input.dart';

class ARViewPage extends StatefulWidget {
  const ARViewPage({super.key});

  @override
  State<ARViewPage> createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
  @override
  void dispose() {
    context.read<ARBloc>().disposeAR();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PromptAR'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: BlocProvider(
        create: (context) => ARBloc(),
        child: BlocBuilder<ARBloc, ARState>(
          builder: (context, arState) {
            return Stack(
              children: [
                // AR Scene View
                ARKitSceneView(
                  showFeaturePoints: true,
                  enableTapRecognizer: true,
                  planeDetection: ARPlaneDetection.horizontalAndVertical,
                  autoenablesDefaultLighting: false,
                  onARKitViewCreated: (controller) {
                    context.read<ARBloc>().add(ARInitialize(controller));
                  },
                ),

                // Instruction text when model is ready
                if (arState.generationState == GenerationState.arReady)
                  const ARInstructionText(),

                // Loading overlay
                if ([
                  GenerationState.processing,
                  GenerationState.downloading,
                  GenerationState.initial,
                ].contains(arState.generationState))
                  ARLoadingOverlay(state: arState.generationState),

                // Error overlay
                if (arState.generationState == GenerationState.error)
                  ARErrorOverlay(errorMessage: arState.errorMessage),

                // Prompt input at bottom (only show when idle or error)
                if (arState.generationState == GenerationState.idle ||
                    arState.generationState == GenerationState.error)
                  const ARPromptInput(),
              ],
            );
          },
        ),
      ),
    );
  }
}
