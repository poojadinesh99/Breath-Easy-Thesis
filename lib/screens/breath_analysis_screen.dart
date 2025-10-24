import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/unified_service.dart';
import '../services/history_service.dart';
import '../widgets/recording_wave.dart';
import '../widgets/analysis_result_card.dart';
import '../models/prediction_response.dart';
import 'dart:io';

// Audio recording configuration
const int sampleRate = 16000;
const int bitRate = 16 * 1024;  // 16 kbps
const int numChannels = 1;  // mono

enum RecordingState {
  initial,
  recording,
  recorded,
  analyzing,
  analyzed,
  error
}

class BreathAnalysisScreen extends StatefulWidget {
  const BreathAnalysisScreen({super.key});

  @override
  State<BreathAnalysisScreen> createState() => _BreathAnalysisScreenState();
}

class _BreathAnalysisScreenState extends State<BreathAnalysisScreen> 
    with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  final UnifiedService _unifiedService = UnifiedService();
  RecordingState _state = RecordingState.initial;
  String? _recordingPath;
  PredictionResponse? _result;
  late AnimationController _animationController;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isRecording = false;
  static const maxDuration = Duration(seconds: 30);
  static const minDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _checkPermissions();
  }

  String get formattedDuration {
    final remaining = maxDuration.inSeconds - _recordingDuration;
    return '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _cleanupTempFile();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (!await Permission.microphone.isGranted) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() => _state = RecordingState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;  // Prevent multiple starts
    
    try {
      // Check permissions again just to be sure
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          throw Exception('Microphone permission is required');
        }
      }

      // Reset state
      _recordingTimer?.cancel();
      _recordingDuration = 0;
      _result = null;
      await _cleanupTempFile();  // Clean up any existing recording
      
      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/breath_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      // Make sure recorder is stopped
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      
      // Configure and start recorder
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: sampleRate,
          numChannels: numChannels,
          bitRate: bitRate,
        ),
        path: _recordingPath!,
      );

      // Only set recording flag after successful start
      _isRecording = true;

      // Start timer
      _recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted) return;
          setState(() {
            _recordingDuration++;
            if (_recordingDuration >= maxDuration.inSeconds) {
              _stopRecording();
            }
          });
        },
      );

      setState(() => _state = RecordingState.recording);
      _animationController.repeat();
    } catch (e) {
      debugPrint('Recording error: $e');
      _isRecording = false;
      if (mounted) {
        setState(() => _state = RecordingState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;

    _recordingTimer?.cancel();
    _animationController.stop();

    try {
      await _audioRecorder.stop();

      if (_recordingDuration < minDuration.inSeconds) {
        _cleanupTempFile();
        setState(() => _state = RecordingState.initial);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording too short. Please record for at least 3 seconds.'),
          ),
        );
        return;
      }

      setState(() => _state = RecordingState.recorded);
      await _analyzeRecording();
    } catch (e) {
      debugPrint('Stop recording error: $e');
      setState(() => _state = RecordingState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
    }
  }

  Future<void> _analyzeRecording() async {
    if (_recordingPath == null) return;

    setState(() => _state = RecordingState.analyzing);

    try {
      final result = await _unifiedService.analyzeAudio(
        filePath: _recordingPath!,
        taskType: 'breath',  // Fixed: backend expects 'breath', not 'breath_deep'
      );

      print('BreathAnalysisScreen: Received result: ${result.toJson()}');
      print('BreathAnalysisScreen: Label: ${result.label}');
      print('BreathAnalysisScreen: Confidence: ${result.confidence}');
      print('BreathAnalysisScreen: TextSummary: ${result.textSummary}');
      print('BreathAnalysisScreen: Error: ${result.error}');

      if (mounted) {
        setState(() {
          _result = result;
          _state = RecordingState.analyzed;
        });
        
        // Save analysis result to history
        if (result.error == null && result.label.isNotEmpty) {
          await HistoryService.addEntry({
            'label': result.label,
            'confidence': result.confidence,
            'source': 'Breath Analysis',
            'timestamp': DateTime.now(),
            'predictions': result.predictions,
            'raw_response': result.toJson(),
            'file_name': _recordingPath != null ? _recordingPath!.split('/').last : null,  // Add file name
          });
          print('BreathAnalysisScreen: Analysis result saved to history');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = RecordingState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
  }


  Widget _buildRecordingControls() {
    return Column(
      children: [
        if (_state == RecordingState.recording)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              formattedDuration,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
        GestureDetector(
          onLongPressStart: (_) => _startRecording(),
          onLongPressEnd: (_) => _stopRecording(),
          onLongPressCancel: () => _stopRecording(),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _state == RecordingState.recording 
                ? Colors.red 
                : Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _state == RecordingState.recording 
                ? Icons.mic
                : Icons.mic_none_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _state == RecordingState.recording
                ? 'Release to stop recording'
                : 'Press and hold to record',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _cleanupTempFile() async {
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up temp file: $e');
      }
      _recordingPath = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breath Analysis'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructions Card
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recording Instructions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionStep('1', 'Find a quiet place', Icons.volume_off_rounded),
                      _buildInstructionStep('2', 'Hold phone 6 inches from mouth', Icons.phone_android_rounded),
                      _buildInstructionStep('3', 'Press and hold to record', Icons.mic_rounded),
                      _buildInstructionStep('4', 'Breathe normally', Icons.air_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recording Wave
                if (_state == RecordingState.recording || _state == RecordingState.analyzing)
                  RecordingWave(
                    animation: _animationController,
                    isAnalyzing: _state == RecordingState.analyzing,
                  ),

                const SizedBox(height: 24),

                // Recording Controls
                _buildRecordingControls(),

                // Analysis Result
                if (_state == RecordingState.analyzing)
                  const Center(child: CircularProgressIndicator()),
                
                if (_state == RecordingState.analyzed && _result != null)
                  AnalysisResultCard(
                    result: _result!,
                    analysisType: 'Breath',
                  ),

                if (_state == RecordingState.error)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Error: Unable to complete the analysis. Please try again.',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}