import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'history_service.dart';

class AnalyticsService {
  static Map<String, dynamic> getHealthOverview() {
    final history = HistoryService.getHistory();

    // Calculate basic statistics
    final totalAnalyses = history.length;
    final clearResults = history.where((analysis) =>
      (analysis['label'] ?? '').toLowerCase() == 'clear'
    ).length;
    final alertResults = totalAnalyses - clearResults;
    final averageConfidence = history.isEmpty ? 0.0 :
      history.map((e) => (e['confidence'] as double?) ?? 0.0)
          .reduce((a, b) => a + b) / history.length;

    // Get most common diagnosis
    final diagnosisCount = <String, int>{};
    for (var analysis in history) {
      final label = analysis['label'] ?? 'Unknown';
      diagnosisCount[label] = (diagnosisCount[label] ?? 0) + 1;
    }
    final mostCommonDiagnosis = diagnosisCount.isEmpty ? 'None' :
      diagnosisCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'totalAnalyses': totalAnalyses,
      'clearResults': clearResults,
      'alertResults': alertResults,
      'averageConfidence': averageConfidence,
      'mostCommonDiagnosis': mostCommonDiagnosis,
      'clearPercentage': totalAnalyses > 0 ? (clearResults / totalAnalyses) * 100 : 0.0,
      'alertPercentage': totalAnalyses > 0 ? (alertResults / totalAnalyses) * 100 : 0.0,
    };
  }

  static List<PieChartSectionData> getDiagnosisDistribution() {
    final history = HistoryService.getHistory();
    final diagnosisCount = <String, int>{};

    // Count occurrences of each diagnosis
    for (var analysis in history) {
      final label = analysis['label'] ?? 'Unknown';
      diagnosisCount[label] = (diagnosisCount[label] ?? 0) + 1;
    }

    // Convert to chart sections
    final colors = [
      const Color(0xFF4CAF50), // Green for Clear
      const Color(0xFFFF9800), // Orange for Wheezing
      const Color(0xFF2196F3), // Blue for Crackles
      const Color(0xFFF44336), // Red for Stridor
      const Color(0xFF9C27B0), // Purple for other
    ];

    return diagnosisCount.entries.map((entry) {
      final index = diagnosisCount.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        color: colors[index % colors.length],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  static List<FlSpot> getConfidenceTrend() {
    final history = HistoryService.getHistory();
    final sortedHistory = List.from(history)
      ..sort((a, b) => (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

    return sortedHistory.asMap().entries.map((entry) {
      final confidence = (entry.value['confidence'] as double?) ?? 0.0;
      return FlSpot(entry.key.toDouble(), confidence * 100); // Convert to percentage
    }).toList();
  }

  static List<BarChartGroupData> getWeeklyAnalysisData() {
    final history = HistoryService.getHistory();
    final weeklyData = <String, int>{};

    // Group by week
    for (var analysis in history) {
      final timestamp = analysis['timestamp'] as DateTime;
      final weekStart = DateTime(timestamp.year, timestamp.month, timestamp.day - timestamp.weekday + 1);
      final weekKey = DateFormat('MMM dd').format(weekStart);
      weeklyData[weekKey] = (weeklyData[weekKey] ?? 0) + 1;
    }

    return weeklyData.entries.map((entry) {
      final index = weeklyData.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.blueAccent,
            width: 20,
          ),
        ],
      );
    }).toList();
  }

  static List<Map<String, dynamic>> getFilteredHistory({
    String? searchQuery,
    String? diagnosisFilter,
    DateTime? startDate,
    DateTime? endDate,
    double? minConfidence,
    double? maxConfidence,
  }) {
    var history = HistoryService.getHistory();

    // Apply filters
    if (searchQuery != null && searchQuery.isNotEmpty) {
      history = history.where((analysis) {
        final label = (analysis['label'] ?? '').toLowerCase();
        final source = (analysis['source'] ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();
        return label.contains(query) || source.contains(query);
      }).toList();
    }

    if (diagnosisFilter != null && diagnosisFilter.isNotEmpty) {
      history = history.where((analysis) =>
        (analysis['label'] ?? '') == diagnosisFilter
      ).toList();
    }

    if (startDate != null) {
      history = history.where((analysis) =>
        (analysis['timestamp'] as DateTime).isAfter(startDate)
      ).toList();
    }

    if (endDate != null) {
      history = history.where((analysis) =>
        (analysis['timestamp'] as DateTime).isBefore(endDate.add(const Duration(days: 1)))
      ).toList();
    }

    if (minConfidence != null) {
      history = history.where((analysis) =>
        ((analysis['confidence'] as double?) ?? 0.0) >= minConfidence
      ).toList();
    }

    if (maxConfidence != null) {
      history = history.where((analysis) =>
        ((analysis['confidence'] as double?) ?? 0.0) <= maxConfidence
      ).toList();
    }

    return history;
  }

  static Map<String, dynamic> getAnalysisSummary() {
    final history = HistoryService.getHistory();

    if (history.isEmpty) {
      return {
        'totalAnalyses': 0,
        'averageConfidence': 0.0,
        'mostCommonSource': 'None',
        'bestDay': 'None',
        'improvementTrend': 'No data',
      };
    }

    // Calculate average confidence
    final averageConfidence = history.map((e) => (e['confidence'] as double?) ?? 0.0)
        .reduce((a, b) => a + b) / history.length;

    // Find most common source
    final sourceCount = <String, int>{};
    for (var analysis in history) {
      final source = analysis['source'] ?? 'Unknown';
      sourceCount[source] = (sourceCount[source] ?? 0) + 1;
    }
    final mostCommonSource = sourceCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Find best day (highest average confidence)
    final dailyConfidence = <String, List<double>>{};
    for (var analysis in history) {
      final timestamp = analysis['timestamp'] as DateTime;
      final dayKey = DateFormat('yyyy-MM-dd').format(timestamp);
      dailyConfidence.putIfAbsent(dayKey, () => []).add((analysis['confidence'] as double?) ?? 0.0);
    }

    String bestDay = 'None';
    double bestAverage = 0.0;
    dailyConfidence.forEach((day, confidences) {
      final average = confidences.reduce((a, b) => a + b) / confidences.length;
      if (average > bestAverage) {
        bestAverage = average;
        bestDay = DateFormat('MMM dd, yyyy').format(DateTime.parse(day));
      }
    });

    // Determine improvement trend
    String improvementTrend;
    if (history.length >= 2) {
      final recent = history.take(3).map((e) => (e['confidence'] as double?) ?? 0.0).toList();
      final older = history.skip(3).take(3).map((e) => (e['confidence'] as double?) ?? 0.0).toList();

      if (recent.isNotEmpty && older.isNotEmpty) {
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final olderAvg = older.reduce((a, b) => a + b) / older.length;

        if (recentAvg > olderAvg) {
          improvementTrend = 'Improving';
        } else if (recentAvg < olderAvg) {
          improvementTrend = 'Declining';
        } else {
          improvementTrend = 'Stable';
        }
      } else {
        improvementTrend = 'Insufficient data';
      }
    } else {
      improvementTrend = 'Insufficient data';
    }

    return {
      'totalAnalyses': history.length,
      'averageConfidence': averageConfidence,
      'mostCommonSource': mostCommonSource,
      'bestDay': bestDay,
      'improvementTrend': improvementTrend,
    };
  }
}
