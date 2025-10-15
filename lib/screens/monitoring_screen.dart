import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/unified_analysis_service.dart';
import '../services/history_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String _breathStatus = 'No data available yet';
  String _speechStatus = 'No data available yet';
  String _breathLabel = 'Unknown';
  String _speechLabel = 'Unknown';
  double _breathConfidence = 0.0;
  Timer? _analysisTimer;
  String? _lastRecordingPath;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _stopMonitoring();
    _recorder.closeRecorder();
    _analysisTimer?.cancel();
    _cleanupTempFiles();
    super.dispose();
  }

  Future<void> _cleanupTempFiles() async {
    if (_lastRecordingPath != null) {
      try {
        final file = File(_lastRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error cleaning up temp file: $e');
      }
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      
      print('Recorder initialized successfully');
    } catch (e) {
      print('Failed to initialize recorder: $e');
      rethrow;
    }
  }

  Future<void> _startMonitoring() async {
    if (_isRecording) return;

    setState(() {
      _isRecording = true;
      _breathStatus = 'Starting monitoring...';
      _speechStatus = 'Starting monitoring...';
    });

    // Start periodic recording and analysis
    _analysisTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _recordAndAnalyzeChunk();
    });

    // Do first recording immediately
    await _recordAndAnalyzeChunk();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monitoring started')),
    );
  }

  Future<void> _stopMonitoring() async {
    if (!_isRecording) return;

    _analysisTimer?.cancel();
    
    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      setState(() {
        _isRecording = false;
        _breathStatus = 'Monitoring stopped';
        _speechStatus = 'Monitoring stopped';
      });

      await _cleanupTempFiles();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitoring stopped')),
      );
    } catch (e) {
      print('Error stopping monitoring: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop monitoring: $e')),
      );
    }
  }

  Future<void> _recordAndAnalyzeChunk() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _breathStatus = 'Recording audio sample...';
        _speechStatus = 'Recording audio sample...';
      });

      // Cleanup previous recording if exists
      await _cleanupTempFiles();

      // Create new recording file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final chunkPath = '${tempDir.path}/monitoring_$timestamp.wav';
      _lastRecordingPath = chunkPath;

      // Start recording with high-quality settings
      await _recorder.startRecorder(
        toFile: chunkPath,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
        bitRate: 256000,
        numChannels: 1,
      );

      // Record for 12 seconds
      for (int i = 1; i <= 12; i++) {
        if (!_isRecording) break;
        setState(() {
          _breathStatus = 'Recording... $i/12 seconds';
          _speechStatus = 'Recording... $i/12 seconds';
        });
        await Future.delayed(const Duration(seconds: 1));
      }

      // Stop recording and verify file
      final recordedPath = await _recorder.stopRecorder();
      
      if (recordedPath == null) {
        throw Exception('Recording failed - no file created');
      }

      final file = File(recordedPath);
      if (!await file.exists()) {
        throw Exception('Recording file not found');
      }

      final fileSize = await file.length();
      print('Recording completed: $recordedPath ($fileSize bytes)');

      if (fileSize < 1000) {
        throw Exception('Recording too short or empty');
      }

      // Analyze the recording
      setState(() {
        _breathStatus = 'Analyzing audio...';
        _speechStatus = 'Processing...';
      });

      final result = await UnifiedAnalysisService.analyzeFile(file);
      
      setState(() {
        _breathLabel = result['label'] ?? 'Unknown';
        _breathConfidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        _breathStatus = '$_breathLabel (${(_breathConfidence * 100).toStringAsFixed(1)}%)';
        
        _speechLabel = result['text_summary'] ?? 'No speech detected';
        _speechStatus = _speechLabel;
      });

      // Save to history
      await HistoryService.addEntry({
        'label': _breathLabel,
        'confidence': _breathConfidence,
        'text_summary': _speechLabel,
        'source': 'Live Monitoring',
        'timestamp': DateTime.now().toIso8601String(),
        'predictions': result['predictions'],
      });

    } catch (e) {
      print('Error during recording/analysis: $e');
      setState(() {
        _breathStatus = 'Error: $e';
        _speechStatus = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitoring'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopMonitoring();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Status: ${_isRecording ? "Monitoring active" : "Stopped"}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time breath and speech analysis with continuous monitoring.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Breath Analysis Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.air,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Breath Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_breathStatus),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Speech Analysis Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Speech Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_speechStatus),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Monitoring is active. The system is continuously analyzing your breathing and speech patterns. Analysis updates every 12 seconds for better accuracy.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Control Button
            ElevatedButton(
              onPressed: _isRecording ? _stopMonitoring : _startMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isRecording ? 'Stop Monitoring' : 'Start Monitoring',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
