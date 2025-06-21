import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import '../features/exercises/presentation/exercises_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Private method to get dynamic greeting based on current time
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Breatheasy Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              // Call sign out and navigate to splash screen
              try {
                await SupabaseAuthService().signOut();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/splash',
                  (Route<dynamic> route) => false,
                );
              } catch (e) {
                // Handle sign out error if needed
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign out failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, Patient!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Your health at a glance",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                  context,
                  title: 'Breath Analysis',
                  status: 'Breathing patterns normal',
                  buttonText: 'View Details',
                  onPressed: () {
                    // Navigate to breath analysis details
                    // TODO: Implement navigation to breath analysis details screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigate to Breath Analysis Details')),
                    );
                  },
                  icon: Icons.air,
                  color: Colors.blueAccent,
                ),
                _buildSummaryCard(
                  context,
                  title: 'Speech Analysis',
                  status: 'Speech normal',
                  buttonText: 'View Details',
                  onPressed: () {
                    // Navigate to speech analysis details
                    // TODO: Implement navigation to speech analysis details screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigate to Speech Analysis Details')),
                    );
                  },
                  icon: Icons.record_voice_over,
                  color: Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Alerts Section
            const Text(
              'Alerts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildAlertCard(
              context,
              message: 'No anomalies detected',
              isAlert: false,
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  icon: Icons.play_arrow,
                  label: 'Start Monitoring',
                  onPressed: () {
                    // Start live monitoring
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Start Monitoring pressed')),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  icon: Icons.history,
                  label: 'View History',
                  onPressed: () {
                    // View history
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('View History pressed')),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  icon: Icons.fitness_center,
                  label: 'Exercises',
                  onPressed: () {
                    // Navigate to exercises
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ExercisesScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String status,
    required String buttonText,
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context,
      {required String message, required bool isAlert}) {
    return Card(
      color: isAlert ? Colors.redAccent : Colors.greenAccent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isAlert ? Icons.warning : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
