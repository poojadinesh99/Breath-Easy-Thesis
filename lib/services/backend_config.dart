import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendConfig {
  static String? _cachedUrl;
  static DateTime? _lastCheck;
  
  // Only use local backend for now
  static final String _localUrl = _getLocalUrl();

  /// Returns the base URL for the API, with connectivity validation
  static Future<String> getValidatedBaseUrl() async {
    // Always use local backend
    return _localUrl;
  }

  static String _getLocalUrl() {
    const computerIP = '192.168.178.42';  // Network IP for device testing
    return 'http://$computerIP:8000';  // Local backend only - now binding to 0.0.0.0
  }

  static Future<bool> _canConnect(String url) async {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse('$url/api/v1/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed for $url: $e');
      return false;
    }
  }

  // Development backend URL (fallback)
  static String get baseUrl {
    return _getLocalUrl();
  }

  // API endpoints - these will use the validated URL
  static Future<String> get healthCheck async => '${await getValidatedBaseUrl()}/api/v1/health';
  static Future<String> get unifiedAnalysis async => '${await getValidatedBaseUrl()}/api/v1/unified';
  static Future<String> get symptomsLog async => '${await getValidatedBaseUrl()}/api/v1/symptoms/log';
  static Future<String> get history async => '${await getValidatedBaseUrl()}/api/v1/history';
}
