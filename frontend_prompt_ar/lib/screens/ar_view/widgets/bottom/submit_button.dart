import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/screens/ar_view/widgets/show_snackbar.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.isLoading,
    required this.textController,
    required this.focusNode,
  });

  final bool isLoading;
  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isLoading
              ? Colors.grey.shade600
              : Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: InkWell(
          onTap: () {
            final prompt = textController.text.trim();
            // should only contain alphanumeric and spaces
            final validCharacters = RegExp(r'^[a-zA-Z0-9 ]+$');
            if (!validCharacters.hasMatch(prompt)) {
              showSnackbar(
                context,
                'Invalid characters in prompt. Please use only letters, numbers, and spaces.',
              );
              return;
            }

            if (prompt.length <= 2) {
              showSnackbar(
                context,
                "Don't be shy! Please enter a more detailed prompt.",
              );
              return;
            }
            context.read<ARCubit>().generate(prompt);
            textController.clear();
            focusNode.unfocus();
          },
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      key: ValueKey('icon'),
                      Icons.send,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
