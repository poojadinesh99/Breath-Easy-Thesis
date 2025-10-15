import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class MedicalAnalysisScreen extends StatefulWidget {
  const MedicalAnalysisScreen({super.key});

  @override
  State<MedicalAnalysisScreen> createState() => _MedicalAnalysisScreenState();
}

class _MedicalAnalysisScreenState extends State<MedicalAnalysisScreen> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _recordingPath;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<bool> _requestPermissions() async {
    final status = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();
    return status.isGranted && storageStatus.isGranted;
  }

  Future<void> _startRecording() async {
    if (!await _requestPermissions()) {
      setState(() {
        _errorMessage = 'Microphone permission required';
      });
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/breathing_$timestamp.wav';

      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _analysisResult = null;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path != null) {
        await _analyzeRecording(path);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop recording: $e';
      });
    }
  }

  Future<void> _analyzeRecording(String path) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.analyzeAudioFile(File(path));
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: $e';
        _isAnalyzing = false;
      });
    }
  }

  Widget _buildRecordingButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAnalysisResults() {
    if (_analysisResult == null) return const SizedBox.shrink();

    final predictions = _analysisResult!['predictions'] as Map<String, dynamic>? ?? {};
    final label = _analysisResult!['label'] as String? ?? 'Unknown';
    final confidence = _analysisResult!['confidence'] as double? ?? 0.0;
    final source = _analysisResult!['source'] as String? ?? 'Unknown';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            _buildResultRow('Primary Diagnosis', label),
            _buildResultRow('Confidence', '${(confidence * 100).toStringAsFixed(1)}%'),
            _buildResultRow('Source', source),
            const SizedBox(height: 16),
            const Text(
              'Detailed Predictions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...predictions.entries.map((entry) => _buildPredictionRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildPredictionRow(String label, double probability) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Class $label'),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: probability,
              backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
                probability > 0.5 ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(probability * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respiratory Analysis'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'Record your breathing',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRecording ? 'Recording... Tap to stop' : 'Tap to start recording',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildRecordingButton(),
            const SizedBox(height: 20),
            if (_isAnalyzing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing audio...'),
                ],
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            _buildAnalysisResults(),
          ],
        ),
      ),
    );
  }
}
