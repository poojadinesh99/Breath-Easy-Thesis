import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

class ApiService {
  static String get baseUrl => BackendConfig.baseUrl;

  /// Analyzes an audio file by sending it to the backend API
  static Future<Map<String, dynamic>> analyzeAudioFile(File audioFile) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict/unified'));
      
      // Add audio file to the request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'breathing_sample.wav',
        ),
      );

      // Send the request
      var response = await request.send();

      // Check if the request was successful
      if (response.statusCode == 200) {
        // Parse the response
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> result = json.decode(responseData);
        
        return {
          'predictions': result['predictions'] ?? {},
          'label': result['label'] ?? 'Unknown',
          'confidence': result['confidence'] ?? 0.0,
          'source': result['source'] ?? 'API',
          'processing_time': result['processing_time'] ?? 0.0,
          'text_summary': result['text_summary'] ?? '',
        };
      } else {
        throw Exception('Failed to analyze audio: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error analyzing audio: $e');
    }
  }

  /// Alternative method for testing or direct data analysis
  static Future<Map<String, dynamic>> analyzeAudioData(List<double> audioData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict/unified'),
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

  /// Health check for the API
  static Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get API status information
  static Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'offline', 'message': 'API not responding'};
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection failed: $e'};
    }
  }
}
