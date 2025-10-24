import 'package:flutter/material.dart';
import '../models/prediction_response.dart';

class AnalysisResultCard extends StatelessWidget {
  final PredictionResponse result;
  final String analysisType;
  final String? category;

  const AnalysisResultCard({
    super.key,
    required this.result,
    required this.analysisType,
    this.category,
  });

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'normal':
      case 'clear':
        return '✅ Normal';
      case 'cough':
        return '🤧 Cough Detected';
      case 'heavy_breathing':
        return '⚠️ Heavy Breathing';
      case 'throat_clearing':
        return '🗣️ Throat Clearing';
      case 'silence':
        return '🔇 Silence';
      case 'crackles':
        return '⚠️ Crackles Detected';
      case 'wheezing':
        return '⚠️ Wheezing Detected';
      case 'abnormal':
        return '⚠️ Abnormal Pattern';
      default:
        return label.toUpperCase();
    }
  }

  Widget _buildResultItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    final isNormalResult = result.label.toLowerCase() == 'normal' || result.label.toLowerCase() == 'clear';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    // Always green for normal results, confidence-based for others
                    isNormalResult ? Colors.green :
                    value >= 0.7 ? Colors.green : 
                    value >= 0.5 ? Colors.orange : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Show error state if result has error
    if (result.hasError) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Analysis Error',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.error ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with analysis type and confidence icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$analysisType Analysis Results',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if (category != null)
                        Text(
                          category!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  // Always show check circle for normal results, regardless of confidence
                  (result.label.toLowerCase() == 'normal' || result.label.toLowerCase() == 'clear')
                      ? Icons.check_circle
                      : result.confidence >= 0.7
                          ? Icons.check_circle
                          : result.confidence >= 0.5
                              ? Icons.info
                              : Icons.warning,
                  color: (result.label.toLowerCase() == 'normal' || result.label.toLowerCase() == 'clear')
                      ? Colors.green
                      : result.confidence >= 0.7
                          ? Colors.green
                          : result.confidence >= 0.5
                              ? Colors.orange
                              : Colors.red,
                  size: 32,
                ),
              ],
            ),
            const Divider(height: 32),
            
            // Main result information
            if (result.label.isNotEmpty)
              _buildResultItem(context, 'Classification', _formatLabel(result.label)),
            if (result.confidence > 0)
              _buildConfidenceBar(context, 'Confidence', result.confidence),
            if (result.textSummary.isNotEmpty)
              _buildResultItem(context, 'Summary', result.textSummary),
            
            // Display transcription for speech analysis
            if (result.transcription != null && result.transcription!.isNotEmpty)
              _buildResultItem(context, 'Transcription', '"${result.transcription!}"'),

            // Display possible conditions if available
            if (result.possibleConditions != null && result.possibleConditions!.isNotEmpty)
              _buildResultItem(context, 'Possible Conditions', result.possibleConditions!.join(', ')),
            
            // Detailed predictions
            if (result.predictions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Detailed Predictions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...result.predictions.entries.map((entry) =>
                _buildConfidenceBar(
                  context,
                  entry.key.toUpperCase(),
                  entry.value,
                ),
              ),
            ],
            
            // Processing time and source
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Processing Time: ${result.processingTime.toStringAsFixed(2)}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (result.source.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Source: ${result.source}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
