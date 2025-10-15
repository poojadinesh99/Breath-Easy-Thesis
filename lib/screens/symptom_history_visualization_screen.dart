import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class SymptomHistoryVisualizationScreen extends StatefulWidget {
  const SymptomHistoryVisualizationScreen({super.key});

  @override
  State<SymptomHistoryVisualizationScreen> createState() => _SymptomHistoryVisualizationScreenState();
}

class _SymptomHistoryVisualizationScreenState extends State<SymptomHistoryVisualizationScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Map<String, List<FlSpot>> _symptomData = {};
  final _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

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
      _processData();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _processData() {
    _symptomData.clear();
    final now = DateTime.now();
    
    // Group data by symptom type
    for (final row in _rows) {
      final symptom = (row['symptom_type'] ?? 'Unknown') as String;
      final severity = (row['severity'] as num).toDouble();
      final date = DateTime.parse(row['logged_at'] as String);
      
      // Convert to days from now for x-axis
      final days = now.difference(date).inDays.toDouble();
      
      _symptomData.putIfAbsent(symptom, () => []);
      _symptomData[symptom]!.add(FlSpot(days, severity));
    }
    
    // Sort points by x value for each symptom
    for (final points in _symptomData.values) {
      points.sort((a, b) => a.x.compareTo(b.x));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return const Center(
        child: Text('No symptom history recorded yet.'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 400,
              child: LineChart(
                LineChartData(
                  lineBarsData: _buildLineBarsData(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Severity'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Days Ago'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 7,
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    verticalInterval: 7,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xff37434d)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineBarsData() {
    final List<LineChartBarData> lines = [];
    var colorIndex = 0;

    for (final entry in _symptomData.entries) {
      final color = _colors[colorIndex % _colors.length];
      lines.add(
        LineChartBarData(
          spots: entry.value,
          isCurved: true,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      );
      colorIndex++;
    }

    return lines;
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: _symptomData.keys.map((symptom) {
        final colorIndex = _symptomData.keys.toList().indexOf(symptom);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _colors[colorIndex % _colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(symptom),
          ],
        );
      }).toList(),
    );
  }
}
