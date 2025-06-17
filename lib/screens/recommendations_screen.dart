import 'package:flutter/material.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Personalized Tips')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text('🏃 10-min Walk'),
            subtitle: Text('Improves lung capacity and stamina.'),
          ),
          ListTile(
            title: Text('🫁 Breathing Exercises'),
            subtitle: Text('Try box breathing 4-4-4-4.'),
          ),
          ListTile(
            title: Text('🍵 Herbal Remedies'),
            subtitle: Text('Green tea, ginger can soothe inflammation.'),
          ),
        ],
      ),
    );
  }
}
