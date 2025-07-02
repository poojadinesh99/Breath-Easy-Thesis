import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/breath_analysis/data/models/sound_sample.dart';
import '../features/breath_analysis/presentation/sound_category_selector.dart';
import 'app_theme.dart';

class SpeechAnalysisScreen extends StatefulWidget {
  const SpeechAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<SpeechAnalysisScreen> createState() => _SpeechAnalysisScreenState();
}

class _SpeechAnalysisScreenState extends State<SpeechAnalysisScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  SoundCategory _selectedCategory = SoundCategory.breathingShallow;
  String? _recordedFilePath;
  String _statusText = 'Press the button to start recording';

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
    return '${directory.path}/${_selectedCategory.toString()}_$timestamp.aac';
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    final path = await _getFilePath();
    await _recorder.startRecorder(toFile: path, codec: Codec.aacMP4);
    setState(() {
      _isRecording = true;
      _recordedFilePath = path;
      _statusText = 'Recording...';
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _statusText = 'Recording stopped. Processing...';
    });

    if (_recordedFilePath != null) {
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception("User not logged in");
        }
        final file = File(_recordedFilePath!);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${_selectedCategory.toString()}_$timestamp.aac';
        final filePath = 'recordings/${user.id}/$fileName';

        final response = await supabase.storage.from('recordings').upload(filePath, file);

        if (response != null && response.isNotEmpty) {
          final publicUrl = supabase.storage.from('recordings').getPublicUrl(filePath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording uploaded successfully! URL: $publicUrl')),
          );
          // Save recording metadata to recordings table
          await supabase.from('recordings').insert({
            'user_id': user.id,
            'file_url': publicUrl,
            'category': _selectedCategory.toString(),
            'recorded_at': DateTime.now().toIso8601String(),
            'notes': '',
          });
        } else {
          throw Exception('Failed to upload file to Supabase Storage');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload recording: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording file found to upload')),
      );
    }
  }

  void _onRecordButtonPressed() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _onCategorySelected(SoundCategory category) {
    setState(() {
      _selectedCategory = category;
    });
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SoundCategorySelector(
              selectedCategory: _selectedCategory,
              onCategorySelected: _onCategorySelected,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
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
            Expanded(
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
                          onTap: () {
                            // Optionally, implement playback or details
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
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
      // 👇 the builder itself is a Future → just await it
      final data = await supabase
          .from('recordings')
          .select() // typed result
          .eq('user_id', user.id)
          .eq('category', 'speech')
          .order('recorded_at', ascending: false);

      return data; // List<Map<String,dynamic>>
    } on PostgrestException catch (e) {
      // new error style
      throw Exception(e.message);
    }
  }
}
