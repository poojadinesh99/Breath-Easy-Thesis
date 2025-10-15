import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendConfig {
  static String? _cachedUrl;
  static DateTime? _lastCheck;
  
  /// Returns the base URL for the API, with connectivity validation
  static Future<String> getValidatedBaseUrl() async {
    // Check cache (valid for 30 seconds)
    if (_cachedUrl != null && _lastCheck != null) {
      final age = DateTime.now().difference(_lastCheck!);
      if (age < const Duration(seconds: 30)) {
        return _cachedUrl!;
      }
    }

    const computerIP = '192.168.178.42';  // Your computer's IP
    final url = baseUrl;

    try {
      // Test connection
      final canConnect = await _canConnect(url);
      if (canConnect) {
        _cachedUrl = url;
        _lastCheck = DateTime.now();
        return url;
      }
      throw Exception('Cannot connect to backend at $url');
    } catch (e) {
      debugPrint('Backend connection error: $e');
      rethrow;
    }
  }

  static Future<bool> _canConnect(String url) async {
    try {
      final uri = Uri.parse('$url/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  // Development backend URL
  static String get baseUrl {
    // For physical device testing, use your computer's IP address
    const computerIP = '192.168.178.42';  // Update this with your computer's IP
    
    if (Platform.isAndroid) {
      return 'http://$computerIP:8000';  // For physical Android device
    } else if (Platform.isIOS) {
      return 'http://$computerIP:8000';  // For physical iOS device
    } else {
      return 'http://localhost:8000';    // For desktop/web testing
    }
  }

  // API endpoints
  static String get healthCheck => '$baseUrl/health';
  static String get unifiedAnalysis => '$baseUrl/api/v1/unified';
  static String get symptomsLog => '$baseUrl/api/v1/symptoms/log';
  static String get history => '$baseUrl/api/v1/history';
}
