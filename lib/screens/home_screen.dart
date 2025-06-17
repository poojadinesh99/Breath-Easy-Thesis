import 'package:flutter/material.dart';
import 'package:breath_easy/screens/symptom_history_screen.dart';
import 'package:breath_easy/screens/patient_profile_screen.dart';
import 'breath_analysis_screen.dart';
import 'ai_alerts_screen.dart';
import 'recommendations_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respiratory Health Tracker'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildFeatureButton(
              context,
              'Patient Profile',
              Icons.medical_services,
              PatientProfileScreen(),
            ),
            _buildFeatureButton(
              context,
              'Symptoms History',
              Icons.history,
              SymptomHistoryScreen(),
            ),
            _buildFeatureButton(
              context,
              'Breath Analysis',
              Icons.air,
              BreathAnalysisScreen(),
            ),
            _buildFeatureButton(
              context,
              'AI Alerts',
              Icons.notifications,
              AIAlertsScreen(),
            ),
            _buildFeatureButton(
              context,
              'Recommendations',
              Icons.recommend,
              RecommendationsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton(
    BuildContext context,
    String title,
    IconData icon,
    Widget screen,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
