import 'package:flutter/material.dart';
import '../../../../bloc/ar_bloc/ar_cubit.dart';
import '../../../../models/model_response.dart';

/// Model card widget for displaying models in the list
class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.index,
    required this.locationType,
    required this.onApply,
    this.onDelete,
    this.formattedTimestamp,
  });

  final ModelResponse model;
  final int index;
  final ModelLocationType locationType;
  final VoidCallback onApply;
  final VoidCallback? onDelete;
  final String? formattedTimestamp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onApply,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              const SizedBox(width: 4),
              // Model info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locationType == ModelLocationType.asset
                          ? (model.localFilePath ?? model.modelId)
                              .split('/')
                              .last
                              .split('.')
                              .first
                          : model.prompt,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Show timestamp for downloaded models
                    if (locationType == ModelLocationType.documentsFolder &&
                        formattedTimestamp != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          formattedTimestamp!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
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

/// Dialog for loading previously generated models
class LoadModelDialog extends StatefulWidget {
  const LoadModelDialog({
    super.key,
    required this.assetModels,
    required this.downloadedModels,
    required this.bloc,
    required this.onModelApply,
  });

  final List<String> assetModels;
  final List<ModelResponse> downloadedModels;
  final ARCubit bloc;
  final Function(ModelResponse) onModelApply;

  @override
  State<LoadModelDialog> createState() => _LoadModelDialogState();
}

class _LoadModelDialogState extends State<LoadModelDialog>
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

  void _showDeleteConfirmation(BuildContext context, ModelResponse model) {
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
              widget.bloc.deleteModel(model.modelId);
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
        maxHeight: MediaQuery.of(context).size.height * 0.6,
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
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
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
              Tab(text: 'Example Models'),
            ],
          ),
          const SizedBox(height: 16),
          // Tab bar view
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Downloaded tab
                _buildDownloadedModelList(
                  models: widget.downloadedModels,
                ),
                // Demo tab
                _buildAssetModelList(
                  models: widget.assetModels,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetModelList({
    required List<String> models,
  }) {
    if (models.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No demo models available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: models.length,
      itemBuilder: (context, index) {
        final assetPath = models[index];
        // Create a ModelResponse for asset models
        final model = ModelResponse(
          modelId: assetPath.split('/').last.split('.').first,
          downloadUrl: '',
          prompt: assetPath.split('/').last.split('.').first,
          status: 'completed',
          message: 'Asset model',
          localFilePath: assetPath,
          locationType: ModelLocationType.asset,
        );

        return _ModelCard(
          model: model,
          index: index,
          locationType: ModelLocationType.asset,
          onApply: () => widget.onModelApply(model),
          onDelete: null, // Asset models can't be deleted
        );
      },
    );
  }

  Widget _buildDownloadedModelList({
    required List<ModelResponse> models,
  }) {
    if (models.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No downloaded models found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        final formattedTimestamp =
            model.timestamp != null ? _formatTimestamp(model.timestamp!) : null;

        return _ModelCard(
          model: model,
          index: index,
          locationType: ModelLocationType.documentsFolder,
          onApply: () => widget.onModelApply(model),
          onDelete: () => _showDeleteConfirmation(context, model),
          formattedTimestamp: formattedTimestamp,
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}
