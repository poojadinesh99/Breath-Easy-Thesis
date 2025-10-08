import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/backend_config.dart';
import '../services/breath_easy_api.dart';

// Speech-specific categories
enum SpeechCategory {
  readingPassage('Reading Passage'),
  countingNumbers('Counting Numbers'),
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
  String _statusText = 'Press the button to start recording';

  // Speech-to-text results
  String? _transcript;
  String? _speechMessage;
  bool _isProcessingSpeech = false;

  // Classification results
  String? _classificationResult;
  double? _classificationScore;
  bool _isPredicting = false;

  DateTime? _recordStart; // track start time

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
    setState(() {
      _isRecorderInitialized = true;
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/${_selectedCategory.name}_$timestamp.wav'; // use wav extension
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    final path = await _getFilePath();
    // Use uncompressed WAV for better STT accuracy
    await _recorder.startRecorder(toFile: path, codec: Codec.pcm16WAV, sampleRate: 16000, numChannels: 1);
    _recordStart = DateTime.now();
    setState(() {
      _isRecording = true;
      _recordedFilePath = path;
      _statusText = 'Recording...';
      _transcript = null;
      _speechMessage = null;
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;
    await _recorder.stopRecorder();
    final durationMs = _recordStart != null ? DateTime.now().difference(_recordStart!).inMilliseconds : 0;
    setState(() {
      _isRecording = false;
      _statusText = 'Recording stopped. Processing...';
    });

    if (_recordedFilePath != null) {
      final file = File(_recordedFilePath!);
      final fileSize = await file.length();
      // Basic guard: very short / tiny file likely silence
      if (durationMs < 3000 || fileSize < 5000) {
        setState(() {
          _transcript = 'Recording too short or silent.';
          _speechMessage = 'Please record at least 3 seconds of clear speech for better accuracy.';
          _statusText = 'Recording too short - try again';
        });
        return;
      }
      // Process speech-to-text
      await _processSpeechToText();
      await _runPredictionAndSave();
    }
  }

  Future<void> _processSpeechToText() async {
    if (_recordedFilePath == null) return;

    setState(() {
      _isProcessingSpeech = true;
      _statusText = 'Transcribing speech...';
    });

    try {
      final file = File(_recordedFilePath!);
      if (!await file.exists()) {
        setState(() {
          _transcript = '';
          _speechMessage = 'Audio file missing.';
          _statusText = 'File error';
        });
        return;
      }

      final uri = Uri.parse('${BackendConfig.base}/predict/speech');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        var transcriptVal = (result['transcript'] ?? '').toString().trim();
        if (transcriptVal.isEmpty) {
          // Treat empty as likely silence
            transcriptVal = 'No intelligible speech detected.';
        }
        setState(() {
          _transcript = transcriptVal;
          _speechMessage = (result['message'] ?? (transcriptVal.isEmpty ? 'No speech captured' : 'Transcription complete')).toString();
          _statusText = 'Speech transcribed successfully';
        });
      } else {
        setState(() {
          _transcript = '';
          _speechMessage = 'Speech transcription failed (code ${response.statusCode})';
          _statusText = 'Failed – try again';
        });
      }
    } catch (e) {
      setState(() {
        _transcript = '';
        _speechMessage = 'Error processing speech: $e';
        _statusText = 'Error – check connection';
      });
    } finally {
      setState(() { _isProcessingSpeech = false; });
    }
  }

  Future<void> _runPredictionAndSave() async {
    if (_recordedFilePath == null) return;
    setState(() { _isPredicting = true; });
    try {
      final file = File(_recordedFilePath!);
      final apiResult = await BreathEasyApi().predict(file);
      final result = apiResult['result'] ?? 'Unknown';
      final score = apiResult['score'] is num ? (apiResult['score'] as num).toDouble() : null;
      setState(() {
        _classificationResult = result;
        _classificationScore = score;
      });
      // Insert into Supabase analysis_history
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('analysis_history').insert({
          'user_id': user.id,
          'type': 'speech',
          'result': result,
          'score': score,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prediction error: $e')),
      );
    } finally {
      setState(() { _isPredicting = false; });
    }
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
    });
  }

  String _getSpeechInstructions() {
    switch (_selectedCategory) {
      case SpeechCategory.readingPassage:
        return 'Read the following passage clearly and at a normal pace:\n\n"The quick brown fox jumps over the lazy dog. This pangram contains every letter of the alphabet at least once. It is commonly used to test typewriters and computer keyboards."';
      case SpeechCategory.countingNumbers:
        return 'Count from 1 to 20 clearly and at a steady pace:\n\n"1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20"';
      case SpeechCategory.describingPicture:
        return 'Describe what you see in an imaginary picture. For example:\n\n"I see a beautiful landscape with mountains in the background, a lake in the middle, and trees surrounding it. The sky is blue with some white clouds."';
      case SpeechCategory.conversation:
        return 'Have a natural conversation. You can talk about:\n\n- Your daily activities\n- The weather\n- Your hobbies\n- Recent news or events\n\nSpeak for at least 30 seconds.';
      case SpeechCategory.vowelSounds:
        return 'Pronounce the following vowel sounds clearly:\n\n"A" (as in "cat"), "E" (as in "bed"), "I" (as in "sit"), "O" (as in "hot"), "U" (as in "cut")\n\nRepeat each sound 3 times.';
      case SpeechCategory.consonantSounds:
        return 'Pronounce the following consonant sounds clearly:\n\n"B" (as in "bat"), "D" (as in "dog"), "F" (as in "fish"), "G" (as in "go"), "H" (as in "hat")\n\nRepeat each sound 3 times.';
      case SpeechCategory.sentenceRepetition:
        return 'Repeat the following sentences clearly:\n\n1. "The weather is beautiful today."\n2. "I would like a cup of coffee."\n3. "She sells seashells by the seashore."';
      case SpeechCategory.wordList:
        return 'Read the following words clearly and slowly:\n\n"Apple, banana, computer, elephant, flower, guitar, hospital, island, jungle, kangaroo"';
    }
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
                              _getSpeechInstructions(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: _isProcessingSpeech
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
                    if (_transcript != null || _speechMessage != null) ...[
                      if (_transcript != null && _transcript!.isNotEmpty)
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
                      if (_speechMessage != null && _speechMessage!.isNotEmpty)
                        Card(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Message:',
                                  style: AppTheme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _speechMessage!,
                                  style: AppTheme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],

                    // Classification result
                    if (_classificationResult != null) ...[
                      Card(
                        color: _classificationResult == 'Normal' ? Colors.green[100] : _classificationResult == 'Warning' ? Colors.yellow[100] : Colors.red[100],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Classification:', style: AppTheme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(_classificationResult!, style: AppTheme.textTheme.bodyMedium),
                              if (_classificationScore != null)
                                Text('Score: ${_classificationScore!.toStringAsFixed(2)}', style: AppTheme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isPredicting)
                      const Center(child: CircularProgressIndicator()),

                    // Replace Expanded FutureBuilder with fixed height list
                    SizedBox(
                      height: 320,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchRecordings(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('No speech analysis recordings found.'));
                          } else {
                            final recordings = snapshot.data!;
                            return ListView.builder(
                              itemCount: recordings.length,
                              itemBuilder: (context, index) {
                                final recording = recordings[index];
                                return ListTile(
                                  leading: const Icon(Icons.audiotrack),
                                  title: Text(recording['category'] ?? 'Unknown'),
                                  subtitle: Text('Recorded at: ${recording['recorded_at']}'),
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
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
          .ilike('category', 'speech_%')
          .order('recorded_at', ascending: false);

      return data;
    } on Exception catch (e) {
      throw Exception(e.toString());
    }
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
