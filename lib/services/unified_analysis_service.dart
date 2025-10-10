import 'package:dio/dio.dart' show Dio, FormData, MultipartFile, Options, Response, DioException, DioExceptionType;
import 'dart:io';
import 'backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

class UnifiedAnalysisService {
  static final Dio _dio = Dio();

  static void setDio(Dio dioClient) {
    _dio.options = dioClient.options;
  }

  /// Analyzes an audio file for respiratory patterns and speech
  static Future<Map<String, dynamic>> analyzeFile(File file) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path, 
          filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.wav'
        ),
      });

      final response = await _dio.post(
        BackendConfig.unifiedAnalysis,
        data: form,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status! < 500,
        ),
      );

      final result = _handleResponse(response);
      
      // Store in Supabase
      await _storeAnalysisResult(result);
      
      return result;
    } catch (e) {
      throw _handleError(e);
    }
  }

  static Map<String, dynamic> _handleResponse(Response response) {
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Server error: ${response.statusCode} - ${response.statusMessage}',
      );
    }

    if (response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty response from server',
      );
    }

    return {
      'predictions': Map<String, double>.from(response.data['predictions'] ?? {}),
      'label': response.data['label'] ?? '',
      'confidence': (response.data['confidence'] as num?)?.toDouble() ?? 0.0,
      'source': response.data['source'] ?? 'unknown',
      'text_summary': response.data['text_summary'] ?? 'No summary available',
      'timestamp': DateTime.now().toIso8601String(),
      'raw_response': response.data,
    };
  }

  static Future<void> _storeAnalysisResult(Map<String, dynamic> result) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('analysis_history').insert({
        'label': result['label'],
        'confidence': result['confidence'],
        'predictions': result['predictions'],
        'text_summary': result['text_summary'],
        'timestamp': result['timestamp'],
        'user_id': supabase.auth.currentUser?.id,
      });
    } catch (e) {
      print('Warning: Failed to store analysis result in Supabase: $e');
      // Don't throw - we still want to return the analysis result to the user
    }
  }

  static Exception _handleError(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return Exception('Connection timeout. Please check your internet connection.');
      }
      if (error.response?.statusCode == 413) {
        return Exception('Audio file too large. Please record a shorter sample.');
      }
      return Exception('Network error: ${error.message}');
    }
    return Exception('Unexpected error during analysis: $error');
  }
}
