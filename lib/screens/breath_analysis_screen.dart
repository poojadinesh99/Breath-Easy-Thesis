import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/unified_analysis_service.dart';
import '../widgets/prediction_result_widget.dart';
import 'app_theme.dart';

// Breath-specific categories
enum BreathCategory {
  breathingShallow('Shallow Breathing'),
  breathingDeep('Deep Breathing'),
  breathingFast('Fast Breathing'),
  breathingSlow('Slow Breathing'),
  coughingHeavy('Heavy Coughing'),
  coughingLight('Light Coughing'),
  wheezing('Wheezing'),
  stridor('Stridor');

  const BreathCategory(this.displayName);
  final String displayName;
}

class BreathAnalysisScreen extends StatefulWidget {
  const BreathAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<BreathAnalysisScreen> createState() => _BreathAnalysisScreenState();
}

class _BreathAnalysisScreenState extends State<BreathAnalysisScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String? _recordedFilePath;
  String _statusText = 'Press the button to start recording';

  Map<String, double> _predictions = {};
  String _topLabel = '';
  double _topConfidence = 0.0;
  String _textSummary = '';
  bool _isAnalyzing = false;
  bool _hasRecordingError = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      await _recorder.openRecorder();
      
      // Configure recorder for high-quality audio
      await _recorder.setAudioInfo(
        AudioInfo(
          inputDeviceId: '',
          outputDeviceId: '',
          focusMode: FocusMode.FOCUS_MODE_AUTO,
          iosSampleRate: 44100,
          iosQuality: IosQuality.HIGH,
          androidAudioSource: AndroidAudioSource.MIC,
          androidAudioFocusGainType: AndroidAudioFocusGainType.GAIN_TRANSIENT_EXCLUSIVE,
        ),
      );
      
      _isRecorderInitialized = true;
      setState(() {});
    } catch (e) {
      setState(() {
        _statusText = 'Error initializing recorder: $e';
        _hasRecordingError = true;
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) {
      setState(() {
        _statusText = 'Recorder not initialized';
        _hasRecordingError = true;
      });
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordedFilePath = '${dir.path}/breath_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _recorder.startRecorder(
        toFile: _recordedFilePath,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
        bitRate: 16 * 44100, // 16-bit
        numChannels: 1, // mono
      );

      setState(() {
        _isRecording = true;
        _statusText = 'Recording... (breathe normally)';
        _hasRecordingError = false;
      });

      // Stop recording after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      if (_isRecording) {
        await _stopRecording();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error during recording: $e';
        _hasRecordingError = true;
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _statusText = 'Recording stopped, analyzing...';
      });
      await _analyzeRecording();
    } catch (e) {
      setState(() {
        _statusText = 'Error stopping recording: $e';
        _hasRecordingError = true;
        _isRecording = false;
      });
    }
  }

  Future<void> _analyzeRecording() async {
    if (_recordedFilePath == null) {
      setState(() {
        _statusText = 'No recording to analyze';
        _hasRecordingError = true;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _hasRecordingError = false;
    });

    try {
      final file = File(_recordedFilePath!);
      if (!await file.exists() || await file.length() < 88200) { // Min 1 second
        throw Exception('Recording too short or invalid');
      }

      final result = await UnifiedAnalysisService.analyzeFile(file);
      
      setState(() {
        _predictions = result['predictions'];
        _topLabel = result['label'];
        _topConfidence = result['confidence'];
        _textSummary = result['text_summary'];
        _statusText = 'Analysis complete';
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'Analysis failed: $e';
        _hasRecordingError = true;
        _isAnalyzing = false;
      });
    } finally {
      // Clean up the recording file
      try {
        if (_recordedFilePath != null) {
          final file = File(_recordedFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        print('Error cleaning up recording file: $e');
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  void _onRecordButtonPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _onRetry() {
    if (_recordedFilePath != null) {
      setState(() {
        _isAnalyzing = true;
        _statusText = 'Retrying analysis...';
      });
      UnifiedAnalysisService.analyzeFile(File(_recordedFilePath!)).then((analysisResult) {
        setState(() {
          _predictions = Map<String, double>.from(analysisResult['predictions'] ?? {});
          _topLabel = analysisResult['label'] ?? '';
          _topConfidence = (analysisResult['confidence'] as double?) ?? 0.0;
          _isAnalyzing = false;
          _statusText = 'Analysis complete';
        });
      }).catchError((e) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Error during analysis: \$e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze recording: \$e')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breath Analysis'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructions Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recording Instructions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Find a quiet place\n'
                          '2. Hold your phone 6 inches from your mouth\n'
                          '3. Press and hold the microphone button\n'
                          '4. Breathe normally or cough as needed\n'
                          '5. Release to stop recording',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Text
                Text(
                  _statusText,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Record Button
                Center(
                  child: GestureDetector(
                    onTapDown: (_) => _startRecording(),
                    onTapUp: (_) => _stopRecording(),
                    onTapCancel: () => _stopRecording(),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Analysis Results
                if (_isAnalyzing)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
                else if (_topLabel.isNotEmpty)
                  PredictionResultWidget(
                    result: {
                      'predictions': _predictions,
                      'label': _topLabel,
                      'confidence': _topConfidence,
                      'source': _textSummary,
                    },
                    onRetry: _onRetry,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getBreathInstructions() {
    switch (_topLabel) {
      case 'breathingShallow':
        return 'Take shallow, quick breaths for 10-15 seconds for accurate analysis.';
      case 'breathingDeep':
        return 'Take deep breaths: inhale slowly for 4 seconds, hold for 4 seconds, exhale for 4 seconds. Repeat 3-4 times for best results (minimum 10 seconds total).';
      case 'breathingFast':
        return 'Take fast, rapid breaths for 10-15 seconds for accurate analysis.';
      case 'breathingSlow':
        return 'Take slow, deliberate breaths for 15-20 seconds.';
      case 'coughingHeavy':
        return 'Perform heavy coughing 3-5 times over 10 seconds.';
      case 'coughingLight':
        return 'Perform light coughing 3-5 times over 10 seconds.';
      case 'wheezing':
        return 'Make wheezing sounds while breathing for 10-15 seconds.';
      case 'stridor':
        return 'Make stridor sounds while breathing for 10-15 seconds.';
      default:
        return '';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRecordings() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    try {
      final data = await supabase
          .from('recordings')
          .select()
          .eq('user_id', user.id)
          .ilike('category', 'breath_%')
          .order('recorded_at', ascending: false);

      return data;
    } on Exception catch (e) {
      throw Exception(e.toString());
    }
  }
}
