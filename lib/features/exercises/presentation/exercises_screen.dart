import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../breath_analysis/data/models/sound_sample.dart';
import '../data/coswara_task.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final List<CoswaraTask> _tasks = coswaraTasks;
  CoswaraTask? _selectedTask;
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _openRecorder();
    _openPlayer();
  }

  Future<void> _openRecorder() async {
    await _recorder!.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _openPlayer() async {
    await _player!.openPlayer();
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _player!.closePlayer();
    _recorder = null;
    _player = null;
    super.dispose();
  }

  Future<void> _startRecording() async {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/coswara_recording.aac';
    await _recorder!.startRecorder(toFile: path);
    setState(() {
      _isRecording = true;
      _recordedFilePath = path;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    _showAnalysis();
    _uploadRecording();
  }

  Future<void> _startPlayback() async {
    if (_recordedFilePath == null) return;
    await _player!.startPlayer(
      fromURI: _recordedFilePath,
      whenFinished: () {
        setState(() {
          _isPlaying = false;
        });
      },
    );
    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _stopPlayback() async {
    await _player!.stopPlayer();
    setState(() {
      _isPlaying = false;
    });
  }

  void _showAnalysis() {
    if (_recordedFilePath == null) return;
    String message = _fakeAnalysis(_recordedFilePath!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _fakeAnalysis(String filePath) {
  final lowerPath = filePath.toLowerCase();

  if (lowerPath.contains('cough')) {
    return "🛑 Alert: Intense coughing detected. Consider medical advice.";
  } else if (lowerPath.contains('breathing')) {
    return "🫁 Breathing pattern looks smooth and consistent ✅";
  } else if (lowerPath.contains('vowel') || lowerPath.contains('aah') || lowerPath.contains('eee')) {
    return "🗣️ Vowel pronunciation detected. Voice clarity seems good!";
  } else if (lowerPath.contains('count') || lowerPath.contains('number')) {
    return "🔢 Counting task completed clearly.";
  } else {
    return "✅ Recording analyzed. No anomalies detected.";
  }
}

 String _sanitizeFileName(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '') // remove non-word characters
      .replaceAll(' ', '_')               // replace spaces with underscores
      .trim();
}

Future<void> _uploadRecording() async {
  if (_recordedFilePath == null || _selectedTask == null) return;

  try {
    final user = Supabase.instance.client.auth.currentUser;
    print("👤 Authenticated UID: ${user?.id}");

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in. Please login first.")),
      );
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    final file = File(_recordedFilePath!);
    final sanitizedTask = _sanitizeFileName(_selectedTask!.sampleName);
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '').replaceAll('T', '_');
    final fileName = '${user.id}/${sanitizedTask}_$timestamp.aac';

    final storageResponse = await Supabase.instance.client.storage
        .from('recordings')
        .upload(fileName, file);

    final url = Supabase.instance.client.storage
        .from('recordings')
        .getPublicUrl(fileName);

    if (url == null) {
      throw Exception('Failed to get public URL');
    }

    await Supabase.instance.client.from('exercises').insert({
      'user_id': user.id, // MUST match auth.uid()
      'exercise_name': _selectedTask!.sampleName,
      'completed_at': DateTime.now().toIso8601String(),
      'recording_url': url,
    });

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to upload recording: $e")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    if (_selectedTask == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Coswara Tasks'),
        ),
        body: ListView.builder(
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final task = _tasks[index];
            return Card(
              child: ListTile(
                leading: Icon(
                  task.category == "Breathing" 
                    ? Icons.air 
                    : task.category == "Cough"
                      ? Icons.sick
                      : Icons.record_voice_over,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(task.sampleName),
                subtitle: Text(task.description),
                trailing: IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      _selectedTask = task;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text('Record Task'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _selectedTask = null;
                _recordedFilePath = null;
              });
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Task: ${_selectedTask!.sampleName}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(_selectedTask!.description),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
              const SizedBox(height: 20),
              if (_recordedFilePath != null)
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(_isPlaying ? 'Stop Playback' : 'Play Recording'),
                      onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Recorded file: $_recordedFilePath')),
                  ],
                ),
            ],
          ),
        ),
      );
    }
  }
}
