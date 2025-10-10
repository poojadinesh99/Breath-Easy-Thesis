import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/unified_analysis_service.dart';

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

class SpeechAnalysisScreen extends StatefulWidget {
  const SpeechAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<SpeechAnalysisScreen> createState() => _SpeechAnalysisScreenState();
}

class _SpeechAnalysisScreenState extends State<SpeechAnalysisScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  SpeechCategory _selectedCategory = SpeechCategory.readingPassage;
  String? _recordedFilePath;
  String _statusText = 'Select a category and press record';
  String _instructions = '';

  String? _transcript;
  Map<String, double> _predictions = {};
  String _topLabel = '';
  double _topConfidence = 0.0;
  bool _isAnalyzing = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _updateInstructions();
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
        _hasError = true;
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) {
      setState(() {
        _statusText = 'Recorder not initialized';
        _hasError = true;
      });
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordedFilePath = '${dir.path}/${_selectedCategory.name}_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _recorder.startRecorder(
        toFile: _recordedFilePath,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
        bitRate: 16 * 44100, // 16-bit
        numChannels: 1, // mono
      );

      setState(() {
        _isRecording = true;
        _statusText = 'Recording... speak clearly';
        _hasError = false;
        _transcript = null;
        _predictions.clear();
      });

      // Stop recording after 15 seconds
      await Future.delayed(const Duration(seconds: 15));
      if (_isRecording) {
        await _stopRecording();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error during recording: $e';
        _hasError = true;
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
        _hasError = true;
        _isRecording = false;
      });
    }
  }

  Future<void> _analyzeRecording() async {
    if (_recordedFilePath == null) {
      setState(() {
        _statusText = 'No recording to analyze';
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _hasError = false;
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
        _transcript = result['text_summary'];
        _statusText = 'Analysis complete';
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'Analysis failed: $e';
        _hasError = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Analysis - Record'),
        backgroundColor: AppTheme.notWhite,
        foregroundColor: AppTheme.darkerText,
        elevation: 0,
      ),
      backgroundColor: AppTheme.notWhite,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Speech-specific category selector
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Speech Task',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: SpeechCategory.values.map((category) {
                                return ChoiceChip(
                                  label: Text(category.displayName),
                                  selected: _selectedCategory == category,
                                  onSelected: (selected) {
                                    if (selected) {
                                      _onCategorySelected(category);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Instructions specific to speech analysis
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Instructions',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _instructions,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: _isAnalyzing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                      onPressed: _isRecorderInitialized ? _onRecordButtonPressed : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_recordedFilePath != null)
                      Text(
                        'Last recording saved at:\n$_recordedFilePath',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    Text(
                      _statusText,
                      style: AppTheme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Speech-to-text results
                    if (_transcript != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transcript:',
                                style: AppTheme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _transcript!,
                                style: AppTheme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Classification result
                    if (_topLabel.isNotEmpty) ...[
                      Card(
                        color: _topLabel == 'Normal' ? Colors.green[100] : _topLabel == 'Warning' ? Colors.yellow[100] : Colors.red[100],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Analysis Result:', style: AppTheme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text('Label: $_topLabel', style: AppTheme.textTheme.bodyMedium),
                              Text('Confidence: ${(_topConfidence * 100).toStringAsFixed(1)}%', style: AppTheme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isAnalyzing)
                      const Center(child: CircularProgressIndicator()),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onRecordButtonPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _onCategorySelected(SpeechCategory category) {
    setState(() {
      _selectedCategory = category;
      _updateInstructions();
    });
  }
}

class AppTheme {
  static const Color notWhite = Color(0xFFF8F8F8);
  static const Color darkerText = Color(0xFF333333);
  static const Color primaryColor = Color(0xFF1976D2);

  static const TextTheme textTheme = TextTheme(
    bodyMedium: TextStyle(fontSize: 16, color: darkerText),
    titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: darkerText),
  );
}
