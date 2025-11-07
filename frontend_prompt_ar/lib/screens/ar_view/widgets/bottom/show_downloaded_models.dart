import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_cubit.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_state.dart';
import 'package:prompt_ar/screens/ar_view/widgets/show_snackbar.dart';

class ShowDownloadedModels extends StatelessWidget {
  const ShowDownloadedModels({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ARCubit>();

    /// Show bottom sheet with list of downloaded models
    void showLoadModelDialog() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.primary,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        builder: (context) => BlocProvider.value(
          value: cubit,
          child: BlocBuilder<ARCubit, ARState>(
            builder: (context, state) {
              if (state.downloadedModels == null) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final models = state.downloadedModels;

              if (models!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No Downloaded Models',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No downloaded models found.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

              return _LoadModelDialog(
                models: models,
                bloc: cubit,
                onModelApply: (modelId) {
                  cubit.loadExistingModel(modelId);
                  showSnackbar(
                    context,
                    'Applied model #${models.indexOf(modelId) + 1} in AR, Tap on screen to place it.',
                  );
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
        ),
        child: InkWell(
          onTap: () {
            // Fetch models via cubit
            context.read<ARCubit>().fetchDownloadedModels();
            showLoadModelDialog();
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: const Icon(
              Icons.folder,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet widget to show list of downloaded models
class _LoadModelDialog extends StatelessWidget {
  final List<String> models;
  final ARCubit bloc;
  final Function(String) onModelApply;

  const _LoadModelDialog({
    required this.models,
    required this.bloc,
    required this.onModelApply,
  });

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String modelId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete Model'),
        content: const Text('Are you sure you want to delete this model?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              bloc.deleteModel(modelId);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Previously Downloaded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          // text saying tap any model to apply
          const Text(
            'Tap a model to apply it in AR',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Model list
          Flexible(
            child: models.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No models found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 11,
                      childAspectRatio: 2.5,
                    ),
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final modelId = models[index];

                      return _ModelCard(
                        modelId: modelId,
                        index: index,
                        onApply: () => onModelApply(modelId),
                        onDelete: () =>
                            _showDeleteConfirmation(context, modelId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Elegant model card widget with apply and delete actions
class _ModelCard extends StatefulWidget {
  final String modelId;
  final int index;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  const _ModelCard({
    required this.modelId,
    required this.index,
    required this.onApply,
    required this.onDelete,
  });

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onApply();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Model icon
              Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.view_in_ar,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
              // Model info
              Expanded(
                child: Text(
                  'Model #${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons
              GestureDetector(
                onTap: () {
                  widget.onDelete();
                },
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
