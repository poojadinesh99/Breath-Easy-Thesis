import 'package:flutter/material.dart';
import '../services/history_service.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _future = HistoryService.getSupabaseHistory();
    });
  }

  Future<void> _refreshHistory() async {
    _loadHistory();
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis History')),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshHistory,
        child: const Icon(Icons.refresh),
        tooltip: 'Refresh History',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('ViewHistoryScreen: Error in snapshot: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading history:\n${snapshot.error}',
                       textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshHistory,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data ?? [];
          print('ViewHistoryScreen: Building UI with ${data.length} records');
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No analysis history yet.\nComplete a breath analysis to see results here.'),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refreshHistory,
            child: ListView.separated(
              itemCount: data.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
              final analysis = data[i];
              final label = analysis['label']?.toString() ?? '-';
              final confidence = analysis['confidence'] ?? 0.0;
              final source = analysis['source']?.toString() ?? 'Breath Analysis';
              final timestamp = analysis['timestamp'] as DateTime?;
              final isReal = analysis['isReal'] ?? false;

              // Extract detailed information from the analysis data
              final verdict = analysis['verdict']?.toString();
              final textSummary = analysis['text_summary']?.toString();
              final possibleConditions = analysis['possible_conditions'] as List?;
              final acousticFeatures = analysis['acoustic_features'] as Map?;
              final transcript = analysis['transcription']?.toString();
              final processingTime = analysis['processing_time'] as double?;

              // Format confidence as percentage
              final confidenceText = '${(confidence * 100).toStringAsFixed(1)}%';

              // Create user-friendly title
              String title = label.toUpperCase();
              if (label == 'normal') {
                title = '✅ Normal Breathing';
              } else if (label == 'crackles') {
                title = '⚠️ Crackles Detected';
              } else if (label == 'wheezing') {
                title = '⚠️ Wheezing Detected';
              } else if (label == 'abnormal') {
                title = '⚠️ Abnormal Pattern';
              } else if (label == 'cough') {
                title = '🗣️ Cough Detected';
              } else if (label == 'heavy_breathing') {
                title = '💨 Heavy Breathing';
              } else if (label == 'throat_clearing') {
                title = '🧽 Throat Clearing';
              }

              // Format timestamp
              final formattedTime = timestamp != null
                ? '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                : 'Unknown time';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('$source • $formattedTime'),
                      const SizedBox(height: 4),
                      if (verdict != null && verdict.isNotEmpty)
                        Text(
                          verdict,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      if (textSummary != null && textSummary.isNotEmpty)
                        Text(
                          textSummary,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      if (possibleConditions != null && possibleConditions.isNotEmpty)
                        Text(
                          'Possible conditions: ${possibleConditions.join(", ")}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (acousticFeatures != null && acousticFeatures.isNotEmpty)
                        Text(
                          'Energy: ${(acousticFeatures['energy_variation'] as double?)?.toStringAsFixed(2) ?? "N/A"}, '
                          'Harsh: ${(acousticFeatures['harsh_sound_ratio'] as double?)?.toStringAsFixed(2) ?? "N/A"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (transcript != null && transcript.isNotEmpty)
                        Text(
                          'Transcript: $transcript',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (processingTime != null)
                        Text(
                          'Processed in ${(processingTime * 1000).toStringAsFixed(0)}ms',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (!isReal)
                        Text(
                          'Sample data',
                          style: const TextStyle(fontSize: 10, color: Colors.blue, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(confidence),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      confidenceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
