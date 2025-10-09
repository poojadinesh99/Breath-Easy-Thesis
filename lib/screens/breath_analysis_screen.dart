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
  BreathCategory _selectedCategory = BreathCategory.breathingDeep;
  String? _recordedFilePath;
  String _statusText = 'Press the button to start recording';

  Map<String, double> _predictions = {};
  String _topLabel = '';
  double _topConfidence = 0.0;
  String _source = '';
  bool _isAnalyzing = false;

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
    return '${directory.path}/${_selectedCategory.name}_$timestamp.aac';
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    final path = await _getFilePath();
    await _recorder.startRecorder(toFile: path, codec: Codec.aacMP4);
    setState(() {
      _isRecording = true;
      _recordedFilePath = path;
      _statusText = 'Recording...';
      _predictions = {};
      _topLabel = '';
      _topConfidence = 0.0;
      _source = '';
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _statusText = 'Recording stopped. Processing...';
      _isAnalyzing = true;
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
            SnackBar(content: Text('Recording uploaded successfully! URL: \$publicUrl')),
          );
          // Save recording metadata to recordings table
          await supabase.from('recordings').insert({
            'user_id': user.id,
            'file_url': publicUrl,
            'category': 'breath_${_selectedCategory.name}',
            'recorded_at': DateTime.now().toIso8601String(),
            'notes': '',
          });

          // Call unified analysis API directly with file
          final analysisResult = await UnifiedAnalysisService.analyzeFile(file);
          setState(() {
            _predictions = Map<String, double>.from(analysisResult['predictions'] ?? {});
            _topLabel = analysisResult['label'] ?? '';
            _topConfidence = (analysisResult['confidence'] as double?) ?? 0.0;
            _source = analysisResult['source'] ?? '';
            _isAnalyzing = false;
            _statusText = 'Analysis complete: $_topLabel (${(_topConfidence * 100).toStringAsFixed(1)}%)';
          });
        } else {
          throw Exception('Failed to upload file to Supabase Storage');
        }
      } catch (e) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Error during analysis: \$e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload or analyze recording: \$e')),
        );
      }
    } else {
      setState(() {
        _isAnalyzing = false;
        _statusText = 'No recording file found to upload';
      });
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

  void _onCategorySelected(BreathCategory category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _onRetry() {
    if (_recordedFilePath != null) {
      setState(() {
        _isAnalyzing = true;
        _statusText = 'Retrying analysis...';
      });
      UnifiedAnalysisService.analyzeUnified(_recordedFilePath!).then((analysisResult) {
        setState(() {
          _predictions = Map<String, double>.from(analysisResult['predictions'] ?? {});
          _topLabel = analysisResult['label'] ?? '';
          _topConfidence = (analysisResult['confidence'] as double?) ?? 0.0;
          _source = analysisResult['source'] ?? '';
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
                    predictions: _predictions,
                    topLabel: _topLabel,
                    confidence: _topConfidence,
                    source: _source,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getBreathInstructions() {
    switch (_selectedCategory) {
      case BreathCategory.breathingShallow:
        return 'Take shallow, quick breaths for 10-15 seconds for accurate analysis.';
      case BreathCategory.breathingDeep:
        return 'Take deep breaths: inhale slowly for 4 seconds, hold for 4 seconds, exhale for 4 seconds. Repeat 3-4 times for best results (minimum 10 seconds total).';
      case BreathCategory.breathingFast:
        return 'Take fast, rapid breaths for 10-15 seconds for accurate analysis.';
      case BreathCategory.breathingSlow:
        return 'Take slow, deliberate breaths for 15-20 seconds.';
      case BreathCategory.coughingHeavy:
        return 'Perform heavy coughing 3-5 times over 10 seconds.';
      case BreathCategory.coughingLight:
        return 'Perform light coughing 3-5 times over 10 seconds.';
      case BreathCategory.wheezing:
        return 'Make wheezing sounds while breathing for 10-15 seconds.';
      case BreathCategory.stridor:
        return 'Make stridor sounds while breathing for 10-15 seconds.';
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
