import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/analytics_service.dart';
import '../services/history_service.dart';

class SimpleExportService {
  static Future<void> exportHealthReport({
    required BuildContext context,
    String format = 'txt',
  }) async {
    try {
      final reportData = _generateHealthReportData();

      if (format == 'txt') {
        await _exportAsText(context, reportData);
      } else if (format == 'csv') {
        await _exportAsCSV(context, reportData);
      } else if (format == 'json') {
        await _exportAsJSON(context, reportData);
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Export failed: $e');
    }
  }

  static Map<String, dynamic> _generateHealthReportData() {
    final history = HistoryService.getHistory();
    final overview = AnalyticsService.getHealthOverview();
    final summary = AnalyticsService.getAnalysisSummary();

    return {
      'generatedAt': DateTime.now(),
      'reportPeriod': {
        'start': history.isEmpty ? null : history.last['timestamp'],
        'end': history.isEmpty ? null : history.first['timestamp'],
      },
      'overview': overview,
      'summary': summary,
      'history': history,
      'analysis': {
        'totalAnalyses': history.length,
        'dateRange': history.isEmpty ? 'No data' :
          '${DateFormat('MMM dd, yyyy').format(history.last['timestamp'])} - ${DateFormat('MMM dd, yyyy').format(history.first['timestamp'])}',
        'mostCommonDiagnosis': overview['mostCommonDiagnosis'],
        'averageConfidence': '${(overview['averageConfidence'] * 100).toStringAsFixed(1)}%',
      },
    };
  }

  static Future<void> _exportAsText(BuildContext context, Map<String, dynamic> reportData) async {
    try {
      final textContent = _generateTextContent(reportData);
      final fileName = 'health_report_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.txt';
      final file = await _saveFile(fileName, textContent);

      if (file != null) {
        _showSuccessSnackBar(context, 'Text report exported successfully');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Text export failed: $e');
    }
  }

  static Future<void> _exportAsCSV(BuildContext context, Map<String, dynamic> reportData) async {
    try {
      final csvContent = _generateCSVContent(reportData);
      final fileName = 'health_data_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.csv';
      final file = await _saveFile(fileName, csvContent);

      if (file != null) {
        _showSuccessSnackBar(context, 'CSV data exported successfully');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'CSV export failed: $e');
    }
  }

  static Future<void> _exportAsJSON(BuildContext context, Map<String, dynamic> reportData) async {
    try {
      final jsonContent = _generateJSONContent(reportData);
      final fileName = 'health_data_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.json';
      final file = await _saveFile(fileName, jsonContent);

      if (file != null) {
        _showSuccessSnackBar(context, 'JSON data exported successfully');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'JSON export failed: $e');
    }
  }

  static String _generateTextContent(Map<String, dynamic> reportData) {
    final buffer = StringBuffer();

    buffer.writeln('=' * 60);
    buffer.writeln('           BREATH EASY - HEALTH REPORT');
    buffer.writeln('=' * 60);
    buffer.writeln('Generated on: ${DateFormat('EEEE, MMMM dd, yyyy HH:mm').format(reportData['generatedAt'])}');
    buffer.writeln('');

    // Report Period
    final period = reportData['reportPeriod'];
    if (period['start'] != null && period['end'] != null) {
      buffer.writeln('Report Period:');
      buffer.writeln('  From: ${DateFormat('MMM dd, yyyy').format(period['start'])}');
      buffer.writeln('  To:   ${DateFormat('MMM dd, yyyy').format(period['end'])}');
      buffer.writeln('');
    }

    // Overview Section
    buffer.writeln('HEALTH OVERVIEW');
    buffer.writeln('-' * 30);
    final overview = reportData['overview'];
    buffer.writeln('Total Analyses: ${overview['totalAnalyses']}');
    buffer.writeln('Clear Results: ${overview['clearResults']} (${overview['clearPercentage'].toStringAsFixed(1)}%)');
    buffer.writeln('Alert Results: ${overview['alertResults']} (${overview['alertPercentage'].toStringAsFixed(1)}%)');
    buffer.writeln('Average Confidence: ${(overview['averageConfidence'] * 100).toStringAsFixed(1)}%');
    buffer.writeln('Most Common Diagnosis: ${overview['mostCommonDiagnosis']}');
    buffer.writeln('');

    // Summary Section
    buffer.writeln('ANALYSIS SUMMARY');
    buffer.writeln('-' * 30);
    final summary = reportData['summary'];
    buffer.writeln('Total Analyses: ${summary['totalAnalyses']}');
    buffer.writeln('Average Confidence: ${(summary['averageConfidence'] * 100).toStringAsFixed(1)}%');
    buffer.writeln('Most Common Source: ${summary['mostCommonSource']}');
    buffer.writeln('Best Performance Day: ${summary['bestDay']}');
    buffer.writeln('Improvement Trend: ${summary['improvementTrend']}');
    buffer.writeln('');

    // Detailed History
    buffer.writeln('DETAILED ANALYSIS HISTORY');
    buffer.writeln('-' * 30);
    final history = reportData['history'];
    for (var i = 0; i < history.length; i++) {
      final analysis = history[i];
      buffer.writeln('${i + 1}. ${DateFormat('MMM dd, yyyy HH:mm').format(analysis['timestamp'])}');
      buffer.writeln('   Diagnosis: ${analysis['label']}');
      buffer.writeln('   Confidence: ${(analysis['confidence'] * 100).toStringAsFixed(1)}%');
      buffer.writeln('   Source: ${analysis['source']}');

      if (analysis['predictions'] != null) {
        buffer.writeln('   Predictions:');
        analysis['predictions'].forEach((key, value) {
          buffer.writeln('     - $key: ${(value * 100).toStringAsFixed(1)}%');
        });
      }
      buffer.writeln('');
    }

    buffer.writeln('RECOMMENDATIONS');
    buffer.writeln('-' * 30);
    buffer.writeln('• Continue regular monitoring to track your respiratory health progress.');
    buffer.writeln('• Consider consulting a healthcare provider if you notice any concerning patterns.');
    buffer.writeln('• Your analysis data has been recorded and can be reviewed by medical professionals.');
    buffer.writeln('• Maintain consistent analysis routines for better health insights.');
    buffer.writeln('');

    buffer.writeln('=' * 60);
    buffer.writeln('End of Report');
    buffer.writeln('=' * 60);

    return buffer.toString();
  }

  static String _generateCSVContent(Map<String, dynamic> reportData) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Date,Diagnosis,Confidence,Source,Predictions');

    // Data rows
    final history = reportData['history'];
    for (var analysis in history) {
      final predictions = analysis['predictions'] != null
          ? analysis['predictions'].entries.map((e) => '${e.key}:${(e.value * 100).toStringAsFixed(1)}%').join(';')
          : '';

      buffer.writeln([
        DateFormat('yyyy-MM-dd HH:mm:ss').format(analysis['timestamp']),
        analysis['label'],
        (analysis['confidence'] * 100).toStringAsFixed(1),
        analysis['source'],
        predictions,
      ].join(','));
    }

    return buffer.toString();
  }

  static String _generateJSONContent(Map<String, dynamic> reportData) {
    // Simple JSON-like formatting
    final buffer = StringBuffer();
    buffer.writeln('{');
    buffer.writeln('  "generatedAt": "${reportData['generatedAt'].toIso8601String()}",');
    buffer.writeln('  "overview": {');
    final overview = reportData['overview'];
    buffer.writeln('    "totalAnalyses": ${overview['totalAnalyses']},');
    buffer.writeln('    "clearResults": ${overview['clearResults']},');
    buffer.writeln('    "averageConfidence": ${overview['averageConfidence']}');
    buffer.writeln('  },');
    buffer.writeln('  "summary": {');
    final summary = reportData['summary'];
    buffer.writeln('    "improvementTrend": "${summary['improvementTrend']}"');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  static Future<File?> _saveFile(String fileName, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      return file;
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static List<String> getAvailableFormats() {
    return ['Text Report', 'CSV Data', 'JSON Data'];
  }

  static String getFormatDescription(String format) {
    switch (format) {
      case 'Text Report':
        return 'Formatted health report with charts and summaries';
      case 'CSV Data':
        return 'Raw data export for spreadsheet analysis';
      case 'JSON Data':
        return 'Structured data for developers and APIs';
      default:
        return 'Export format';
    }
  }
}
