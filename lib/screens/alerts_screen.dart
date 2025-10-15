import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel; // realtime channel
  String? _userId; // cache user id

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _initRealtime();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _initRealtime() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    _userId = user.id;

    // Subscribe to inserts/updates on analysis_history
    _channel = supabase.channel('public:analysis_history')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'analysis_history',
        callback: (payload) {
          final newRow = payload.newRecord;
          if (newRow == null) return;
          if (newRow['user_id'] != _userId) return; // only this user's data
          final alertCandidate = _mapIfAlert(newRow);
          if (alertCandidate != null) {
            setState(() {
              // Avoid duplicates by id
              _alerts.removeWhere((a) => a['id'] == alertCandidate['id']);
              _alerts.insert(0, alertCandidate);
            });
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'analysis_history',
        callback: (payload) {
          final updated = payload.newRecord;
          if (updated == null) return;
          if (updated['user_id'] != _userId) return;
          final alertCandidate = _mapIfAlert(updated);
          setState(() {
            _alerts.removeWhere((a) => a['id'] == updated['id']);
            if (alertCandidate != null) {
              _alerts.insert(0, alertCandidate);
            }
          });
        },
      )
      .subscribe();
  }

  Map<String, dynamic>? _mapIfAlert(Map<String, dynamic> row) {
    final label = (row['label'] ?? '').toString().toLowerCase();
    final confidence = (row['confidence'] as num?)?.toDouble() ?? 0.0;
    final abnormal = label.contains('abnormal') || label.contains('wheeze') || label.contains('crackle');
    final lowConf = confidence < 0.6;
    if (!(abnormal || lowConf)) return null;
    return {
      'id': row['id'],
      'label': row['label'],
      'confidence': confidence,
      'source': row['source'] ?? 'unknown',
      'predictions': row['predictions'],
      'created_at': row['created_at'],
    };
  }

  Future<void> _loadAlerts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() { _error = 'Not logged in'; _alerts = []; });
        return;
      }

      final data = await supabase
          .from('analysis_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(200);

      final rows = List<Map<String, dynamic>>.from(data);
      final alerts = rows.map(_mapIfAlert).whereType<Map<String, dynamic>>().toList();
      setState(() { _alerts = alerts; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Color _getSeverityColor(double confidence, String label) {
    final l = label.toLowerCase();
    if (l.contains('wheeze') || l.contains('crackle')) return Colors.red;
    if (confidence < 0.4) return Colors.red;
    if (confidence < 0.6) return Colors.orange;
    return Colors.yellow.shade700;
  }

  String _getSeverityText(double confidence, String label) {
    final l = label.toLowerCase();
    if (l.contains('wheeze') || l.contains('crackle')) return 'High';
    if (confidence < 0.4) return 'High';
    if (confidence < 0.6) return 'Medium';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _alerts.isEmpty
                  ? _buildNoAlertsView()
                  : _buildAlertsList(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_error ?? 'Error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _buildNoAlertsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Alerts',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your recent analyses show normal or stable results. Continue monitoring for any changes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        final label = (alert['label'] ?? 'Unknown').toString();
        final confidence = (alert['confidence'] as num?)?.toDouble() ?? 0.0;
        final createdAt = alert['created_at'];
        DateTime? ts;
        if (createdAt is String) ts = DateTime.tryParse(createdAt);
        if (createdAt is DateTime) ts = createdAt;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _getSeverityColor(confidence, label),
                shape: BoxShape.circle,
              ),
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
                Text('Severity: ${_getSeverityText(confidence, label)}'),
              ],
            ),
            trailing: Text(
              _formatTimestamp(ts),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () => _showAlertDetails(alert),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime? ts) {
    if (ts == null) return 'Unknown';
    return '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    final label = (alert['label'] ?? 'Unknown').toString();
    final confidence = (alert['confidence'] as num?)?.toDouble() ?? 0.0;
    final predictions = alert['predictions'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alert Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Label: $label'),
              const SizedBox(height: 8),
              Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              Text('Severity: ${_getSeverityText(confidence, label)}'),
              const SizedBox(height: 16),
              if (predictions != null) ...[
                const Text('Predictions:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(predictions.toString()),
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
      ),
    );
  }
}
