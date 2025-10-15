import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpeechRecordingPanel extends StatefulWidget {
  const SpeechRecordingPanel({super.key});

  @override
  State<SpeechRecordingPanel> createState() => _SpeechRecordingPanelState();
}

class _SpeechRecordingPanelState extends State<SpeechRecordingPanel> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _riskScore;
  StreamSubscription? _recorderSubscription;
  final List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
    setState(() {
      _isRecorderInitialized = true;
    });
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '\${directory.path}/speech_\$timestamp.wav';
  }

  void _startRecording() async {
    if (!_isRecorderInitialized) return;
    final path = await _getFilePath();
    _waveformData.clear();
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );
    _recorderSubscription = _recorder.onProgress?.listen((event) {
      if (event.decibels != null) {
        setState(() {
          _waveformData.add(event.decibels!.clamp(-60.0, 0.0) + 60.0);
          if (_waveformData.length > 100) {
            _waveformData.removeAt(0);
          }
        });
      }
    });
    setState(() {
      _isRecording = true;
      _riskScore = null;
    });

    // Automatically stop after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_isRecording) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() async {
    if (!_isRecorderInitialized) return;
    final path = await _recorder.stopRecorder();
    _recorderSubscription?.cancel();
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });

    if (path != null) {
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) throw Exception('User not logged in');

        final file = File(path);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = 'recordings/\${user.id}/cough/\$timestamp.wav';

        final response = await supabase.storage.from('recordings').upload(filePath, file);

        if (response != null && response.isNotEmpty) {
          final publicUrl = supabase.storage.from('recordings').getPublicUrl(filePath);

          // Call CoughAnalysisService.analyze(fileUrl)
          final riskScore = await CoughAnalysisService.analyze(publicUrl);

          setState(() {
            _riskScore = riskScore.toString();
            _isUploading = false;
          });
        } else {
          throw Exception('Failed to upload file to Supabase Storage');
        }
      } catch (e) {
        setState(() {
          _isUploading = false;
          _riskScore = 'Error: \$e';
        });
      }
    } else {
      setState(() {
        _isUploading = false;
        _riskScore = 'No recording file found';
      });
    }
  }

  Widget _buildWaveform() {
    if (_waveformData.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: Text('Waveform will appear here')));
    }
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _WaveformPainter(_waveformData),
        size: Size(double.infinity, 100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWaveform(),
        const SizedBox(height: 16),
        if (_isUploading) const CircularProgressIndicator(),
        if (!_isRecording && !_isUploading)
          ElevatedButton.icon(
            icon: const Icon(Icons.mic),
            label: const Text('Start Recording'),
            onPressed: _startRecording,
          ),
        if (_isRecording)
          ElevatedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Stop Recording'),
            onPressed: _stopRecording,
          ),
        const SizedBox(height: 16),
        if (_riskScore != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Cough Risk Score: \$_riskScore'),
            ),
          ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  _WaveformPainter(this.waveformData);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;
    final widthPerSample = size.width / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * widthPerSample;
      final y = waveformData[i] / 60 * size.height;
      canvas.drawLine(Offset(x, midY - y / 2), Offset(x, midY + y / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData;
  }
}

// Dummy CoughAnalysisService for demonstration
class CoughAnalysisService {
  static Future<double> analyze(String fileUrl) async {
    // Simulate network call delay
    await Future.delayed(const Duration(seconds: 2));
    // Return a dummy risk score
    return 0.42;
  }
}
