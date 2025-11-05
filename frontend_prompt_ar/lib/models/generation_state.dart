/// State for model generation and AR display
enum GenerationState {
  idle,
  processing,    // Backend is generating the model
  downloading,   // Downloading the model file
  applying,      // Applying model to AR view
  arReady,       // AR view is ready and showing the model
  error,
}

