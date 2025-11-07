import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/models/generation_state.dart';
import '../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../bloc/ar_bloc/ar_state.dart';

/// Instruction text widget displayed when model is ready for placement
class ARInstructionText extends StatelessWidget {
  const ARInstructionText({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ARCubit, ARState>(
      builder: (context, s) {
        final state = s.generationState;

        String text = "";

        if (state == GenerationState.idle && !s.isModelPlaced) {
          text = "Enter a prompt to generate a 3D model.";
        } else if (state == GenerationState.arReady && !s.isModelPlaced) {
          text = "Tap on the screen to place the model in AR.";
        }

        if (text.isEmpty) {
          return const SizedBox.shrink();
        }

        final size = MediaQuery.of(context).size;
        return Positioned(
          top: size.height * 0.014,
          left: size.width * 0.16,
          right: size.width * 0.16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
