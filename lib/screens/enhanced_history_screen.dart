import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../widgets/prediction_result_widget.dart';

class EnhancedHistoryScreen extends StatefulWidget {
  const EnhancedHistoryScreen({super.key});

  @override
  _EnhancedHistoryScreenState createState() => _EnhancedHistoryScreenState();
}

class _EnhancedHistoryScreenState extends State<EnhancedHistoryScreen> {
  String _searchQuery = '';
  String _selectedDiagnosis = '';
  DateTime? _startDate;
  DateTime? _endDate;
  double _minConfidence = 0.0;
  double _maxConfidence = 1.0;

  final List<String> _diagnosisOptions = ['Clear', 'Wheezing', 'Crackles', 'Stridor'];

  @override
  Widget build(BuildContext context) {
    final filteredHistory = AnalyticsService.getFilteredHistory(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      diagnosisFilter: _selectedDiagnosis.isEmpty ? null : _selectedDiagnosis,
      startDate: _startDate,
      endDate: _endDate,
      minConfidence: _minConfidence,
      maxConfidence: _maxConfidence,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by diagnosis or source...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filter Summary
          if (_hasActiveFilters())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getFilterSummary(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Results: ${filteredHistory.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to statistics dashboard
                    Navigator.pushNamed(context, '/statistics');
                  },
                  child: const Text('View Analytics'),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: filteredHistory.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: filteredHistory.length,
                  itemBuilder: (context, index) {
                    final analysis = filteredHistory[index];
                    return _buildHistoryItem(analysis);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty && !_hasActiveFilters()
              ? 'No analysis history yet'
              : 'No results found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty && !_hasActiveFilters()
              ? 'Start by running a breath analysis'
              : 'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> analysis) {
    final timestamp = analysis['timestamp'] as DateTime;
    final label = analysis['label'] ?? 'Unknown';
    final confidence = (analysis['confidence'] as double?) ?? 0.0;
    final source = analysis['source'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with timestamp and source
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSourceColor(source),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    source,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Diagnosis and confidence
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getDiagnosisColor(label),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _getDiagnosisIcon(label),
                  color: _getDiagnosisColor(label),
                  size: 32,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Predictions preview
            if (analysis['predictions'] != null && (analysis['predictions'] as Map).isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Predictions:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._buildPredictionChips(analysis['predictions']),
                  ],
                ),
              ),

            // Expandable detailed view
            TextButton(
              onPressed: () {
                _showDetailedAnalysis(analysis);
              },
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPredictionChips(Map predictions) {
    return predictions.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
        child: Chip(
          label: Text(
            '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: _getConfidenceColor(entry.value),
        ),
      );
    }).toList();
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'demo':
        return Colors.blue;
      case 'live':
        return Colors.green;
      case 'file':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getDiagnosisColor(String diagnosis) {
    switch (diagnosis.toLowerCase()) {
      case 'clear':
        return Colors.green;
      case 'wheezing':
        return Colors.orange;
      case 'crackles':
        return Colors.blue;
      case 'stridor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getDiagnosisIcon(String diagnosis) {
    switch (diagnosis.toLowerCase()) {
      case 'clear':
        return Icons.check_circle;
      case 'wheezing':
        return Icons.warning;
      case 'crackles':
        return Icons.hearing;
      case 'stridor':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade100;
    if (confidence >= 0.6) return Colors.yellow.shade100;
    return Colors.red.shade100;
  }

  void _showDetailedAnalysis(Map<String, dynamic> analysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Analysis Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const Divider(),

                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        PredictionResultWidget(
                          result: analysis,
                          onRetry: () {},
                          isLoading: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Analysis History'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Diagnosis Filter
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Diagnosis',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDiagnosis.isEmpty ? null : _selectedDiagnosis,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All Diagnoses')),
                        ..._diagnosisOptions.map((diagnosis) =>
                          DropdownMenuItem(value: diagnosis, child: Text(diagnosis))
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDiagnosis = value ?? '';
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Date Range
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _startDate = date;
                                });
                              }
                            },
                            child: Text(
                              _startDate == null
                                ? 'Start Date'
                                : DateFormat('MMM dd').format(_startDate!),
                            ),
                          ),
                        ),
                        const Text(' - '),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _endDate = date;
                                });
                              }
                            },
                            child: Text(
                              _endDate == null
                                ? 'End Date'
                                : DateFormat('MMM dd').format(_endDate!),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Confidence Range
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Confidence Range'),
                        RangeSlider(
                          values: RangeValues(_minConfidence, _maxConfidence),
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          labels: RangeLabels(
                            '${(_minConfidence * 100).toStringAsFixed(0)}%',
                            '${(_maxConfidence * 100).toStringAsFixed(0)}%',
                          ),
                          onChanged: (values) {
                            setState(() {
                              _minConfidence = values.start;
                              _maxConfidence = values.end;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _clearFilters();
                    });
                  },
                  child: const Text('Clear All'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    this.setState(() {});
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _hasActiveFilters() {
    return _selectedDiagnosis.isNotEmpty ||
           _startDate != null ||
           _endDate != null ||
           _minConfidence > 0.0 ||
           _maxConfidence < 1.0;
  }

  String _getFilterSummary() {
    final filters = <String>[];

    if (_selectedDiagnosis.isNotEmpty) {
      filters.add('Diagnosis: $_selectedDiagnosis');
    }

    if (_startDate != null || _endDate != null) {
      final start = _startDate != null ? DateFormat('MMM dd').format(_startDate!) : '...';
      final end = _endDate != null ? DateFormat('MMM dd').format(_endDate!) : '...';
      filters.add('Date: $start - $end');
    }

    if (_minConfidence > 0.0 || _maxConfidence < 1.0) {
      filters.add('Confidence: ${(_minConfidence * 100).toStringAsFixed(0)}% - ${(_maxConfidence * 100).toStringAsFixed(0)}%');
    }

    return filters.join(', ');
  }

  void _clearFilters() {
    _searchQuery = '';
    _selectedDiagnosis = '';
    _startDate = null;
    _endDate = null;
    _minConfidence = 0.0;
    _maxConfidence = 1.0;
  }
}
