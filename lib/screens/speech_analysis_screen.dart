import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/unified_service.dart';
import '../services/history_service.dart';
import '../widgets/analysis_result_card.dart';
import '../models/prediction_response.dart';

// Audio recording configuration
const int sampleRate = 16000;
const int bitRate = 16 * 1024;  // 16 kbps
const int numChannels = 1;  // mono

// Speech-specific categories
enum SpeechCategory {
  readingPassage('Reading Passage'),
  describingPicture('Describing Picture'),
  conversation('Conversation'),
  vowelSounds('Vowel Sounds'),
  consonantSounds('Consonant Sounds'),
  sentenceRepetition('Sentence Repetition'),
  wordList('Word List');

  const SpeechCategory(this.displayName);
  final String displayName;
}

enum RecordingState {
  initial,
  recording,
  recorded,
  analyzing,
  analyzed,
  error
}

class SpeechAnalysisScreen extends StatefulWidget {
  const SpeechAnalysisScreen({super.key});

  @override
  State<SpeechAnalysisScreen> createState() => _SpeechAnalysisScreenState();
}

class _SpeechAnalysisScreenState extends State<SpeechAnalysisScreen> 
    with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  final UnifiedService _unifiedService = UnifiedService();
  RecordingState _state = RecordingState.initial;
  SpeechCategory _selectedCategory = SpeechCategory.readingPassage;
  String? _recordingPath;
  PredictionResponse? _result;
  late AnimationController _animationController;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  static const maxDuration = Duration(seconds: 30); // Match backend limit for speech tasks
  String _instructions = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _checkPermissions();
    _updateInstructions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (!await Permission.microphone.isGranted) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() => _state = RecordingState.error);
      }
    }
  }

  void _updateInstructions() {
    switch (_selectedCategory) {
      case SpeechCategory.readingPassage:
        _instructions = 'Read the following passage clearly and at a normal pace:\n\n'
            '"The quick brown fox jumps over the lazy dog. This pangram contains '
            'every letter of the alphabet at least once. It is commonly used to '
            'test typewriters and computer keyboards."';
        break;
      case SpeechCategory.describingPicture:
        _instructions = 'Describe what you see in the image in detail. Include colors, '
            'objects, people, and any activities you observe.';
        break;
      case SpeechCategory.conversation:
        _instructions = 'Have a natural conversation about your day or any topic '
            'you\'d like to discuss.';
        break;
      case SpeechCategory.vowelSounds:
        _instructions = 'Say each vowel sound clearly: A E I O U\n'
            'Hold each sound for 2-3 seconds.';
        break;
      case SpeechCategory.consonantSounds:
        _instructions = 'Say each consonant sound clearly: B D G K P T\n'
            'Make each sound distinctly.';
        break;
      case SpeechCategory.sentenceRepetition:
        _instructions = 'Repeat the following sentence three times:\n\n'
            '"She sells seashells by the seashore."';
        break;
      case SpeechCategory.wordList:
        _instructions = 'Read each word clearly:\n\n'
            'Blue, Chair, Door, Fish, Game, House, Jump, Knife, Light, Moon';
        break;
    }
    setState(() {});
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingDuration = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
      if (_recordingDuration >= maxDuration.inSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      final isPermitted = await _audioRecorder.hasPermission();
      if (!isPermitted) {
        setState(() => _state = RecordingState.error);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/speech_${_selectedCategory.name}_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Configure and start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: sampleRate,
          bitRate: bitRate,
          numChannels: numChannels,
        ),
        path: _recordingPath!,
      );

      setState(() => _state = RecordingState.recording);
      _startRecordingTimer();
      _animationController.repeat();

    } catch (e) {
      print('Error starting recording: $e');
      setState(() => _state = RecordingState.error);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      _animationController.stop();

      setState(() => _state = RecordingState.recorded);

      if (_recordingPath != null) {
        await _analyzeRecording();
      }

    } catch (e) {
      print('Error stopping recording: $e');
      setState(() => _state = RecordingState.error);
    }
  }

  Future<void> _analyzeRecording() async {
    if (_recordingPath == null) return;

    setState(() => _state = RecordingState.analyzing);

    try {
      final result = await _unifiedService.analyzeAudio(
        filePath: _recordingPath!,
        taskType: 'speech'
      );
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
            'source': 'Speech Analysis',
            'timestamp': DateTime.now(),
            'predictions': result.predictions,
            'raw_response': result.toJson(),
            'transcription': result.transcription ?? '',
            'file_name': _recordingPath != null ? _recordingPath!.split('/').last : null,  // Add file name
          });
          print('SpeechAnalysisScreen: Analysis result saved to history');
        }
      }
    } catch (e) {
      print('Error analyzing recording: $e');
      if (mounted) {
        setState(() {
          _result = null;
          _state = RecordingState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Analysis'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Speech Task',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SpeechCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Task Category',
                        ),
                        onChanged: (SpeechCategory? newValue) {
                          if (newValue != null && _state != RecordingState.recording) {
                            setState(() {
                              _selectedCategory = newValue;
                              _updateInstructions();
                            });
                          }
                        },
                        items: SpeechCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category.displayName),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _instructions,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Recording',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (_state == RecordingState.recording) ...[
                        Text(
                          'Recording in progress...',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _recordingDuration / maxDuration.inSeconds,
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Duration: ${_recordingDuration}s / ${maxDuration.inSeconds}s',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: _state == RecordingState.analyzing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(),
                              )
                            : Icon(_state == RecordingState.recording ? Icons.stop : Icons.mic),
                        label: Text(_state == RecordingState.recording ? 'Stop Recording' : 'Start Recording'),
                        onPressed: _state != RecordingState.analyzing
                            ? () {
                                if (_state == RecordingState.recording) {
                                  _stopRecording();
                                } else {
                                  _startRecording();
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_state == RecordingState.error)
                Card(
                  color: Colors.red[100],
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'An error occurred during recording or analysis. Please try again.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              if (_state == RecordingState.analyzed && _result != null)
                AnalysisResultCard(
                  result: _result!,
                  analysisType: 'Speech',
                  category: _selectedCategory.displayName,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
