import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/screens/ar_view/widgets/bottom/show_downloaded_models.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../../bloc/ar_bloc/ar_state.dart';
import '../../../../models/generation_state.dart';
import 'submit_button.dart';
import 'text_input.dart';
import 'mode_picker.dart';

/// Floating prompt input widget for AR view
class BottomWidget extends StatefulWidget {
  const BottomWidget({super.key});

  @override
  State<BottomWidget> createState() => _BottomWidgetState();
}

class _BottomWidgetState extends State<BottomWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ARCubit, ARState>(
      builder: (context, state) {
        final isLoading = state.generationState == GenerationState.generating ||
            state.generationState == GenerationState.downloading;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Mode picker
                  const ModePicker(),
                  // Text input and buttons row
                  Row(
                    children: [
                      // Load models button
                      const ShowDownloadedModels(),
                      const SizedBox(width: 12),

                      // Text input field
                      Expanded(
                        child: TextInput(
                            textController: _textController,
                            focusNode: _focusNode,
                            isLoading: isLoading),
                      ),
                      const SizedBox(width: 12),

                      // Submit button
                      SubmitButton(
                          isLoading: isLoading,
                          textController: _textController,
                          focusNode: _focusNode),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
