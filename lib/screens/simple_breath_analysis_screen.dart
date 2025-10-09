import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/unified_analysis_service.dart';

class SimpleBreathAnalysisScreen extends StatefulWidget {
  const SimpleBreathAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<SimpleBreathAnalysisScreen> createState() => _SimpleBreathAnalysisScreenState();
}

class _SimpleBreathAnalysisScreenState extends State<SimpleBreathAnalysisScreen> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _currentFilePath;
  Map<String, dynamic>? _lastResult;
  String _statusMessage = 'Ready to record your breathing';

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _requestPermissions();
    await _recorder!.openRecorder();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<String> _getRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/breath_recording_$timestamp.wav';
  }

  Future<void> _startRecording() async {
    if (_recorder == null) return;
    
    try {
      _currentFilePath = await _getRecordingPath();
      await _recorder!.startRecorder(
        toFile: _currentFilePath,
        codec: Codec.pcm16WAV,
      );
      
      setState(() {
        _isRecording = true;
        _statusMessage = 'Recording... Breathe naturally for 3-5 seconds';
        _lastResult = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_recorder == null || !_isRecording) return;
    
    try {
      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
        _statusMessage = 'Analyzing your breathing pattern...';
      });
      
      if (_currentFilePath != null) {
        await _analyzeRecording();
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusMessage = 'Error stopping recording: $e';
      });
    }
  }

  Future<void> _analyzeRecording() async {
    if (_currentFilePath == null) return;
    
    try {
      final file = File(_currentFilePath!);
      if (!await file.exists()) {
        throw Exception('Recording file not found');
      }
      
      // Analyze the audio file
      final result = await UnifiedAnalysisService.analyzeFile(file);
      
      setState(() {
        _lastResult = result;
        _isAnalyzing = false;
        _statusMessage = _getResultMessage(result);
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _statusMessage = 'Analysis failed: $e';
      });
    }
  }

  String _getResultMessage(Map<String, dynamic> result) {
    final label = result['label']?.toString() ?? 'unknown';
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePercent = (confidence * 100).toStringAsFixed(1);
    
    switch (label.toLowerCase()) {
      case 'clear':
      case 'normal':
        return '✅ Healthy breathing detected ($confidencePercent% confidence)';
      case 'crackles':
        return '⚠️ Possible crackles detected ($confidencePercent% confidence)';
      case 'wheezing':
        return '⚠️ Possible wheezing detected ($confidencePercent% confidence)';
      case 'abnormal':
        return '🔴 Abnormal breathing pattern detected ($confidencePercent% confidence)';
      default:
        return 'Analysis complete: $label ($confidencePercent% confidence)';
    }
  }

  Color _getResultColor() {
    if (_lastResult == null) return Colors.grey;
    
    final label = _lastResult!['label']?.toString().toLowerCase() ?? '';
    switch (label) {
      case 'clear':
      case 'normal':
        return Colors.green;
      case 'crackles':
      case 'wheezing':
        return Colors.orange;
      case 'abnormal':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breath Analysis'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getResultColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getResultColor().withOpacity(0.3)),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _getResultColor(),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Recording Button
            GestureDetector(
              onTap: _isAnalyzing ? null : (_isRecording ? _stopRecording : _startRecording),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.blue,
                  boxShadow: [
                    if (_isRecording)
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: _isAnalyzing
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 60,
                        color: Colors.white,
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              _isAnalyzing
                  ? 'Analyzing...'
                  : _isRecording
                      ? 'Tap to stop recording'
                      : 'Tap to start recording',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Results Section
            if (_lastResult != null) ...[
              const Text(
                'Last Analysis Results:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildResultsCard(),
            ],
            
            // Instructions
            if (_lastResult == null) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Hold phone close to your chest\n'
                      '2. Breathe naturally for 3-5 seconds\n'
                      '3. AI will analyze for respiratory conditions',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final predictions = _lastResult!['predictions'] as Map<String, dynamic>? ?? {};
    final label = _lastResult!['label']?.toString() ?? 'unknown';
    final confidence = ((_lastResult!['confidence'] as num?)?.toDouble() ?? 0.0) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primary Result: $label',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getResultColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${confidence.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16),
          ),
          
          if (predictions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Detailed Predictions:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...predictions.entries.map((entry) {
              final value = ((entry.value as num?)?.toDouble() ?? 0.0) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${value.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    super.dispose();
  }
}
