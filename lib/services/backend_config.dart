import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendConfig {
  // Hugging Face Space runtime URL (not the repo page URL)
  static const String cloudUrl = 'https://poojadinesh99-breath-easy-thesis.hf.space';

  // Toggle to force local vs cloud; set to false to use cloud
  static const bool useLocal = false;

  static String _localUrl() {
    const computerIP = '192.168.178.42';
    return 'http://$computerIP:8000';
  }

  // Base URL used by the app
  static String get baseUrl => useLocal ? _localUrl() : cloudUrl;

  /// Returns the base URL for the API. Keep simple and fast.
  static Future<String> getValidatedBaseUrl() async => baseUrl;

  // Optional connectivity probe (kept for future use)
  static Future<bool> _canConnect(String url) async {
    try {
      final uri = Uri.parse('$url/');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed for $url: $e');
      return false;
    }
  }

  // API endpoints built from the selected base URL
  static Future<String> get healthCheck async => '${await getValidatedBaseUrl()}/';
  static Future<String> get unifiedAnalysis async => '${await getValidatedBaseUrl()}/predict';
  // The following are not exposed on the Space; keep placeholders for future
  static Future<String> get symptomsLog async => '${await getValidatedBaseUrl()}/symptoms/log';
  static Future<String> get history async => '${await getValidatedBaseUrl()}/history';
}
