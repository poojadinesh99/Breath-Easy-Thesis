import 'package:flutter/material.dart';
import '../widgets/api_health_badge.dart';
import '../widgets/analysis_card.dart';
import 'speech_analysis_screen.dart';
import 'breath_analysis_screen.dart';
import 'view_history_screen.dart';
import 'settings_screen.dart';

class ModernHomeScreen extends StatelessWidget {
  const ModernHomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Let\'s Check Your Health',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const ApiHealthBadge(),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Analysis Tools',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16.0,
                  crossAxisSpacing: 16.0,
                  childAspectRatio: 1.1, // Increased to give even more height
                ),
                delegate: SliverChildListDelegate([
                  AnalysisCard(
                    title: 'Breath Analysis',
                    description: 'Record and analyze your breathing pattern',
                    icon: Icons.air,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BreathAnalysisScreen()),
                    ),
                  ),
                  AnalysisCard(
                    title: 'Speech Analysis',
                    description: 'Analyze your speech patterns',
                    icon: Icons.record_voice_over,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SpeechAnalysisScreen()),
                    ),
                  ),
                  AnalysisCard(
                    title: 'History',
                    description: 'View your analysis history',
                    icon: Icons.history,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ViewHistoryScreen()),
                    ),
                  ),
                  AnalysisCard(
                    title: 'Settings',
                    description: 'Customize your experience',
                    icon: Icons.settings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
  }
}
