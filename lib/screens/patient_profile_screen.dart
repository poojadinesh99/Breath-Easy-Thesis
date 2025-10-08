import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/history_service.dart';
import 'patient_intake_form.dart';
import 'symptom_tracker_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  _PatientProfileScreenState createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _patientData;
  List<Map<String, dynamic>> _recentAnalyses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPatientData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Load patient data from Supabase
        final response = await Supabase.instance.client
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1)
            .single();

        setState(() {
          _patientData = response;
        });
      }

      // Load recent analyses
      final allAnalyses = await HistoryService.getSupabaseHistory();
      final recentAnalyses = allAnalyses.take(5).toList();
      setState(() {
        _recentAnalyses = recentAnalyses;
        _isLoading = false;
      });
    } catch (e) {
      // If no patient data found, that's okay
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Profile'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.person)),
            Tab(text: 'Intake Form', icon: Icon(Icons.assignment)),
            Tab(text: 'Symptom Tracker', icon: Icon(Icons.healing)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                PatientIntakeFormScreen(),
                SymptomTrackerScreen(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Info Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.person, size: 30, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patientData?['name'] ?? 'Patient Name',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Age: ${_patientData?['age'] ?? 'Not specified'}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_patientData != null) ...[
                    _buildInfoRow('Contact', _patientData!['contact_number'] ?? 'Not provided'),
                    _buildInfoRow('Smoker', _patientData!['is_smoker'] == true ? 'Yes' : 'No'),
                    _buildInfoRow('Respiratory History', _patientData!['has_respiratory_disease_history'] == true ? 'Yes' : 'No'),
                    _buildInfoRow('COVID Exposure', _patientData!['exposed_to_covid'] == true ? 'Yes' : 'No'),
                    _buildInfoRow('Vaccinated', _patientData!['vaccinated'] == true ? 'Yes' : 'No'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Health Metrics Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Health Metrics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('Total Analyses', _recentAnalyses.length.toString(), Icons.analytics),
                      _buildMetricItem('Clear Results', _countClearResults().toString(), Icons.check_circle),
                      _buildMetricItem('Alerts', _countAlerts().toString(), Icons.warning),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Analyses Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Analyses',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/history'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_recentAnalyses.isEmpty)
                    const Center(
                      child: Text(
                        'No recent analyses found.\nStart analyzing to see your history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._recentAnalyses.take(3).map((analysis) => _buildAnalysisItem(analysis)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.assignment),
                  label: const Text('Update Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.healing),
                  label: const Text('Track Symptoms'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAnalysisItem(Map<String, dynamic> analysis) {
    final label = analysis['label'] ?? 'Unknown';
    final confidence = (analysis['confidence'] as double?) ?? 0.0;
    final source = analysis['source'] ?? 'Unknown';
    final timestamp = analysis['timestamp'] ?? DateTime.now();

    return ListTile(
      leading: Icon(
        Icons.bubble_chart,
        color: label.toLowerCase() == 'clear' ? Colors.green : Colors.orange,
      ),
      title: Text(label),
      subtitle: Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}% • $source'),
      trailing: Text(
        _formatTimestamp(timestamp),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () => _showAnalysisDetails(analysis),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is DateTime) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
    return 'Unknown';
  }

  void _showAnalysisDetails(Map<String, dynamic> analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label: ${analysis['label'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Confidence: ${((analysis['confidence'] as double?) ?? 0.0 * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text('Source: ${analysis['source'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Timestamp: ${_formatTimestamp(analysis['timestamp'])}'),
          ],
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

  int _countClearResults() {
    return _recentAnalyses.where((analysis) =>
      (analysis['label'] ?? '').toLowerCase() == 'clear'
    ).length;
  }

  int _countAlerts() {
    return _recentAnalyses.where((analysis) =>
      (analysis['label'] ?? '').toLowerCase() != 'clear'
    ).length;
  }
}
