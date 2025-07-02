import 'package:flutter/material.dart';
import 'breath_analysis_screen.dart';
import 'speech_analysis_screen.dart';

class AnalysisSelectionScreen extends StatelessWidget {
  const AnalysisSelectionScreen({Key? key}) : super(key: key);

  void _navigateToAnalysis(BuildContext context, String type) {
    if (type == 'breath') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BreathAnalysisScreen()),
      );
    } else if (type == 'speech') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SpeechAnalysisScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Analysis Type'),
      ),
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics, size: 72, color: Theme.of(context).primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'Choose the type of analysis you want to perform.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _navigateToAnalysis(context, 'breath'),
                  child: const Text('Breath Analysis'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _navigateToAnalysis(context, 'speech'),
                  child: const Text('Speech Analysis'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
