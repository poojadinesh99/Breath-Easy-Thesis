import 'package:flutter/material.dart';
import 'breath_analysis_screen.dart';
import 'speech_analysis_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisSelectionScreen extends StatelessWidget {
  const AnalysisSelectionScreen({super.key});

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
                const SizedBox(height: 16),
                FutureBuilder<String?>(
                  future: _getInferencePref(),
                  builder: (context, snap) {
                    final current = snap.data ?? 'default';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Inference:'),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: current,
                          items: const [
                            DropdownMenuItem(value: 'default', child: Text('Auto')),
                            DropdownMenuItem(value: 'local', child: Text('Local')),
                            DropdownMenuItem(value: 'hf', child: Text('HuggingFace')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            await _setInferencePref(v);
                            (context as Element).markNeedsBuild();
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _navigateToAnalysis(context, 'breath'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Breath Analysis'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _navigateToAnalysis(context, 'speech'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Speech Analysis'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _setInferencePref(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('inference_source', value);
  }

  static Future<String?> _getInferencePref() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('inference_source');
  }
}
