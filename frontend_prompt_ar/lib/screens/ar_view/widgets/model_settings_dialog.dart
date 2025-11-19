import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../../bloc/ar_bloc/ar_cubit.dart';

/// Dialog for adjusting model scale and rotation
class ModelSettingsDialog extends StatefulWidget {
  final ARNode tappedNode;

  const ModelSettingsDialog({
    super.key,
    required this.tappedNode,
  });

  @override
  State<ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends State<ModelSettingsDialog> {
  late double _scaleMultiplier;
  late vector.Vector3 _initialScale;

  @override
  void initState() {
    super.initState();
    final scale = widget.tappedNode.scale;

    // Store the initial scale (use average for uniform scaling)
    final avgScale = (scale.x + scale.y + scale.z) / 3.0;
    _initialScale = vector.Vector3(avgScale, avgScale, avgScale);

    // Start with 1.0x multiplier (original size)
    _scaleMultiplier = 1.0;
  }

  void _onScaleChanged(double multiplier) {
    setState(() {
      _scaleMultiplier = multiplier;
    });
  }

  void _onScaleChangeEnd(double multiplier) {
    // Calculate the new scale based on initial scale and multiplier
    final newScale = vector.Vector3(
      _initialScale.x * multiplier,
      _initialScale.y * multiplier,
      _initialScale.z * multiplier,
    );

    // Update scale only when slider drag ends
    final cubit = context.read<ARCubit>();
    cubit.updateNodeScale(
      widget.tappedNode.name,
      newScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Model Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scale section
                      const Text(
                        'Scale',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Single overall scale slider (multiplier relative to initial scale)
                      _buildSlider(
                        label: 'Size',
                        value: _scaleMultiplier,
                        min: 0.1,
                        max: 3.0,
                        onChanged: _onScaleChanged,
                        onChangeEnd: _onScaleChangeEnd,
                        displayValue: '${_scaleMultiplier.toStringAsFixed(2)}x',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remove button
                  ElevatedButton(
                    onPressed: () async {
                      final cubit = context.read<ARCubit>();
                      await cubit.removeNode(widget.tappedNode.name);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Remove'),
                  ),
                  // Close button
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    String? displayValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                displayValue ?? value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withAlpha(50),
              valueIndicatorColor: Colors.black87,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
              divisions: 100,
            ),
          ),
        ],
      ),
    );
  }
}
