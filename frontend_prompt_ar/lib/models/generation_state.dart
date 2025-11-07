/// State for model generation and AR display
enum GenerationState {
  initial,
  idle,
  generating, // Backend is generating the model
  downloading, // Downloading the model file
  arReady, // AR view is ready and showing the model
  error;

  // get is loading state
  bool get isLoading =>
      this == GenerationState.generating || this == GenerationState.downloading;
}
