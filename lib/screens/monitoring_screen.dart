import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../services/unified_analysis_service.dart';
import '../services/history_service.dart';
import '../services/backend_config.dart';
import 'package:http/http.dart' as http;

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String _currentStatus = 'Stopped';
  String _breathStatus = 'No data available yet';
  String _speechStatus = 'No data available yet';
  String _breathLabel = 'Unknown';
  String _speechLabel = 'Unknown';
  double _breathConfidence = 0.0;
  double _speechConfidence = 0.0;
  Timer? _analysisTimer;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _analysisTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    try {
      // Request microphone permission
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
      
      // Open recorder
      await _recorder.openRecorder();
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
      _currentStatus = 'Monitoring active';
      _breathStatus = 'Starting monitoring...';
      _speechStatus = 'Starting monitoring...';
    });

    // Start periodic recording and analysis every 10 seconds
    _analysisTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
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

    try {
      // Stop any ongoing recording
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      
      // Cancel the periodic timer
      _analysisTimer?.cancel();

      setState(() {
        _isRecording = false;
        _currentStatus = 'Stopped';
        _breathStatus = 'Monitoring stopped';
        _speechStatus = 'Monitoring stopped';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitoring stopped')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop monitoring: $e')),
      );
    }
  }

  Future<void> _recordAndAnalyzeChunk() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _isAnalyzing = true;
        _breathStatus = 'Recording 10-second sample...';
        _speechStatus = 'Recording 10-second sample...';
      });

      // Ensure recorder is ready and permissions are granted
      if (!_recorder.isRecording) {
        // Double-check permissions
        var status = await Permission.microphone.status;
        if (!status.isGranted) {
          setState(() {
            _breathStatus = 'Microphone permission denied';
            _speechStatus = 'Microphone permission denied';
          });
          return;
        }

        // Create a new temporary file for this chunk
        Directory tempDir = await getTemporaryDirectory();
        String chunkPath = '${tempDir.path}/monitoring_chunk_${DateTime.now().millisecondsSinceEpoch}.wav';

        print('Starting recording to: $chunkPath');

        // Initialize recorder session with more explicit settings
        await _recorder.openRecorder();
        
        // Start recording with explicit configuration for Android
        await _recorder.startRecorder(
          toFile: chunkPath,
          codec: Codec.pcm16WAV,
          sampleRate: 16000,
          bitRate: 128000,
          numChannels: 1,
        );

        // Wait for 10 seconds while recording, with status updates
        for (int i = 1; i <= 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!_isRecording) break; // Exit if monitoring was stopped
          setState(() {
            _breathStatus = 'Recording... ${i}/10 seconds';
            _speechStatus = 'Recording... ${i}/10 seconds';
          });
        }

        // Stop recording
        String? recordedPath = await _recorder.stopRecorder();
        await _recorder.closeRecorder();
        print('Recording stopped. File: $recordedPath');

        // Verify the file was created and has content
        final file = File(chunkPath);
        if (file.existsSync()) {
          final fileSize = await file.length();
          print('Audio file created: $chunkPath, size: $fileSize bytes');
          
          if (fileSize > 1000) { // Ensure file has actual audio data (more than just headers)
            setState(() {
              _breathStatus = 'Analyzing breath patterns...';
              _speechStatus = 'Analyzing speech...';
            });

            try {
              // Breath analysis
              final breathResult = await UnifiedAnalysisService.analyzeFile(file);
              
              setState(() {
                _breathLabel = breathResult['label'] ?? 'Unknown';
                _breathConfidence = (breathResult['confidence'] as double?) ?? 0.0;
                _breathStatus = 'Breath: ${_breathLabel} (${(_breathConfidence * 100).toStringAsFixed(1)}%)';
              });

              // Save to history
              await HistoryService.addEntry({
                'label': _breathLabel,
                'confidence': _breathConfidence,
                'source': 'Live Monitoring - Breath',
                'timestamp': DateTime.now(),
                'predictions': breathResult,
              });
            } catch (e) {
              setState(() {
                _breathStatus = 'Breath analysis failed: $e';
              });
              print('Breath analysis error: $e');
            }

            try {
              // Speech analysis
              final speechResult = await _analyzeSpeech(file);
              
              setState(() {
                _speechLabel = speechResult['label'] ?? 'Unknown';
                _speechConfidence = (speechResult['confidence'] as double?) ?? 0.0;
                _speechStatus = speechResult['message'] ?? 'Speech analysis complete.';
              });

              await HistoryService.addEntry({
                'label': _speechLabel,
                'confidence': _speechConfidence,
                'source': 'Live Monitoring - Speech',
                'timestamp': DateTime.now(),
                'predictions': speechResult,
              });
            } catch (e) {
              setState(() {
                _speechStatus = 'Speech analysis failed: $e';
              });
              print('Speech analysis error: $e');
            }
          } else {
            setState(() {
              _breathStatus = 'Recording too short (${fileSize} bytes)';
              _speechStatus = 'Recording too short (${fileSize} bytes)';
            });
            print('Audio file too small: $fileSize bytes');
          }

          // Clean up the temporary file
          try {
            await file.delete();
          } catch (e) {
            print('Could not delete temp file: $e');
          }
        } else {
          setState(() {
            _breathStatus = 'Recording failed - file not found';
            _speechStatus = 'Recording failed - file not found';
          });
          print('Audio file not created: $chunkPath');
        }
      } else {
        setState(() {
          _breathStatus = 'Recorder busy';
          _speechStatus = 'Recorder busy';
        });
        print('Recorder is already recording');
      }
    } catch (e) {
      setState(() {
        _breathStatus = 'Recording failed: $e';
        _speechStatus = 'Recording failed: $e';
      });
      print('Recording error: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<Map<String, dynamic>> _analyzeSpeech(File file) async {
    // Use HTTP multipart to call /predict/speech
    try {
      final uri = Uri.parse('${BackendConfig.base}/predict/speech');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return {
          'label': result['label'] ?? 'Speech',
          'confidence': (result['confidence'] as num?)?.toDouble() ?? 0.0,
          'message': result['message'] ?? 'Speech analysis complete.',
          'transcript': result['transcript'] ?? '',
        };
      } else {
        return {
          'label': 'Error',
          'confidence': 0.0,
          'message': 'Speech analysis failed (code ${response.statusCode})',
          'transcript': '',
        };
      }
    } catch (e) {
      return {
        'label': 'Error',
        'confidence': 0.0,
        'message': 'Speech analysis error: $e',
        'transcript': '',
      };
    }
  }

  Widget _buildConfidenceBadge(String label, double confidence) {
    // Don't show confidence for unknown/empty labels
    if (label.isEmpty || label == 'Unknown' || confidence <= 0.0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: confidence > 0.7 ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confidence > 0.7 ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Text(
        '${(confidence * 100).toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: confidence > 0.7 ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitoring'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Monitoring',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $_currentStatus',
              style: TextStyle(
                fontSize: 16,
                color: _isRecording ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Real-time breath and speech analysis with continuous monitoring.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Breath Analysis Card
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.bubble_chart,
                  color: _breathLabel.toLowerCase() == 'clear' ? Colors.green : Colors.orange,
                ),
                title: const Text('Breath Analysis'),
                subtitle: Text(_breathStatus),
                trailing: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _buildConfidenceBadge(_breathLabel, _breathConfidence),
              ),
            ),

            const SizedBox(height: 12),

            // Speech Analysis Card
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.record_voice_over,
                  color: _speechLabel.toLowerCase() == 'normal' ? Colors.green : Colors.orange,
                ),
                title: const Text('Speech Analysis'),
                subtitle: Text(_speechStatus),
                trailing: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _buildConfidenceBadge(_speechLabel, _speechConfidence),
              ),
            ),

            const SizedBox(height: 24),

            // Control Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRecording ? _stopMonitoring : _startMonitoring,
                icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                label: Text(_isRecording ? 'Stop Monitoring' : 'Start Monitoring'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Text
            if (_isRecording)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '🎤 Monitoring is active. The system is continuously analyzing your breathing and speech patterns. Analysis updates every 10 seconds for better accuracy.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
