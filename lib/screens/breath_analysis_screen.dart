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
        title: const Text('Breath Analysis - Record'),
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
                    // Breath-specific category selector
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Breath Pattern',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: BreathCategory.values.map((category) {
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
                    // Instructions specific to breath analysis
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
                              _getBreathInstructions(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
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
                        'Last recording saved at:\n\$_recordedFilePath',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    Text(
                      _statusText,
                      style: AppTheme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Replace original Expanded prediction/history section:
                    if (_predictions.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: PredictionResultWidget(
                            result: {
                              'predictions': _predictions,
                              'label': _topLabel,
                              'confidence': _topConfidence,
                              'source': _source,
                            },
                            onRetry: _onRetry,
                            isLoading: _isAnalyzing,
                          ),
                        ),
                      )
                    else
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchRecordings(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No breath analysis recordings found.')));
                          } else {
                            final recordings = snapshot.data!;
                            return SizedBox(
                              height: 300,
                              child: ListView.builder(
                                itemCount: recordings.length,
                                itemBuilder: (context, index) {
                                  final recording = recordings[index];
                                  return ListTile(
                                    leading: const Icon(Icons.audiotrack),
                                    title: Text(recording['category'] ?? 'Unknown'),
                                    subtitle: Text('Recorded at: ${recording['recorded_at']}'),
                                  );
                                },
                              ),
                            );
                          }
                        },
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
