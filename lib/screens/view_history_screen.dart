import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _history = [];
          _isLoading = false;
          _error = 'Not logged in';
        });
        return;
      }
      final data = await supabase
          .from('analysis_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(200);
      setState(() {
        _history = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _history.isEmpty
                  ? _buildEmptyState()
                  : _buildHistoryList(),
    );
  }

  Widget _buildErrorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Analysis History',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Run an analysis to see results here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        final label = entry['label'] ?? 'Unknown';
        final confidence = (entry['confidence'] as num?)?.toDouble() ?? 0.0;
        final source = entry['source'] ?? 'Unknown';
        final createdAt = entry['created_at'];
        DateTime? ts;
        if (createdAt is String) {
          ts = DateTime.tryParse(createdAt);
        } else if (createdAt is DateTime) {
          ts = createdAt;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.bubble_chart,
              color: label.toLowerCase() == 'clear' ? Colors.green : Colors.orange,
            ),
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
                Text('Source: $source'),
              ],
            ),
            trailing: Text(
              _formatTimestamp(ts),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () => _showHistoryDetails(context, entry),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime? ts) {
    if (ts == null) return 'Unknown';
    return '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
  }

  void _showHistoryDetails(BuildContext context, Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) {
        final preds = entry['predictions'];
        return AlertDialog(
          title: const Text('Analysis Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Label: ${entry['label'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('Confidence: ${( (entry['confidence'] as num?)?.toDouble() ?? 0.0 * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                Text('Source: ${entry['source'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('Timestamp: ${_formatTimestamp(DateTime.tryParse(entry['created_at'] ?? ''))}'),
                if (preds != null) ...[
                  const SizedBox(height: 16),
                  const Text('All Predictions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(preds.toString()),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
