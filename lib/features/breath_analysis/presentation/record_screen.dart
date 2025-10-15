import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/sound_sample.dart';
import 'sound_category_selector.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  SoundCategory _selectedCategory = SoundCategory.breathingShallow;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
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
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
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
        final filePath = 'audio/${user.id}/$fileName';

        final response = await supabase.storage.from('audio').upload(filePath, file);

        if (response != null && response.isNotEmpty) {
          final publicUrl = supabase.storage.from('audio').getPublicUrl(filePath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording uploaded successfully! URL: $publicUrl')),
          );
          // Optionally, save publicUrl.data to your database
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

    // Show local saved path info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording saved: $_recordedFilePath')),
    );
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
        title: const Text('Breath Analysis - Record'),
      ),
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
          ],
        ),
      ),
    );
  }
}
