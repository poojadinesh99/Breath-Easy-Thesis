import 'package:flutter/material.dart';
import '../services/demo_analysis_service.dart';
import '../widgets/prediction_result_widget.dart';

class DemoAnalysisScreen extends StatefulWidget {
  const DemoAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<DemoAnalysisScreen> createState() => _DemoAnalysisScreenState();
}

class _DemoAnalysisScreenState extends State<DemoAnalysisScreen> {
  bool _isAnalyzing = false;
  Map<String, double> _predictions = {};
  String _topLabel = '';
  double _topConfidence = 0.0;
  String _source = '';

  Future<void> _runDemoAnalysis() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await DemoAnalysisService.analyzeDemo();
      setState(() {
        _predictions = Map<String, double>.from(result['predictions'] ?? {});
        _topLabel = result['label'] ?? '';
        _topConfidence = (result['confidence'] as double?) ?? 0.0;
        _source = result['source'] ?? '';
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo analysis failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Analysis'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Demo Breath Analysis',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This is a demo of the breath analysis feature. Click the button below to run a sample analysis.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isAnalyzing ? null : _runDemoAnalysis,
              child: _isAnalyzing
                  ? const CircularProgressIndicator()
                  : const Text('Run Demo Analysis'),
            ),
            const SizedBox(height: 20),
            if (_predictions.isNotEmpty)
              Expanded(
                child: PredictionResultWidget(
                  result: {
                    'predictions': _predictions,
                    'label': _topLabel,
                    'confidence': _topConfidence,
                    'source': _source,
                  },
                  onRetry: _runDemoAnalysis,
                  isLoading: _isAnalyzing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
