/// Model response from the AI 3D generation API
class ModelResponse {
  final String modelId;
  final String modelUrl;
  final String prompt;
  final DateTime createdAt;
  final String status;

  ModelResponse({
    required this.modelId,
    required this.modelUrl,
    required this.prompt,
    required this.createdAt,
    required this.status,
  });

  factory ModelResponse.fromJson(Map<String, dynamic> json) {
    return ModelResponse(
      modelId: json['model_id'] as String,
      modelUrl: json['model_url'] as String,
      prompt: json['prompt'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_id': modelId,
      'model_url': modelUrl,
      'prompt': prompt,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}

