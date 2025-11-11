import 'package:flutter/material.dart';

/// Cancel button positioned outside the container
class CancelButton extends StatelessWidget {
  const CancelButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back,
          color: Colors.white.withValues(alpha: 0.8),
          size: 32,
        ),
      ),
    );
  }
}

/// Plus button for creating new models with animated glowing border
class PlusButton extends StatefulWidget {
  const PlusButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<PlusButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    // Animated glowing border
                    border: Border.all(
                      color: primaryColor.withValues(
                        alpha: 0.9 + (_glowAnimation.value * 0.1),
                      ),
                      width: 3 + (_glowAnimation.value * 2.5),
                    ),
                    boxShadow: [
                      // Primary outer glow - most intense
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.8 + (_glowAnimation.value * 0.2),
                        ),
                        blurRadius: 35 + (_glowAnimation.value * 30),
                        spreadRadius: 5 + (_glowAnimation.value * 8),
                        offset: const Offset(0, 8),
                      ),
                      // Secondary outer glow - wider spread
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.6 + (_glowAnimation.value * 0.3),
                        ),
                        blurRadius: 50 + (_glowAnimation.value * 25),
                        spreadRadius: 3 + (_glowAnimation.value * 6),
                        offset: const Offset(0, 8),
                      ),
                      // Inner glow - bright and close
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.7 + (_glowAnimation.value * 0.3),
                        ),
                        blurRadius: 18 + (_glowAnimation.value * 15),
                        spreadRadius: -1,
                        offset: const Offset(0, 4),
                      ),
                      // Magical white sparkle - elegant highlight
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: 0.6 + (_glowAnimation.value * 0.4),
                        ),
                        blurRadius: 10 + (_glowAnimation.value * 12),
                        spreadRadius: 2 + (_glowAnimation.value * 4),
                        offset: const Offset(0, 0),
                      ),
                      // Additional purple/primary glow layer
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.5 + (_glowAnimation.value * 0.3),
                        ),
                        blurRadius: 30 + (_glowAnimation.value * 20),
                        spreadRadius: 4 + (_glowAnimation.value * 7),
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 22,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
