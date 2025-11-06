import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_state.dart';
import '../../../bloc/ar_bloc/ar_bloc.dart';
import '../../../bloc/ar_bloc/ar_event.dart';

/// Instruction text widget displayed when model is ready for placement
class ARInstructionText extends StatelessWidget {
  const ARInstructionText({super.key});

  Future<void> _showResetDialog(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Clear Model'),
        content: const Text(
          'Are you sure you want to clear the current model? This will reset the AR view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldReset == true && context.mounted) {
      context.read<ARBloc>().add(const ARReset());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ARBloc, ARState>(
      builder: (context, state) {
        return Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Instruction text
                const Expanded(
                  child: Text(
                    'Tap on a plane to place the model',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Reset button
                IconButton(
                  onPressed: () => _showResetDialog(context),
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: 'Clear model',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
