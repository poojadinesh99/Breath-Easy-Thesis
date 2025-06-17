import 'package:flutter/material.dart';

class AIAlertsScreen extends StatelessWidget {
  const AIAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Alerts')),
      body: Center(
        child: Text(
          '🚨 No critical alerts at the moment.',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      ),
    );
  }
}
