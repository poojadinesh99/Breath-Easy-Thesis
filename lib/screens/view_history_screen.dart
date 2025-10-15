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
    _future = _client
        .from('analysis_history')
        .select('id, analysis_type, predicted_label, confidence, created_at, extra')
        .order('created_at', ascending: false)
        .limit(50)
        .then((value) => value as List<dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis History')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }
          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final row = data[i] as Map<String, dynamic>;
              final label = row['predicted_label']?.toString() ?? '-';
              final conf = (row['confidence'] ?? 0).toString();
              final type = row['analysis_type']?.toString() ?? 'unified';
              final ts = row['created_at']?.toString() ?? '';
              final extra = (row['extra'] as Map?) ?? {};
              final transcript = extra['transcript']?.toString();
              final summary = extra['audio_metadata']?['summary']?.toString();
              return ListTile(
                title: Text(label),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$type • $ts'),
                    if (summary != null) Text('Summary: $summary'),
                    if (transcript != null) Text('Transcript: $transcript'),
                  ],
                ),
                trailing: Text(conf),
              );
            },
          );
        },
      ),
    );
  }
}
