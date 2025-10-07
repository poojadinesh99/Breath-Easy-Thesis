import 'package:dio/dio.dart' as dio;
import 'dart:io';
import 'backend_config.dart';
import 'history_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnifiedAnalysisService {
  static dio.Dio _dio = dio.Dio();

  static void setDio(dio.Dio dioClient) => _dio = dioClient;

  // Legacy URL based (kept for backward compatibility)
  static Future<Map<String, dynamic>> analyzeUnified(String fileUrl) async {
    final String backendUrl = '${BackendConfig.base}/predict/unified';
    try {
      final response = await _dio.post(
        backendUrl,
        data: {'file_url': fileUrl},
        options: dio.Options(headers: {'Content-Type': 'application/json'}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error during unified analysis: $e');
    }
  }

  // New: multipart upload from local file (emulator/device path)
  static Future<Map<String, dynamic>> analyzeFile(File file) async {
    final String backendUrl = '${BackendConfig.base}/predict/unified';
    try {
      final form = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(file.path, filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.wav'),
      });
      final response = await _dio.post(backendUrl, data: form);
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error during multipart unified analysis: $e');
    }
  }

  static Map<String, dynamic> _handleResponse(dio.Response response) {
    if (response.statusCode == 200 && response.data != null) {
      final result = {
        'predictions': Map<String, double>.from(response.data['predictions'] ?? {}),
        'label': response.data['label'] ?? '',
        'confidence': (response.data['confidence'] as num?)?.toDouble() ?? 0.0,
        'source': response.data['source'] ?? 'unknown',
        'text_summary': response.data['text_summary'] ?? 'No summary available',
        'timestamp': DateTime.now().toIso8601String(),
        'raw_response': response.data,
      };
      HistoryService.addEntry(result);
      _persistToSupabase(result);
      return result;
    } else {
      throw Exception('Failed to get valid response from backend');
    }
  }

  static Future<void> _persistToSupabase(Map<String, dynamic> result) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return; // skip if not logged in
      
      // Ensure all required fields are present
      final analysisData = {
        'user_id': user.id,
        'analysis_type': result['source'] ?? 'monitoring',
        'label': result['label'] ?? 'Unknown',
        'confidence': (result['confidence'] ?? 0.0).toDouble(),
        'source': result['source'] ?? 'monitoring',
        'predictions': result['predictions'] ?? {},
        'raw_response': result['raw_response'] ?? {},
        'transcript': result['transcript'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await supabase.from('analysis_history').insert(analysisData);
      print('Analysis saved to Supabase: ${analysisData['label']} (${analysisData['confidence']})');
    } catch (e) {
      print('Failed to save to Supabase: $e');
      // Silently ignore persistence errors for now
    }
  }
}
