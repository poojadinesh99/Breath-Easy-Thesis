class DemoAnalysisService {
  static Future<Map<String, dynamic>> analyzeDemo() async {
    // Simulate a delay for demo analysis
    await Future.delayed(const Duration(seconds: 2));

    // Return a dummy analysis result
    return {
      'predictions': {
        'Normal': 0.85,
        'Anomaly': 0.15,
      },
      'label': 'Normal',
      'confidence': 0.85,
      'source': 'Demo Data',
    };
  }
}
