import 'package:flutter/material.dart';

/// Floating card with animated icon for mode selector
class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(170),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Animated icon container with enhanced animations
            AnimatedBuilder(
              animation: _iconAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, -2 * _bounceAnimation.value),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha(190),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: _glowAnimation.value * 0.5,
                            ),
                            width: 1.5 + (_glowAnimation.value * 0.5),
                          ),
                          boxShadow: [
                            // Glowing shadow around icon
                            BoxShadow(
                              color: primaryColor.withValues(
                                alpha: _glowAnimation.value * 0.6,
                              ),
                              blurRadius: 12 + (_glowAnimation.value * 10),
                              spreadRadius: 1 + (_glowAnimation.value * 2),
                              offset: const Offset(0, 2),
                            ),
                            // White sparkle
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: _glowAnimation.value * 0.4,
                              ),
                              blurRadius: 6 + (_glowAnimation.value * 6),
                              spreadRadius: 0.5,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode selector menu with floating cards (no background)
class ModeSelectorMenu extends StatelessWidget {
  const ModeSelectorMenu({
    super.key,
    required this.onCreateFromPrompt,
    required this.onLoadRecentModels,
    required this.onDismiss,
  });

  final VoidCallback onCreateFromPrompt;
  final VoidCallback onLoadRecentModels;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ModeCard(
              icon: Icons.text_fields_rounded,
              title: 'Create 3D from Text Prompt',
              subtitle: 'Generate a new 3D model',
              onTap: onCreateFromPrompt,
            ),
            _ModeCard(
              icon: Icons.history_rounded,
              title: 'Load Recently Generated',
              subtitle: 'Browse your saved models',
              onTap: onLoadRecentModels,
            ),
          ],
        ),
      ),
    );
  }
}
