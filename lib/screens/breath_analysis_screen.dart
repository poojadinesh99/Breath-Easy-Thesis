
import 'package:flutter/material.dart';
import 'package:breath_easy/services/firebase_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:breath_easy/services/instruction_service.dart';

class BreathAnalysisScreen extends StatefulWidget {
  const BreathAnalysisScreen({super.key});

  @override
  _BreathAnalysisScreenState createState() => _BreathAnalysisScreenState();
}

class _BreathAnalysisScreenState extends State<BreathAnalysisScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final InstructionService _instructionService = InstructionService();

  bool _isRecording = false;
  String? _recordedFilePath;
  String? _analysisResult;

  final List<AccelerometerEvent> _accelerometerEvents = [];
  final List<GyroscopeEvent> _gyroscopeEvents = [];

  List<Instruction> _instructions = [];
  int _currentInstructionIndex = 0;

  String _patientNumber = '';
  String _patientAge = '';
  String _patientSex = '';

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    await _instructionService.loadInstructions();
    setState(() {
      _instructions = _instructionService.getInstructions();
    });
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  void _startSensors() {
    _accelerometerEvents.clear();
    _gyroscopeEvents.clear();

    accelerometerEvents.listen((event) {
      _accelerometerEvents.add(event);
    });

    gyroscopeEvents.listen((event) {
      _gyroscopeEvents.add(event);
    });
  }

  void _stopSensors() {
    // Optionally process sensor data here
  }

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final currentInstruction = _instructions.isNotEmpty ? _instructions[_currentInstructionIndex] : null;
    final category = currentInstruction != null ? currentInstruction.name.replaceAll(RegExp(r'[\[\]\-]'), '') : 'unknown';
    final filename = '${_patientNumber}_${timestamp}_$category.aac';
    return '${directory.path}/$filename';
  }

  Future<void> _startRecording() async {
    if (_patientNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter patient number before recording')),
      );
      return;
    }
    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No instructions loaded')),
      );
      return;
    }
    final path = await _getFilePath();
    await _recorder.startRecorder(toFile: path);
    _startSensors();
    setState(() {
      _isRecording = true;
      _analysisResult = null;
      _recordedFilePath = path;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _stopSensors();
    setState(() {
      _isRecording = false;
    });
    _performMockAnalysis();
  }

  void _performMockAnalysis() {
    setState(() {
      _analysisResult = "Gait and speech data recorded successfully.";
    });
  }

  Future<void> _uploadFileAndSaveData() async {
    try {
      final user = _authService.getCurrentUser();
      if (user == null) {
        throw Exception("User not logged in");
      }
      if (_recordedFilePath == null) {
        throw Exception("No recorded file to upload");
      }
      final file = File(_recordedFilePath!);
      final storageRef = FirebaseStorage.instance.ref().child('audio_records').child(file.uri.pathSegments.last);
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final currentInstruction = _instructions.isNotEmpty ? _instructions[_currentInstructionIndex] : null;

      final data = {
        'analysisResult': _analysisResult,
        'accelerometerData': _accelerometerEvents.map((e) => {'x': e.x, 'y': e.y, 'z': e.z}).toList(),
        'gyroscopeData': _gyroscopeEvents.map((e) => {'x': e.x, 'y': e.y, 'z': e.z}).toList(),
        'audioFileUrl': downloadUrl,
        'instructionId': currentInstruction?.id,
        'instructionName': currentInstruction?.name,
        'patientNumber': _patientNumber,
        'patientAge': _patientAge,
        'patientSex': _patientSex,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('gait_speech_analysis')
          .add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gait and speech analysis data saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  void _nextInstruction() {
    if (_currentInstructionIndex < _instructions.length - 1) {
      setState(() {
        _currentInstructionIndex++;
        _analysisResult = null;
        _recordedFilePath = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have completed all exercises')),
      );
    }
  }

  void _previousInstruction() {
    if (_currentInstructionIndex > 0) {
      setState(() {
        _currentInstructionIndex--;
        _analysisResult = null;
        _recordedFilePath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentInstruction = _instructions.isNotEmpty ? _instructions[_currentInstructionIndex] : null;
    final localizedText = currentInstruction?.localizedInstructions['en'] ?? 'Loading...';

    return Scaffold(
      appBar: AppBar(title: Text('Gait + Speech Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _instructions.isEmpty
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Exercise ${_currentInstructionIndex + 1} of ${_instructions.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentInstruction?.description ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      localizedText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    // Media playback placeholder (can be implemented later)
                    Text('Media file: ${currentInstruction?.mediaFile ?? 'N/A'}'),
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Patient Number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _patientNumber = value.trim(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Patient Age',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _patientAge = value.trim(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Patient Sex',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _patientSex = value.trim(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isRecording ? _stopRecording : _startRecording,
                      child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                    ),
                    const SizedBox(height: 20),
                    if (_analysisResult != null) ...[
                      Text(_analysisResult!),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _uploadFileAndSaveData,
                        child: Text('Submit Analysis'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _previousInstruction,
                          child: Text('Previous'),
                        ),
                        ElevatedButton(
                          onPressed: _nextInstruction,
                          child: Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}