import 'package:flutter/material.dart';
import '../services/recommendations_service.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationsService _recommendationsService = RecommendationsService();
  List<Recommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recommendations = await _recommendationsService.getPersonalizedRecommendations();
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshRecommendations() async {
    await _loadRecommendations();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRecommendations,
            tooltip: 'Refresh recommendations',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(theme)
              : _recommendations.isEmpty
                  ? _buildNoRecommendationsView(theme)
                  : _buildRecommendationsView(theme),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Recommendations',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecommendationsView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Recommendations Yet',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete a breath analysis to receive personalized health recommendations based on your results.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshRecommendations,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refreshRecommendations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Personalized Health Tips',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on your recent analysis results',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic Recommendations Cards
          ..._recommendations.map((recommendation) =>
              _buildRecommendationCardFromRecommendation(context, recommendation)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCardFromRecommendation(
    BuildContext context,
    Recommendation recommendation,
  ) {
    final theme = Theme.of(context);

    // Map icon string to IconData
    IconData iconData;
    switch (recommendation.icon) {
      case 'directions_walk':
        iconData = Icons.directions_walk;
        break;
      case 'waves':
        iconData = Icons.waves;
        break;
      case 'local_cafe':
        iconData = Icons.local_cafe;
        break;
      case 'bedtime':
        iconData = Icons.bedtime;
        break;
      case 'water_drop':
        iconData = Icons.water_drop;
        break;
      case 'check_circle':
        iconData = Icons.check_circle;
        break;
      case 'air':
        iconData = Icons.air;
        break;
      case 'face':
        iconData = Icons.face;
        break;
      case 'local_hospital':
        iconData = Icons.local_hospital;
        break;
      case 'healing':
        iconData = Icons.healing;
        break;
      case 'touch_app':
        iconData = Icons.touch_app;
        break;
      case 'assignment':
        iconData = Icons.assignment;
        break;
      case 'block':
        iconData = Icons.block;
        break;
      case 'medical_services':
        iconData = Icons.medical_services;
        break;
      case 'chair':
        iconData = Icons.chair;
        break;
      case 'schedule':
        iconData = Icons.schedule;
        break;
      case 'local_drink':
        iconData = Icons.local_drink;
        break;
      case 'water':
        iconData = Icons.water;
        break;
      case 'warning':
        iconData = Icons.warning;
        break;
      case 'mic':
        iconData = Icons.mic;
        break;
      case 'celebration':
        iconData = Icons.celebration;
        break;
      case 'fitness_center':
        iconData = Icons.fitness_center;
        break;
      default:
        iconData = Icons.lightbulb;
    }

    // Determine color based on category
    Color color;
    switch (recommendation.category) {
      case 'exercise':
        color = Colors.green;
        break;
      case 'breathing':
        color = Colors.blue;
        break;
      case 'nutrition':
        color = Colors.orange;
        break;
      case 'lifestyle':
        color = Colors.purple;
        break;
      case 'maintenance':
        color = Colors.teal;
        break;
      case 'prevention':
        color = Colors.indigo;
        break;
      case 'management':
        color = Colors.amber;
        break;
      case 'technique':
        color = Colors.cyan;
        break;
      case 'medical':
        color = Colors.red;
        break;
      case 'therapy':
        color = Colors.pink;
        break;
      case 'monitoring':
        color = Colors.brown;
        break;
      case 'relief':
        color = Colors.lightBlue;
        break;
      case 'soothing':
        color = Colors.lightGreen;
        break;
      case 'encouragement':
        color = Colors.deepPurple;
        break;
      default:
        color = Colors.grey;
    }

    return Column(
      children: [
        Card(
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
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        iconData,
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
                            recommendation.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            recommendation.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recommendation.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
