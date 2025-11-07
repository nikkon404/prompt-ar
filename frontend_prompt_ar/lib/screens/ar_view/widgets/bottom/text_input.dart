import 'package:flutter/material.dart';

class TextInput extends StatefulWidget {
  const TextInput({
    super.key,
    required this.textController,
    required this.focusNode,
  });

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.06,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: widget.textController,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            // Dismiss keyboard when "Done" is pressed
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
