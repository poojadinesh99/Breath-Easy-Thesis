import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'backend_config.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

class RespireUnifiedService {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30)));
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  Future<void> init() async {
    await _recorder.openRecorder();
  }

  Future<void> dispose() async {
    await _recorder.closeRecorder();
  }

  Future<Map<String, dynamic>> recordAndAnalyze({int seconds = 8, String taskType = 'general'}) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/unified_input.wav';
    await _recorder.startRecorder(toFile: path, codec: Codec.pcm16WAV, numChannels: 1, sampleRate: 16000);
    await Future.delayed(Duration(seconds: seconds));
    await _recorder.stopRecorder();

    final base = BackendConfig.baseUrl;
    final endpoints = ['$base/predict'];
    DioException? last;
    try {
      for (final url in endpoints) {
        try {
          final form = FormData.fromMap({
            'file': await MultipartFile.fromFile(path, filename: 'input.wav', contentType: MediaType('audio', 'wav')),
            'task_type': taskType,
          });
          final resp = await _dio.post(url, data: form);
          return Map<String, dynamic>.from(resp.data as Map);
        } on DioException catch (e) {
          last = e;
          continue;
        }
      }
      return {'error': 'Unified analysis failed', 'details': last?.message};
    } finally {
      try { await File(path).delete(); } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> analyzeFile(File file, {String taskType = 'general'}) async {
    final base = BackendConfig.baseUrl;
    final endpoints = ['$base/predict'];
    DioException? last;
    for (final url in endpoints) {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path, filename: 'input.wav', contentType: MediaType('audio', 'wav')),
          'task_type': taskType,
        });
        final resp = await _dio.post(url, data: form);
        return Map<String, dynamic>.from(resp.data as Map);
      } on DioException catch (e) {
        last = e;
        continue;
      }
    }
    return {'error': 'Unified analysis failed', 'details': last?.message};
  }
}
