import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  late final SupabaseClient _client;
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _future = _client
          .from('analysis_history')
          .select('id, analysis_type, predicted_label, confidence, created_at, extra')
          .order('created_at', ascending: false)
          .limit(50)
          .then((value) {
            print('ViewHistoryScreen: Loaded ${value.length} records from Supabase');
            for (var record in value.take(3)) {
              print('ViewHistoryScreen: Record ${record['id']}: ${record['predicted_label']} (${record['confidence']})');
            }
            return value as List<dynamic>;
          }).catchError((error) {
            print('ViewHistoryScreen: Error loading data: $error');
            throw error;
          });
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
      body: FutureBuilder<List<dynamic>>(
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
              final row = data[i] as Map<String, dynamic>;
              final label = row['predicted_label']?.toString() ?? '-';
              final confidence = row['confidence'] ?? 0.0;
              final type = row['analysis_type']?.toString() ?? 'unified';
              final ts = row['created_at']?.toString() ?? '';
              final extra = (row['extra'] as Map?) ?? {};
              
              // Extract the text summary from the backend
              final textSummary = extra['text_summary']?.toString();
              final transcript = extra['transcript']?.toString();
              
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
              }
              
              // Format timestamp
              final DateTime? dateTime = DateTime.tryParse(ts);
              final formattedTime = dateTime != null 
                ? '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
                : ts;
              
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
                      Text('$type • $formattedTime'),
                      const SizedBox(height: 4),
                      if (textSummary != null) 
                        Text(
                          textSummary,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      if (transcript != null) 
                        Text('Transcript: $transcript'),
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
