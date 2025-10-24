import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppConfig {
  static const bool useLocalBackend = true;  // Use local backend
  
  // Backend URLs - simplified to always use local backend
  static String get backendUrl {
    if (useLocalBackend) {
      // For local development
      if (Platform.isAndroid) {
        // Android device needs actual machine IP
        return 'http://192.168.178.42:8000';  // Your local machine IP
      }
      // iOS simulator and other platforms
      return 'http://localhost:8000';
    }
    
    // Cloud backend (currently not available)
    return 'https://your-app-name.onrender.com';  // Replace when you redeploy
  }
  
  // Alternative: Use cloud ML APIs
  static const String huggingFaceApiUrl = 'https://api-inference.huggingface.co/models/';
  static const String openAIApiUrl = 'https://api.openai.com/v1/audio/transcriptions';
  
  // Audio settings
  static const int sampleRate = 16000;  // 16kHz
  static const int numChannels = 1;     // mono
  static const Duration maxRecordDuration = Duration(seconds: 30);
  static const Duration minRecordDuration = Duration(milliseconds: 500);
  
  // Error messages
  static const String networkError = 'Network error. Please check your connection and try again.';
  static const String recordingTooShort = 'Recording too short. Please record for at least 0.5 seconds.';
  static const String invalidAudioFormat = 'Invalid audio format. Please try again.';
  static const String genericError = 'Something went wrong. Please try again.';
  
  // Debug settings
  static bool get isDebugMode => kDebugMode;
  static void debugLog(String message) {
    if (isDebugMode) {
      print('[BreathEasy] $message');
    }
  }
}
