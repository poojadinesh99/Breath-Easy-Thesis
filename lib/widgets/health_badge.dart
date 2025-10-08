import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/backend_config.dart';

class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key});

  Future<Map<String, dynamic>> _fetch() async {
    final res = await Dio().get('${BackendConfig.base}/health');
    return Map<String, dynamic>.from(res.data as Map);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetch(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final d = snap.data!;
        final local = d['local_model_available'] == true ? 'Local' : 'Remote';
        final labels = (d['labels'] is Map ? (d['labels'] as Map).values.join(', ') : '');
        final version = d['model_version'] ?? 'unknown';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueGrey[200]!),
          ),
          child: Text('Model $version • $local • Classes: $labels',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        );
      },
    );
  }
}
