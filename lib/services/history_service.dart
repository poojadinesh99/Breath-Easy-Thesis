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
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        await supabase.from('analysis_history').insert({
          'user_id': user.id,
          'analysis_type': entry['source'] ?? 'monitoring',
          'label': entry['label'] ?? 'Unknown',
          'confidence': (entry['confidence'] ?? 0.0).toDouble(),
          'source': entry['source'] ?? 'monitoring',
          'predictions': entry['predictions'] ?? {},
          'raw_response': entry['raw_response'] ?? {},
          'transcript': entry['transcript'] ?? '',
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
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        final data = await supabase
            .from('analysis_history')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(50);
        
        // Convert to expected format
        return data.map<Map<String, dynamic>>((item) => {
          'label': item['label'] ?? 'Unknown',
          'confidence': (item['confidence'] ?? 0.0).toDouble(),
          'source': item['source'] ?? 'Unknown',
          'timestamp': DateTime.parse(item['created_at']),
          'predictions': item['predictions'] ?? {},
        }).toList();
      }
    } catch (e) {
      print('Failed to load history from Supabase: $e');
    }
    
    // Fallback to local history
    return _localHistory;
  }
}
