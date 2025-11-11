import 'package:flutter/material.dart';
import 'package:prompt_ar/models/generation_mode.dart';
import '../../../models/generation_state.dart';

/// Simple and elegant loading overlay widget for AR view
class ARLoadingOverlay extends StatefulWidget {
  final GenerationState state;
  final GenerationMode mode;
  final String prompt;

  const ARLoadingOverlay({
    super.key,
    required this.state,
    required this.mode,
    required this.prompt,
  });

  @override
  State<ARLoadingOverlay> createState() => _ARLoadingOverlayState();
}

class _ARLoadingOverlayState extends State<ARLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Gentle pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _message {
    final waitingSeconds = widget.mode == GenerationMode.advanced ? 30 : 20;
    switch (widget.state) {
      case GenerationState.generating:
        return 'Generating 3D model for "${widget.prompt}"\nThis may take about $waitingSeconds seconds.';
      case GenerationState.downloading:
        return 'Downloading model...';
      default:
        return 'Please wait...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple pulsing icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(
                      alpha: 0.1 + (_pulseAnimation.value * 0.15),
                    ),
                    border: Border.all(
                      color: primaryColor.withValues(
                        alpha: 0.3 + (_pulseAnimation.value * 0.4),
                      ),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.view_in_ar,
                    size: 50,
                    color: primaryColor.withValues(
                      alpha: 0.8 + (_pulseAnimation.value * 0.2),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 48),

            // Simple progress indicator
            SizedBox(
              width: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Clean text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
