import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/prediction_response.dart';
import 'backend_config.dart';

class UnifiedService {
  static const Duration requestTimeout = Duration(seconds: 45); // Increased timeout for audio processing

  Future<PredictionResponse> analyzeAudio({
    required String filePath,
    required String taskType,
  }) async {
    if (kDebugMode) {
      print('UnifiedService: Starting audio analysis for task: $taskType');
      print('UnifiedService: File path: $filePath');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          print('UnifiedService: Recording file not found at: $filePath');
        }
        return PredictionResponse.error('Recording file not found');
      }

      final fileSize = await file.length();
      if (kDebugMode) {
        print('UnifiedService: File size: ${fileSize} bytes');
      }

      final endpointUrl = await BackendConfig.unifiedAnalysis;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(endpointUrl),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );
      request.fields['task_type'] = taskType;

      if (kDebugMode) {
        print('UnifiedService: Sending request to: $endpointUrl');
      }

      final streamedResponse = await request.send().timeout(
        requestTimeout,
        onTimeout: () => throw TimeoutException(
          'Analysis request timed out after ${requestTimeout.inSeconds} seconds', 
          requestTimeout
        ),
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print('UnifiedService: Response status: ${response.statusCode}');
        print('UnifiedService: Response length: ${response.body.length} characters');
      }

      if (response.statusCode != 200) {
        String errorMessage = 'Analysis failed. Please try again.';
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? errorMessage;
        } catch (e) {
          if (kDebugMode) {
            print('UnifiedService: Failed to parse error response: $e');
          }
        }
        
        if (kDebugMode) {
          print('UnifiedService: Error response: $errorMessage');
        }
        
        return PredictionResponse.error(errorMessage);
      }

      final responseData = json.decode(response.body);
      if (kDebugMode) {
        print('UnifiedService: Raw response body: ${response.body}');
        print('UnifiedService: Parsed response data: $responseData');
      }
      
      // Handle wrapped response format {status: "success", data: {...}}
      Map<String, dynamic> actualData = responseData;
      if (responseData.containsKey('status') && responseData.containsKey('data')) {
        actualData = responseData['data'] as Map<String, dynamic>;
        if (kDebugMode) {
          print('UnifiedService: Unwrapped data: $actualData');
        }
      }
      
      if (kDebugMode) {
        print('UnifiedService: Successfully received prediction response');
      }
      
      return PredictionResponse.fromJson(actualData);
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('UnifiedService: Timeout error: $e');
      }
      return PredictionResponse.error('Request timed out. Please check your connection and try again.');
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('UnifiedService: Network error: $e');
      }
      return PredictionResponse.error('Network error. Please check your connection.');
    } catch (e) {
      if (kDebugMode) {
        print('UnifiedService: Unexpected error: $e');
      }
      return PredictionResponse.error('Failed to analyze audio: $e');
    }
  }

  /// Test connection to the backend
  Future<bool> testConnection() async {
    try {
      final healthUrl = await BackendConfig.healthCheck;
      final response = await http.get(
        Uri.parse(healthUrl),
      ).timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        print('UnifiedService: Health check status: ${response.statusCode}');
      }
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('UnifiedService: Health check failed: $e');
      }
      return false;
    }
  }
}
