import 'package:dio/dio.dart' show Dio, DioException, DioExceptionType, FormData, MultipartFile, Options, BaseOptions;
import 'dart:io';
import 'backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

class UnifiedAnalysisService {
  static final Dio _dio = Dio()
    ..options = BaseOptions(
      baseUrl: BackendConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status! < 500,
    );

  /// Analyzes an audio file using the unified backend endpoint
  static Future<Map<String, dynamic>> analyzeFile(File file) async {
    try {
      // Validate file size (minimum 1 second of audio)
      final fileSize = await file.length();
      if (fileSize < 88200) { // 44100 samples/sec * 2 bytes/sample = 88200 bytes/sec
        throw Exception('Recording too short - please record at least 1 second');
      }

      // Create form data with the file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.wav'
        ),
      });

      // Send request to backend
      final response = await _dio.post(
        BackendConfig.unifiedAnalysis,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status! < 500,
        ),
      );

      // Handle response
      if (response.statusCode == 200 && response.data != null) {
        final predictions = Map<String, double>.from(response.data['predictions'] ?? {});
        final label = response.data['label'] ?? '';
        final confidence = (response.data['confidence'] as num?)?.toDouble() ?? 0.0;
        final textSummary = response.data['text_summary'] ?? 'No summary available';

        // Store in Supabase if available
        try {
          final supabase = Supabase.instance.client;
          await supabase.from('analysis_history').insert({
            'label': label,
            'confidence': confidence,
            'predictions': predictions,
            'text_summary': textSummary,
            'timestamp': DateTime.now().toIso8601String(),
            'user_id': supabase.auth.currentUser?.id,
          });
        } catch (e) {
          print('Warning: Failed to store analysis in Supabase: $e');
          // Continue even if Supabase storage fails
        }

        return {
          'predictions': predictions,
          'label': label,
          'confidence': confidence,
          'text_summary': textSummary,
        };
      } else {
        throw Exception(
          'Backend error: ${response.statusCode} - ${response.statusMessage}\n'
          '${response.data?['detail'] ?? 'No additional details'}'
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Connection timeout. Please check your internet connection.');
      }
      if (e.response?.statusCode == 413) {
        throw Exception('Audio file too large. Please record a shorter sample.');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Analysis failed: $e');
    }
  }
}
