/// Model response from the AI 3D generation API
class ModelResponse {
  final String modelId;
  final String downloadUrl;  // URL to download the model
  final String prompt;
  final String status;
  final String message;
  final String? localFilePath;  // Local file path after download

  ModelResponse({
    required this.modelId,
    required this.downloadUrl,
    required this.prompt,
    required this.status,
    required this.message,
    this.localFilePath,
  });

  factory ModelResponse.fromJson(Map<String, dynamic> json) {
    return ModelResponse(
      modelId: json['model_id'] as String,
      downloadUrl: json['download_url'] as String,
      prompt: json['prompt'] as String? ?? '',
      status: json['status'] as String,
      message: json['message'] as String? ?? 'Model generated successfully',
    );
  }

  ModelResponse copyWith({
    String? localFilePath,
  }) {
    return ModelResponse(
      modelId: modelId,
      downloadUrl: downloadUrl,
      prompt: prompt,
      status: status,
      message: message,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_id': modelId,
      'download_url': downloadUrl,
      'prompt': prompt,
      'status': status,
      'message': message,
    };
  }
}

