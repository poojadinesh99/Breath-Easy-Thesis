import 'dart:io' show Platform;

// Production backend URL - used by default
const String _baseUrl = 'https://breath-easy-backend-fresh.onrender.com';

class BackendConfig {
  // Production backend URL
  static const String baseProd = 'https://breath-easy-backend-fresh.onrender.com';

  // Development backend URL (for testing)
  static String get baseDev =>
      Platform.isAndroid ? 'http://192.168.178.42:8000' : 'http://localhost:8000';

  // Use development for testing on device
  static String get baseUrl => baseDev;

  // API endpoints
  static String get healthCheck => '$baseUrl/health';
  static String get unifiedAnalysis => '$baseUrl/api/v1/unified';
  static String get transcription => '$baseUrl/api/v1/transcribe';
  // Add any additional endpoints here
}
