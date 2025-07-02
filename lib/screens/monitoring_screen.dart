import 'package:flutter/material.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Monitoring',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This screen will display live breath and speech analysis data, alerts, and trends.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bubble_chart),
                title: const Text('Breath Analysis Status'),
                subtitle: const Text('No data available yet.'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: const Text('Speech Analysis Status'),
                subtitle: const Text('No data available yet.'),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement live monitoring start/stop
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Start Monitoring functionality not implemented yet.')),
                );
              },
              child: const Text('Start Monitoring'),
            ),
          ],
        ),
      ),
    );
  }
}
