import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SymptomHistoryScreen extends StatefulWidget {
  const SymptomHistoryScreen({super.key});

  @override
  State<SymptomHistoryScreen> createState() => _SymptomHistoryScreenState();
}

class _SymptomHistoryScreenState extends State<SymptomHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() { _error = 'Not logged in'; _loading = false; });
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('symptoms')
          .select()
          .eq('user_id', user.id)
          .order('logged_at', ascending: false)
          .limit(500);
      setState(() { _rows = List<Map<String,dynamic>>.from(data); });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom History'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _rows.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
          const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.healing, size: 72, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No symptom logs yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        const Text('Track symptoms to see them listed here.', style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  Widget _buildList() => ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: _rows.length,
    itemBuilder: (context, index) {
      final row = _rows[index];
      final symptom = row['symptom_type'] ?? 'Unknown';
      final severity = row['severity'] ?? 0;
      final notes = row['notes'];
      final loggedAt = row['logged_at'];
      DateTime? ts;
      if (loggedAt is String) ts = DateTime.tryParse(loggedAt);
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: severity >= 7 ? Colors.redAccent : (severity >= 4 ? Colors.orange : Colors.green),
            child: Text(severity.toString(), style: const TextStyle(color: Colors.white)),
          ),
          title: Text(symptom),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logged: ${_format(ts)}'),
              if (notes != null && (notes as String).trim().isNotEmpty) Text('Notes: $notes'),
            ],
          ),
        ),
      );
    },
  );

  String _format(DateTime? ts) {
    if (ts == null) return 'Unknown';
    return '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')} ${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}';
  }
}
