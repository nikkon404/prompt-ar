import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_cubit.dart';
import 'package:prompt_ar/bloc/ar_bloc/ar_state.dart';
import 'package:prompt_ar/models/model_response.dart';
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
              if (state.downloadedModels == null || state.assetModels == null) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              return _LoadModelDialog(
                assetModels: state.assetModels ?? [],
                downloadedModels: state.downloadedModels ?? [],
                bloc: cubit,
                onModelApply: (modelId, type) {
                  cubit.loadExistingModel(modelId, type);
                  showSnackbar(
                    context,
                    'Applied model in AR, Tap on screen to place it.',
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

/// Bottom sheet widget to show list of downloaded models with tabs
class _LoadModelDialog extends StatefulWidget {
  final List<String> assetModels;
  final List<String> downloadedModels;
  final ARCubit bloc;
  final Function(String, ModelLocationType) onModelApply;

  const _LoadModelDialog({
    required this.assetModels,
    required this.downloadedModels,
    required this.bloc,
    required this.onModelApply,
  });

  @override
  State<_LoadModelDialog> createState() => _LoadModelDialogState();
}

class _LoadModelDialogState extends State<_LoadModelDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
              widget.bloc.deleteModel(modelId);
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
          // Title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Models',
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
          const SizedBox(height: 8),
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Downloaded'),
              Tab(text: 'Demo Models'),
            ],
          ),
          const SizedBox(height: 16),
          // Tab bar view
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Downloaded tab
                _buildModelList(
                  models: widget.downloadedModels,
                  type: ModelLocationType.documentsFolder,
                ),
                // Demo tab
                _buildModelList(
                  models: widget.assetModels,
                  type: ModelLocationType.asset,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList({
    required List<String> models,
    required ModelLocationType type,
  }) {
    final isDemo = type == ModelLocationType.asset;
    if (models.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            isDemo ? 'No demo models available' : 'No downloaded models found',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 3,
        crossAxisSpacing: 11,
        childAspectRatio: 2.5,
      ),
      shrinkWrap: true,
      itemCount: models.length,
      itemBuilder: (context, index) {
        final modelId = models[index];

        return ModelCard(
          modelId: modelId,
          index: index,
          locationType: type,
          onApply: () => widget.onModelApply(modelId, type),
          onDelete:
              isDemo ? null : () => _showDeleteConfirmation(context, modelId),
        );
      },
    );
  }
}

/// Elegant model card widget with apply and delete actions
class ModelCard extends StatelessWidget {
  final String modelId;
  final int index;
  final ModelLocationType locationType;
  final Function onApply;
  final VoidCallback? onDelete;

  const ModelCard({
    super.key,
    required this.modelId,
    required this.index,
    required this.locationType,
    required this.onApply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onApply();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locationType == ModelLocationType.asset
                          ? modelId.split('/').last.split('.').first
                          : 'Model #${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons - only show delete for downloaded models
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
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
