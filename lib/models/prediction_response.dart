class PredictionResponse {
  final Map<String, double> predictions;
  final String label;
  final double confidence;
  final String source;
  final double processingTime;
  final String textSummary;
  final String? transcription;  // Add transcription field
  final List<String>? possibleConditions;  // Add possible conditions field
  final String? error;

  PredictionResponse({
    Map<String, double>? predictions,
    String? label,
    double? confidence,
    String? source,
    double? processingTime,
    String? textSummary,
    this.transcription,  // Add transcription parameter
    this.possibleConditions,  // Add possible conditions parameter
    this.error,
  })  : predictions = predictions ?? {"clear": 1.0},
        label = label ?? "",
        confidence = confidence ?? 0.0,
        source = source ?? "",
        processingTime = processingTime ?? 0.0,
        textSummary = textSummary ?? "";

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    // Convert predictions to Map<String, double>
    final rawPredictions = json['predictions'] as Map<String, dynamic>?;
    final Map<String, double> predictions = {};
    if (rawPredictions != null) {
      rawPredictions.forEach((key, value) {
        if (value is num) {
          predictions[key] = value.toDouble();
        }
      });
    }

    return PredictionResponse(
      predictions: predictions,
      label: json['label'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      source: json['source'] as String?,
      processingTime: (json['processing_time'] as num?)?.toDouble(),
      textSummary: json['text_summary'] as String?,
      transcription: json['transcription'] as String?,  // Add transcription parsing
      possibleConditions: (json['possible_conditions'] as List<dynamic>?)?.cast<String>(),  // Add possible conditions parsing
      error: json['error'] as String?,
    );
  }

  // Factory for error responses
  factory PredictionResponse.error(String message) {
    return PredictionResponse(
      predictions: {"error": 0.0},
      label: "Error",
      confidence: 0.0,
      source: "error",
      processingTime: 0.0,
      textSummary: message,
      error: message,
    );
  }

  // Check if this is an error response
  bool get hasError => error != null;

  // Convert to JSON for debugging
  Map<String, dynamic> toJson() {
    return {
      'predictions': predictions,
      'label': label,
      'confidence': confidence,
      'source': source,
      'processing_time': processingTime,
      'text_summary': textSummary,
      'possible_conditions': possibleConditions,
      'error': error,
    };
  }
}
