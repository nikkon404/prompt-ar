import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../bloc/ar_bloc/ar_state.dart';
import '../../../models/generation_state.dart';
import '../../../models/generation_mode.dart';

/// Floating prompt input widget for AR view
class ARPromptInput extends StatefulWidget {
  const ARPromptInput({super.key});

  @override
  State<ARPromptInput> createState() => _ARPromptInputState();
}

class _ARPromptInputState extends State<ARPromptInput> {
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode picker
                  const ModePicker(),
                  // Text input and submit button row
                  Row(
                    children: [
                      // Text input field
                      Expanded(
                        child: _TextInput(
                            textController: _textController,
                            focusNode: _focusNode,
                            isLoading: isLoading),
                      ),
                      const SizedBox(width: 12),

                      // Submit button
                      Container(
                        decoration: BoxDecoration(
                          color: isLoading
                              ? Colors.grey.shade600
                              : Colors.deepPurple.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final prompt = _textController.text.trim();
                              // should only contain alphanumeric and spaces
                              final validCharacters =
                                  RegExp(r'^[a-zA-Z0-9 ]+$');
                              if (!validCharacters.hasMatch(prompt)) {
                                // Show error snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Invalid prompt. Please use only alphanumeric characters and spaces.'),
                                  ),
                                );
                                return;
                              }

                              if (prompt.isNotEmpty && prompt.length > 2) {
                                context.read<ARCubit>().generate(prompt);
                                _textController.clear();
                                _focusNode.unfocus();
                              }
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                          ),
                        ),
                      ),
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

class _TextInput extends StatelessWidget {
  const _TextInput({
    required TextEditingController textController,
    required FocusNode focusNode,
    required this.isLoading,
  })  : _textController = textController,
        _focusNode = focusNode;

  final TextEditingController _textController;
  final FocusNode _focusNode;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        enabled: !isLoading,
        decoration: InputDecoration(
          hintText: 'Enter your prompt (e.g., "wooden chair")',
          hintStyle: TextStyle(
            color: Colors.grey.shade600,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        maxLines: 2,
        maxLength: 20,
      ),
    );
  }
}

class ModePicker extends StatelessWidget {
  const ModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    /// Builds a mode option widget
    Widget buildModeOption(
        {required GenerationMode mode, required bool isSelected}) {
      return GestureDetector(
        onTap: () {
          context.read<ARCubit>().updateMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.deepPurple.shade600
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.deepPurple.shade400
                  : Colors.white.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    mode.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                mode.description,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BlocBuilder<ARCubit, ARState>(
      buildWhen: (previous, current) {
        return previous.generationMode != current.generationMode;
      },
      builder: (context, state) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: buildModeOption(
                  mode: GenerationMode.basic,
                  isSelected: state.generationMode == GenerationMode.basic,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildModeOption(
                  mode: GenerationMode.advanced,
                  isSelected: state.generationMode == GenerationMode.advanced,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
