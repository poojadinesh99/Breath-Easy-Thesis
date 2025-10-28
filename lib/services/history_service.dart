import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryService {
  // Sample data for offline mode
  static final List<Map<String, dynamic>> _localHistory = [
    {
      'label': 'Clear',
      'confidence': 0.95,
      'source': 'Breath Analysis',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'predictions': {
        'Clear': 0.95,
        'Wheezing': 0.03,
        'Crackles': 0.02,
      },
    },
    {
      'label': 'Wheezing',
      'confidence': 0.87,
      'source': 'Speech Analysis',
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
      'predictions': {
        'Wheezing': 0.87,
        'Clear': 0.10,
        'Stridor': 0.03,
      },
    },
    {
      'label': 'Clear',
      'confidence': 0.92,
      'source': 'Breath Analysis',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'predictions': {
        'Clear': 0.92,
        'Wheezing': 0.05,
        'Crackles': 0.03,
      },
    },
    {
      'label': 'Crackles',
      'confidence': 0.78,
      'source': 'Demo Analysis',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      'predictions': {
        'Crackles': 0.78,
        'Clear': 0.15,
        'Wheezing': 0.07,
      },
    },
  ];

  static Future<void> addEntry(Map<String, dynamic> entry) async {
    // Add to local history first
    _localHistory.insert(0, entry);
    
    // Try to save to Supabase
    try {
      final supabase = Supabase.instance.client;
      var user = supabase.auth.currentUser;
      
      // For testing: create anonymous user if none exists (but handle disabled anonymous auth)
      if (user == null) {
        try {
          final response = await supabase.auth.signInAnonymously();
          user = response.user;
          print('Created anonymous user for history: ${user?.id}');
        } catch (e) {
          print('Failed to create anonymous user for history: $e');
          print('Anonymous authentication is disabled - skipping cloud save, using local storage only');
          return; // Skip saving to Supabase if can't authenticate, but keep local history
        }
      }
      
      if (user != null) {
        await supabase.from('analysis_history').insert({
          'user_id': user.id,
          'analysis_type': entry['source'] == 'Speech Analysis' ? 'speech' : 'unified',
          'predicted_label': entry['label'] ?? 'Unknown',  // Match actual schema
          'confidence': (entry['confidence'] ?? 0.0).toDouble(),
          'file_name': entry['file_name'],  // Remove unnecessary ?? null
          'extra': entry['predictions'] ?? {},  // Match actual schema (extra instead of predictions)
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Entry saved to Supabase: ${entry['label']}');
      }
    } catch (e) {
      print('Failed to save entry to Supabase: $e');
      // Continue with local storage only
    }
  }

  static List<Map<String, dynamic>> getLocalHistory() {
    return _localHistory;
  }

  // Backward compatibility - returns local history synchronously
  static List<Map<String, dynamic>> getHistory() {
    return _localHistory;
  }

  // New async method to get history from Supabase
  static Future<List<Map<String, dynamic>>> getSupabaseHistory() async {
    try {
      final supabase = Supabase.instance.client;
      var user = supabase.auth.currentUser;

      // For testing: create anonymous user if none exists (but handle disabled anonymous auth)
      if (user == null) {
        try {
          final response = await supabase.auth.signInAnonymously();
          user = response.user;
          print('Created anonymous user for history retrieval: ${user?.id}');
        } catch (e) {
          print('Failed to create anonymous user for history retrieval: $e');
          print('Anonymous authentication is disabled - returning all history (no user filter)');
          // Return all history without user filter when auth is disabled
          final data = await supabase
              .from('analysis_history')
              .select()
              .order('created_at', ascending: false)
              .limit(50);

          print('Loaded ${data.length} real analysis entries from Supabase (no user filter)');

          // Convert to expected format with detailed information from extra field
          final realData = data.map<Map<String, dynamic>>((item) => {
            'label': item['predicted_label'] ?? 'Unknown',
            'confidence': (item['confidence'] ?? 0.0).toDouble(),
            'source': item['analysis_type'] == 'speech' ? 'Speech Analysis' : 'Breath Analysis',
            'timestamp': DateTime.parse(item['created_at']),
            'predictions': item['extra']?['predictions'] ?? {},
            'isReal': true,
            // Add detailed information from extra field
            'possible_conditions': item['extra']?['possible_conditions'] ?? [],
            'verdict': item['extra']?['verdict'] ?? '',
            'simplified_label': item['extra']?['simplified_label'] ?? '',
            'acoustic_features': item['extra']?['acoustic_features'] ?? {},
            'text_summary': item['extra']?['text_summary'] ?? '',
            'transcription': item['extra']?['transcription'] ?? '',
            'processing_time': item['extra']?['processing_time'] ?? 0.0,
            'model_version': item['extra']?['model_version'] ?? '1.0.0',
          }).toList();

          return realData;
        }
      }

      if (user != null) {
        final data = await supabase
            .from('analysis_history')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(50);

        print('Loaded ${data.length} real analysis entries from Supabase');

        // Convert to expected format with detailed information from extra field
        final realData = data.map<Map<String, dynamic>>((item) => {
          'label': item['predicted_label'] ?? 'Unknown',
          'confidence': (item['confidence'] ?? 0.0).toDouble(),
          'source': item['analysis_type'] == 'speech' ? 'Speech Analysis' : 'Breath Analysis',
          'timestamp': DateTime.parse(item['created_at']),
          'predictions': item['extra']?['predictions'] ?? {},
          'isReal': true,
          // Add detailed information from extra field
          'possible_conditions': item['extra']?['possible_conditions'] ?? [],
          'verdict': item['extra']?['verdict'] ?? '',
          'simplified_label': item['extra']?['simplified_label'] ?? '',
          'acoustic_features': item['extra']?['acoustic_features'] ?? {},
          'text_summary': item['extra']?['text_summary'] ?? '',
          'transcription': item['extra']?['transcription'] ?? '',
          'processing_time': item['extra']?['processing_time'] ?? 0.0,
          'model_version': item['extra']?['model_version'] ?? '1.0.0',
        }).toList();

        // Return real data if available
        if (realData.isNotEmpty) {
          return realData;
        }
      }
    } catch (e) {
      print('Failed to load history from Supabase: $e');
    }

    // Return empty list instead of sample data to show "No analyses found"
    print('No real analysis data found - returning empty list');
    return [];
  }
}
