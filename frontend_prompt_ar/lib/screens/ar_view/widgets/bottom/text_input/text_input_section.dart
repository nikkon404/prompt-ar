import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../bloc/ar_bloc/ar_cubit.dart';
import '../../show_snackbar.dart';
import 'mode_picker.dart';

/// Text input field widget
class _TextInputField extends StatefulWidget {
  const _TextInputField({
    required this.textController,
    required this.focusNode,
  });

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  State<_TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<_TextInputField> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.06,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          autofocus: true,
          controller: widget.textController,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            widget.focusNode.unfocus();
          },
          decoration: InputDecoration(
            hintText: 'Enter your prompt...',
            hintStyle: TextStyle(
              color: Colors.grey.shade600,
            ),
            counterText: '',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
          maxLines: 1,
          maxLength: 22,
        ),
      ),
    );
  }
}

/// Generate button with magic icon and text
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.textController,
    required this.focusNode,
  });

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final prompt = textController.text.trim();

          if (prompt.length <= 2) {
            showSnackbar(
              context,
              "Don't be shy! Please enter a more detailed prompt.",
            );
            return;
          }
          final validCharacters = RegExp(r'^[a-zA-Z0-9 ]+$');
          if (!validCharacters.hasMatch(prompt)) {
            showSnackbar(
              context,
              'Invalid characters in prompt. Please use only letters, numbers, and spaces.',
            );
            return;
          }
          textController.clear();
          focusNode.unfocus();
          context.read<ARCubit>().generate(prompt);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'Generate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main content panel with mode picker, text input, and generate button
class TextInputSection extends StatelessWidget {
  const TextInputSection({
    super.key,
    required this.textController,
    required this.focusNode,
  });

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 5.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode picker
          const ModePicker(),

          const SizedBox(height: 12),

          // Text input and buttons row
          Row(
            children: [
              // Text input field
              Expanded(
                child: _TextInputField(
                  textController: textController,
                  focusNode: focusNode,
                ),
              ),
              const SizedBox(width: 12),

              // Generate button
              _GenerateButton(
                textController: textController,
                focusNode: focusNode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
