import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/screens/ar_view/widgets/show_snackbar.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.textController,
    required this.focusNode,
  });

  final TextEditingController textController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: InkWell(
          onTap: () {
            final prompt = textController.text.trim();
            // dissmi keyboard
            focusNode.unfocus();

            if (prompt.length <= 2) {
              showSnackbar(
                context,
                "Don't be shy! Please enter a more detailed prompt.",
              );
              return;
            }
            // should only contain alphanumeric and spaces
            final validCharacters = RegExp(r'^[a-zA-Z0-9 ]+$');
            if (!validCharacters.hasMatch(prompt)) {
              showSnackbar(
                context,
                'Invalid characters in prompt. Please use only letters, numbers, and spaces.',
              );
              return;
            }
            textController.clear();
            context.read<ARCubit>().generate(prompt);
          },
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: const AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              child: Icon(
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
