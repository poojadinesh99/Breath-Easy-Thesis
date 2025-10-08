import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class SymptomHistoryVisualizationScreen extends StatefulWidget {
  const SymptomHistoryVisualizationScreen({super.key});

  @override
  State<SymptomHistoryVisualizationScreen> createState() => _SymptomHistoryVisualizationScreenState();
}

class _SymptomHistoryVisualizationScreenState extends State<SymptomHistoryVisualizationScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<charts.Series<SymptomData, DateTime>> _series = [];

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
          .order('logged_at', ascending: true)
          .limit(1000);
      _rows = List<Map<String,dynamic>>.from(data);
      _buildSeries();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _buildSeries() {
    Map<String, List<SymptomData>> grouped = {};
    for (final row in _rows) {
      final symptom = (row['symptom_type'] ?? 'Unknown') as String;
      final severity = (row['severity'] ?? 0) as int;
      final loggedAt = row['logged_at'];
      DateTime? ts;
      if (loggedAt is String) ts = DateTime.tryParse(loggedAt);
      if (ts == null) continue;
      grouped.putIfAbsent(symptom, () => []);
      grouped[symptom]!.add(SymptomData(ts, severity.toDouble()));
    }
    _series = grouped.entries.map((e) {
      return charts.Series<SymptomData, DateTime>(
        id: e.key,
        data: e.value,
        domainFn: (SymptomData d, _) => d.date,
        measureFn: (SymptomData d, _) => d.intensity,
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom History Visualization'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _series.isEmpty
                  ? _buildEmpty()
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: charts.TimeSeriesChart(
                        _series,
                        animate: true,
                        dateTimeFactory: const charts.LocalDateTimeFactory(),
                        behaviors: [
                          charts.SeriesLegend(position: charts.BehaviorPosition.bottom, horizontalFirst: false, desiredMaxColumns: 2),
                          charts.PanAndZoomBehavior(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildError() => Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)));
  Widget _buildEmpty() => const Center(child: Text('No symptom data available.'));
}

class SymptomData {
  final DateTime date;
  final double intensity;
  SymptomData(this.date, this.intensity);
}
