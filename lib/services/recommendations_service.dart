import 'history_service.dart';

class Recommendation {
  final String title;
  final String subtitle;
  final String description;
  final String icon;
  final String category;
  final int priority;

  Recommendation({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.category,
    required this.priority,
  });
}

class RecommendationsService {

  // Static fallback recommendations
  static final List<Recommendation> _defaultRecommendations = [
    Recommendation(
      title: 'Daily Walking',
      subtitle: 'Improves lung capacity and stamina',
      description: 'Try a 10-15 minute brisk walk daily. Fresh air helps clear airways and strengthens respiratory muscles.',
      icon: 'directions_walk',
      category: 'exercise',
      priority: 1,
    ),
    Recommendation(
      title: 'Breathing Exercises',
      subtitle: 'Enhance respiratory function',
      description: 'Practice box breathing: Inhale for 4, hold for 4, exhale for 4, hold for 4. Repeat 5-10 times.',
      icon: 'waves',
      category: 'breathing',
      priority: 1,
    ),
    Recommendation(
      title: 'Herbal Remedies',
      subtitle: 'Natural inflammation relief',
      description: 'Green tea, ginger, and honey can soothe throat irritation and reduce inflammation.',
      icon: 'local_cafe',
      category: 'nutrition',
      priority: 2,
    ),
    Recommendation(
      title: 'Quality Sleep',
      subtitle: 'Rest for recovery',
      description: 'Aim for 7-9 hours of sleep. Proper rest helps your immune system and respiratory recovery.',
      icon: 'bedtime',
      category: 'lifestyle',
      priority: 1,
    ),
    Recommendation(
      title: 'Stay Hydrated',
      subtitle: 'Keep airways moist',
      description: 'Drink 8-10 glasses of water daily. Proper hydration helps thin mucus and clear airways.',
      icon: 'water_drop',
      category: 'nutrition',
      priority: 1,
    ),
  ];

  // Personalized recommendations based on analysis patterns
  static final Map<String, List<Recommendation>> _personalizedRecommendations = {
    'normal': [
      Recommendation(
        title: 'Maintain Healthy Habits',
        subtitle: 'Your breathing is normal - keep it up!',
        description: 'Continue your current healthy breathing practices. Regular exercise and avoiding irritants will help maintain your respiratory health.',
        icon: 'check_circle',
        category: 'maintenance',
        priority: 1,
      ),
      Recommendation(
        title: 'Preventive Breathing Exercises',
        subtitle: 'Build respiratory resilience',
        description: 'Practice diaphragmatic breathing daily to strengthen your respiratory muscles and improve lung capacity.',
        icon: 'fitness_center',
        category: 'prevention',
        priority: 2,
      ),
    ],
    'wheezing': [
      Recommendation(
        title: 'Wheezing Management',
        subtitle: 'Address airway constriction',
        description: 'Use a humidifier to moisten the air and reduce wheezing. Avoid triggers like smoke, dust, and cold air.',
        icon: 'air',
        category: 'management',
        priority: 1,
      ),
      Recommendation(
        title: 'Pursed-Lip Breathing',
        subtitle: 'Control wheezing episodes',
        description: 'Practice pursed-lip breathing: Inhale through nose, exhale slowly through pursed lips. This helps control wheezing and improves breathing efficiency.',
        icon: 'face',
        category: 'technique',
        priority: 1,
      ),
      Recommendation(
        title: 'Consult Healthcare Provider',
        subtitle: 'Professional medical advice needed',
        description: 'Persistent wheezing may indicate asthma or other respiratory conditions. Schedule an appointment with your healthcare provider.',
        icon: 'local_hospital',
        category: 'medical',
        priority: 1,
      ),
    ],
    'crackles': [
      Recommendation(
        title: 'Crackle Reduction Techniques',
        subtitle: 'Clear lung secretions',
        description: 'Try controlled coughing and postural drainage to help clear mucus from your lungs. Stay well-hydrated to thin secretions.',
        icon: 'healing',
        category: 'clearance',
        priority: 1,
      ),
      Recommendation(
        title: 'Chest Physiotherapy',
        subtitle: 'Manual techniques for mucus clearance',
        description: 'Learn chest clapping and vibration techniques from a respiratory therapist to help mobilize secretions.',
        icon: 'touch_app',
        category: 'therapy',
        priority: 2,
      ),
    ],
    'abnormal': [
      Recommendation(
        title: 'Monitor Symptoms Closely',
        subtitle: 'Track your breathing patterns',
        description: 'Keep a daily log of your symptoms, breathing difficulty, and any triggers. This information will be valuable for your healthcare provider.',
        icon: 'assignment',
        category: 'monitoring',
        priority: 1,
      ),
      Recommendation(
        title: 'Avoid Respiratory Irritants',
        subtitle: 'Minimize exposure to triggers',
        description: 'Avoid smoke, strong odors, dust, and air pollution. Use air purifiers and keep your environment clean.',
        icon: 'block',
        category: 'prevention',
        priority: 1,
      ),
      Recommendation(
        title: 'Medical Evaluation',
        subtitle: 'Professional assessment recommended',
        description: 'Abnormal breathing patterns warrant medical evaluation. Consult with a pulmonologist or your primary care physician.',
        icon: 'medical_services',
        category: 'medical',
        priority: 1,
      ),
    ],
    'heavy_breathing': [
      Recommendation(
        title: 'Heavy Breathing Relief',
        subtitle: 'Reduce respiratory effort',
        description: 'Take breaks during activities, use pursed-lip breathing, and avoid overexertion. Find a comfortable position that eases breathing.',
        icon: 'chair',
        category: 'relief',
        priority: 1,
      ),
      Recommendation(
        title: 'Energy Conservation',
        subtitle: 'Manage daily activities efficiently',
        description: 'Pace yourself during activities, delegate tasks when possible, and take frequent rest breaks to conserve energy.',
        icon: 'schedule',
        category: 'management',
        priority: 2,
      ),
    ],
    'cough': [
      Recommendation(
        title: 'Cough Control Techniques',
        subtitle: 'Manage coughing episodes',
        description: 'Use honey and warm fluids to soothe your throat. Practice controlled coughing to clear airways effectively.',
        icon: 'local_drink',
        category: 'soothing',
        priority: 1,
      ),
      Recommendation(
        title: 'Humidification Therapy',
        subtitle: 'Keep airways moist',
        description: 'Use a cool-mist humidifier to add moisture to the air, which can help reduce coughing and throat irritation.',
        icon: 'water',
        category: 'therapy',
        priority: 2,
      ),
    ],
  };

  /// Analyze user's analysis history and generate personalized recommendations
  Future<List<Recommendation>> getPersonalizedRecommendations() async {
    try {
      // Fetch user's analysis history
      final history = await HistoryService.getSupabaseHistory();

      if (history.isEmpty) {
        // Return default recommendations if no analysis data
        return _defaultRecommendations;
      }

      // Analyze patterns from history
      final patterns = _analyzePatterns(history);

      // Generate personalized recommendations based on patterns
      final personalized = _generateRecommendationsFromPatterns(patterns);

      // If we have personalized recommendations, return them
      if (personalized.isNotEmpty) {
        // Sort by priority and limit to top recommendations
        personalized.sort((a, b) => a.priority.compareTo(b.priority));
        return personalized.take(5).toList();
      }

      // Fallback to default recommendations
      return _defaultRecommendations;

    } catch (e) {
      // Error logged silently in production
      // Return default recommendations on error
      return _defaultRecommendations;
    }
  }

  /// Analyze patterns from analysis history
  Map<String, dynamic> _analyzePatterns(List<Map<String, dynamic>> history) {
    final patterns = {
      'mostCommonLabel': '',
      'hasAbnormal': false,
      'recentAbnormalCount': 0,
      'averageConfidence': 0.0,
      'totalAnalyses': history.length,
      'labelCounts': <String, int>{},
    };

    double totalConfidence = 0.0;
    int recentAbnormalCount = 0;
    final recentThreshold = DateTime.now().subtract(const Duration(days: 7));

    for (final analysis in history) {
      final label = (analysis['label'] as String?)?.toLowerCase() ?? '';
      final confidence = (analysis['confidence'] as num?)?.toDouble() ?? 0.0;
      final timestamp = analysis['timestamp'] as DateTime?;

      // Count label occurrences
      final labelCounts = patterns['labelCounts'] as Map<String, int>;
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;

      // Check for abnormal patterns
      if (_isAbnormalLabel(label)) {
        patterns['hasAbnormal'] = true;
        if (timestamp != null && timestamp.isAfter(recentThreshold)) {
          recentAbnormalCount++;
        }
      }

      totalConfidence += confidence;
    }

    // Find most common label
    String mostCommonLabel = '';
    int maxCount = 0;
    (patterns['labelCounts'] as Map<String, int>).forEach((label, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonLabel = label;
      }
    });

    patterns['mostCommonLabel'] = mostCommonLabel;
    patterns['recentAbnormalCount'] = recentAbnormalCount;
    patterns['averageConfidence'] = history.isNotEmpty ? totalConfidence / history.length : 0.0;

    return patterns;
  }

  /// Check if a label indicates abnormal breathing
  bool _isAbnormalLabel(String label) {
    final abnormalLabels = ['wheezing', 'crackles', 'abnormal', 'heavy_breathing', 'cough'];
    return abnormalLabels.contains(label.toLowerCase());
  }

  /// Generate recommendations based on analyzed patterns
  List<Recommendation> _generateRecommendationsFromPatterns(Map<String, dynamic> patterns) {
    final recommendations = <Recommendation>[];

    final mostCommonLabel = patterns['mostCommonLabel'] as String;
    final hasAbnormal = patterns['hasAbnormal'] as bool;
    final recentAbnormalCount = patterns['recentAbnormalCount'] as int;
    final averageConfidence = patterns['averageConfidence'] as double;
    final totalAnalyses = patterns['totalAnalyses'] as int;

    // Add recommendations based on most common label
    if (_personalizedRecommendations.containsKey(mostCommonLabel)) {
      recommendations.addAll(_personalizedRecommendations[mostCommonLabel]!);
    }

    // Add general recommendations based on patterns
    if (hasAbnormal && recentAbnormalCount > 0) {
      recommendations.add(
        Recommendation(
          title: 'Recent Abnormal Patterns Detected',
          subtitle: 'Monitor your symptoms closely',
          description: 'You\'ve had $recentAbnormalCount abnormal analysis results in the past week. Continue monitoring and consider consulting a healthcare provider.',
          icon: 'warning',
          category: 'monitoring',
          priority: 1,
        ),
      );
    }

    // Add confidence-based recommendations
    if (averageConfidence < 0.6) {
      recommendations.add(
        Recommendation(
          title: 'Improve Recording Quality',
          subtitle: 'Get more accurate results',
          description: 'Your analysis confidence is low (${(averageConfidence * 100).toInt()}%). Try recording in a quiet environment with clear breathing sounds.',
          icon: 'mic',
          category: 'technique',
          priority: 2,
        ),
      );
    }

    // Add encouragement for consistent normal results
    if (mostCommonLabel == 'normal' && totalAnalyses > 5) {
      recommendations.add(
        Recommendation(
          title: 'Excellent Respiratory Health!',
          subtitle: 'Keep up the great work',
          description: 'Your recent analyses show consistently normal breathing patterns. Continue your healthy habits and regular monitoring.',
          icon: 'celebration',
          category: 'encouragement',
          priority: 3,
        ),
      );
    }

    return recommendations;
  }

  /// Get default recommendations (fallback)
  List<Recommendation> getDefaultRecommendations() {
    return _defaultRecommendations;
  }
}
