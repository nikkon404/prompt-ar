import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../../bloc/ar_bloc/ar_state.dart';
import '../../../../models/generation_mode.dart';

class ModePicker extends StatelessWidget {
  const ModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    /// Builds a mode option widget
    Widget buildModeOption({
      required GenerationMode mode,
      required bool isSelected,
    }) {
      return GestureDetector(
        onTap: () {
          context.read<ARCubit>().updateMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? const Padding(
                            key: ValueKey('check'),
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
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

