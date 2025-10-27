import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

class ApiService {
  static String get baseUrl => BackendConfig.baseUrl;

  /// Check if the API is healthy
  static Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/health'),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('API request timed out'),
      );

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (e) {
      debugPrint('API health check error: $e');
      return false;
    }
  }

  /// Get detailed API status
  static Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/health'),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'API not responding'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Analyzes an audio file by sending it to the backend API
  static Future<Map<String, dynamic>> analyzeAudioFile(File audioFile) async {
    try {
      final uri = Uri.parse('$baseUrl/predict');
      final req = http.MultipartRequest('POST', uri);
      req.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path, filename: 'audio_sample.wav'),
      );
      final resp = await req.send().timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        final body = await resp.stream.bytesToString();
        return _normalize(json.decode(body));
      }
      throw Exception('Analysis failed: ${resp.statusCode}');
    } catch (e) {
      throw Exception('Analysis failed: $e');
    }
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> r) => {
        'predictions': r['predictions'] ?? r['probs'] ?? {},
        'predicted_label': r['predicted_label'] ?? r['label'] ?? 'Unknown',
        'confidence': r['confidence'] ?? r['score'] ?? 0.0,
        'source': r['source'] ?? 'API',
        'processing_time': r['processing_time'] ?? r['latency_ms'] ?? 0.0,
        'text_summary': r['text_summary'] ?? r['summary'] ?? '',
        'audio_metadata': r['audio_metadata'] ?? {},
      };

  /// Alternative method for testing or direct data analysis
  static Future<Map<String, dynamic>> analyzeAudioData(List<double> audioData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'audio_data': audioData}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze audio data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error analyzing audio data: $e');
    }
  }
}
