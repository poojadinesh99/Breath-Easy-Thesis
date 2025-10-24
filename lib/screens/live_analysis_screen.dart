import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../services/streaming_recorder.dart';
import '../services/backend_config.dart';

class LiveAnalysisScreen extends StatefulWidget {
  final String? userId;
  const LiveAnalysisScreen({super.key, this.userId});

  @override
  State<LiveAnalysisScreen> createState() => _LiveAnalysisScreenState();
}

class _LiveAnalysisScreenState extends State<LiveAnalysisScreen> {
  late final StreamingRecorder _recorder;
  bool _recording = false;
  String? _label;
  double? _confidence;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _recorder = StreamingRecorder(baseUrl: BackendConfig.baseUrl);
    _recorder.init();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _recording = true);
    try {
      await _recorder.start(userId: widget.userId);
    } catch (e) {
      setState(() => _recording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backend error: $e')),
        );
      }
    }
  }

  Future<void> _stop() async {
    final result = await _recorder.stopAndFinalize(userId: widget.userId);
    setState(() {
      _recording = false;
      _label = result['label'] as String?;
      _confidence = (result['confidence'] as num?)?.toDouble();
      _summary = result['text_summary'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Respiratory Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            if (_recording)
              const Text('Recording… sending chunks every second', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _recording ? null : _start,
              child: const Text('Start'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _recording ? _stop : null,
              child: const Text('Stop and Analyze'),
            ),
            const Divider(height: 32),
            if (_label != null) ...[
              Text('Prediction: $_label', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_confidence != null)
                LinearPercentIndicator(
                  lineHeight: 14.0,
                  percent: (_confidence!).clamp(0.0, 1.0),
                  center: Text('${((_confidence!) * 100).toStringAsFixed(1)}%'),
                  backgroundColor: Colors.grey.shade300,
                  progressColor: Colors.blue,
                ),
              const SizedBox(height: 16),
              if (_summary != null)
                Text(_summary!),
            ] else
              const Text('No analysis yet.'),
          ],
        ),
      ),
    );
  }
}
