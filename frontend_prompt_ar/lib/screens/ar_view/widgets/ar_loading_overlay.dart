import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_bloc.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_state.dart';
import '../../../models/generation_state.dart';

/// Loading overlay widget for AR view
class ARLoadingOverlay extends StatelessWidget {
  final GenerationState state;

  const ARLoadingOverlay({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    String message = "";
    switch (state) {
      case GenerationState.processing:
        message = 'Generating 3D model...\nThis may take 5-10 seconds';
        break;
      case GenerationState.downloading:
        message = 'Downloading model...';
        break;
      default:
        message = 'Please wait...';
    }

    return BlocBuilder<ARBloc, ARState>(
      builder: (context, state) {
        return Container(
          color: Colors.black.withOpacity(0.65),
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
                  message,
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
      },
    );
  }
}
