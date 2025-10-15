import 'package:flutter/material.dart';

class PredictionResultWidget extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onRetry;
  final bool isLoading;

  const PredictionResultWidget({
    super.key,
    required this.result,
    required this.onRetry,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final predictions = Map<String, double>.from(result['predictions'] ?? {});
    final topLabel = result['label'] as String? ?? '';
    final topConfidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final source = result['source'] as String? ?? 'unknown';
    final textSummary = result['text_summary'] as String? ?? ''; 

    // Optional: use label to pick a color vibe
    final isAbnormal = topLabel.toLowerCase() == 'abnormal';
    final accent = isAbnormal ? Colors.red : Colors.green;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analysis Result', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Top prediction highlight
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top label
                    Text(
                      'Top Prediction: $topLabel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accent.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (textSummary.isNotEmpty) ...[
                    Card(
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          textSummary,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                    // Confidence bar
                    LinearProgressIndicator(
                      value: topConfidence.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                    const SizedBox(height: 6),

                    // Confidence text
                    Text(
                      'Confidence: ${(topConfidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 14, color: accent.shade800),
                    ),

                    // 👇 New: human-friendly summary from backend
                    if (textSummary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        textSummary,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // All predictions
              Text('All Predictions:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),

              // Keep the list scrollable within the card
              Expanded(
                child: ListView.builder(
                  itemCount: predictions.length,
                  itemBuilder: (context, index) {
                    final label = predictions.keys.elementAt(index);
                    final confidence = predictions[label] ?? 0.0;
                    final barColor =
                        (label.toLowerCase() == 'abnormal') ? Colors.red : Colors.green;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(label, style: const TextStyle(fontSize: 14)),
                          ),
                          Expanded(
                            flex: 2,
                            child: LinearProgressIndicator(
                              value: confidence.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(confidence * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Text('Source: $source', style: const TextStyle(fontSize: 12, color: Colors.grey)),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Analysis'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
