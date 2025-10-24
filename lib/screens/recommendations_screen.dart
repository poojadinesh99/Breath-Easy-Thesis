import 'package:flutter/material.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    // Show welcome message after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeMessage();
    });
  }

  void _showWelcomeMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text('💡 Personalized tips based on your health data!'),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blue.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Recommendations'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3), // Fixed compatibility
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(height: 8),
                Text(
                  'Personalized Health Tips',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Based on your recent analysis results',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7), // Fixed compatibility
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Recommendations Cards
          _buildRecommendationCard(
            context,
            icon: Icons.directions_walk,
            title: 'Daily Walking',
            subtitle: 'Improves lung capacity and stamina',
            description: 'Try a 10-15 minute brisk walk daily. Fresh air helps clear airways and strengthens respiratory muscles.',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          
          _buildRecommendationCard(
            context,
            icon: Icons.waves, // Wave icon represents breathing rhythm
            title: 'Breathing Exercises',
            subtitle: 'Enhance respiratory function',
            description: 'Practice box breathing: Inhale for 4, hold for 4, exhale for 4, hold for 4. Repeat 5-10 times.',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          
          _buildRecommendationCard(
            context,
            icon: Icons.local_cafe,
            title: 'Herbal Remedies',
            subtitle: 'Natural inflammation relief',
            description: 'Green tea, ginger, and honey can soothe throat irritation and reduce inflammation.',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          
          _buildRecommendationCard(
            context,
            icon: Icons.bedtime,
            title: 'Quality Sleep',
            subtitle: 'Rest for recovery',
            description: 'Aim for 7-9 hours of sleep. Proper rest helps your immune system and respiratory recovery.',
            color: Colors.purple,
          ),
          const SizedBox(height: 12),
          
          _buildRecommendationCard(
            context,
            icon: Icons.water_drop,
            title: ' Stay Hydrated',
            subtitle: 'Keep airways moist',
            description: 'Drink 8-10 glasses of water daily. Proper hydration helps thin mucus and clear airways.',
            color: Colors.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1), // Fixed compatibility issue
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6), // Fixed compatibility
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
