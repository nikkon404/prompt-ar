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
