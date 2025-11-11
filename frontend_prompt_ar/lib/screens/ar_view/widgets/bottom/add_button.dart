import 'package:flutter/material.dart';

/// Plus button for creating new models with animated glowing border
class AddButton extends StatefulWidget {
  const AddButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Custom curve for fast edge transitions - creates magical snap effect
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve:
            Curves.easeInOutCubic, // Faster acceleration/deceleration at edges
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
                    // Animated glowing border - faster edge transitions
                    border: Border.all(
                      color: primaryColor.withValues(
                        alpha: 0.85 + (_glowAnimation.value * 0.15),
                      ),
                      width: 2.5 + (_glowAnimation.value * 3.0),
                    ),
                    boxShadow: [
                      // Primary outer glow - most intense with dramatic edge transitions
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.75 + (_glowAnimation.value * 0.25),
                        ),
                        blurRadius: 30 + (_glowAnimation.value * 40),
                        spreadRadius: 4 + (_glowAnimation.value * 10),
                        offset: const Offset(0, 8),
                      ),
                      // Secondary outer glow - wider spread with faster edges
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.5 + (_glowAnimation.value * 0.4),
                        ),
                        blurRadius: 45 + (_glowAnimation.value * 35),
                        spreadRadius: 2 + (_glowAnimation.value * 8),
                        offset: const Offset(0, 8),
                      ),
                      // Inner glow - bright and close with snap effect
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.65 + (_glowAnimation.value * 0.35),
                        ),
                        blurRadius: 15 + (_glowAnimation.value * 20),
                        spreadRadius: -1,
                        offset: const Offset(0, 4),
                      ),
                      // Magical white sparkle - elegant highlight with fast edges
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: 0.5 + (_glowAnimation.value * 0.5),
                        ),
                        blurRadius: 8 + (_glowAnimation.value * 16),
                        spreadRadius: 1 + (_glowAnimation.value * 5),
                        offset: const Offset(0, 0),
                      ),
                      // Additional purple/primary glow layer - magical pulse
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.4 + (_glowAnimation.value * 0.4),
                        ),
                        blurRadius: 25 + (_glowAnimation.value * 30),
                        spreadRadius: 3 + (_glowAnimation.value * 9),
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
