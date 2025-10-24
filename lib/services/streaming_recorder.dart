import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

class StreamingRecorder {
  final String baseUrl; // e.g., http://<backend-ip>:10000
  final Dio _dio;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  Timer? _chunkTimer;
  String? _sessionId;
  String? _sessionDir;

  StreamingRecorder({required this.baseUrl}) : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30)));

  Future<void> init() async {
    await _recorder.openRecorder();
  }

  Future<void> dispose() async {
    await _recorder.closeRecorder();
  }

  Future<String> _startSessionOnServer({String? userId}) async {
    final form = FormData.fromMap({ if (userId != null) 'user_id': userId });
    final resp = await _dio.post('$baseUrl/api/v1/stream/start', data: form);
    return resp.data['session_id'] as String;
  }

  Future<void> start({String? userId}) async {
    _sessionId = await _startSessionOnServer(userId: userId);
    final dir = await getTemporaryDirectory();
    _sessionDir = '${dir.path}/be_session_${const Uuid().v4()}';
    await Directory(_sessionDir!).create(recursive: true);

    await _recorder.startRecorder(
      toFile: '$_sessionDir/current.wav',
      codec: Codec.pcm16WAV,
      numChannels: 1,
      sampleRate: 16000,
    );

    // Slice and upload every 1 second
    _chunkTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        await _flushChunk();
      } catch (_) {}
    });
  }

  Future<void> _flushChunk() async {
    if (_sessionDir == null || _sessionId == null) return;
    // Stop, copy, restart to create a chunk
    await _recorder.stopRecorder();
    final current = File('$_sessionDir/current.wav');
    if (await current.exists()) {
      final chunkPath = '$_sessionDir/chunk_${DateTime.now().millisecondsSinceEpoch}.wav';
      await current.copy(chunkPath);
      // upload chunk
      final form = FormData.fromMap({
        'session_id': _sessionId,
        'chunk': await MultipartFile.fromFile(chunkPath, filename: 'chunk.wav', contentType: MediaType('audio', 'wav')),
      });
      await _dio.post('$baseUrl/api/v1/stream/chunk', data: form);
      // cleanup chunk
      try { await File(chunkPath).delete(); } catch (_) {}
    }
    // restart recording for next slice
    await _recorder.startRecorder(
      toFile: '$_sessionDir/current.wav',
      codec: Codec.pcm16WAV,
      numChannels: 1,
      sampleRate: 16000,
    );
  }

  Future<Map<String, dynamic>> stopAndFinalize({String? userId}) async {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    try { await _flushChunk(); } catch (_) {}
    try { await _recorder.stopRecorder(); } catch (_) {}

    final form = FormData.fromMap({
      'session_id': _sessionId,
      if (userId != null) 'user_id': userId,
    });
    final resp = await _dio.post('$baseUrl/api/v1/stream/finalize', data: form);

    // cleanup local session dir
    if (_sessionDir != null) {
      try { await Directory(_sessionDir!).delete(recursive: true); } catch (_) {}
    }
    _sessionDir = null;
    _sessionId = null;
    return Map<String, dynamic>.from(resp.data as Map);
  }
}
