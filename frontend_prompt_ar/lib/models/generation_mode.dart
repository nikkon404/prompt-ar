/// Generation mode for 3D model creation
enum GenerationMode {
  basic, // Shap-E - Faster but lower quality
  advanced, // TRELLIS - Higher quality but slower
}

/// Extension to add helper methods to GenerationMode
extension GenerationModeExtension on GenerationMode {
  /// Get display name
  String get displayName {
    switch (this) {
      case GenerationMode.basic:
        return 'Basic';
      case GenerationMode.advanced:
        return 'Advanced';
    }
  }

  /// Get description
  String get description {
    switch (this) {
      case GenerationMode.basic:
        return 'Faster but lower quality';
      case GenerationMode.advanced:
        return 'Higher quality but slower';
    }
  }
}
