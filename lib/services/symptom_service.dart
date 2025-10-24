import 'package:supabase_flutter/supabase_flutter.dart';

class SymptomService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> addSymptom({
    required String symptomType,
    int? severity,
    String? notes,
  }) async {
    await _client.from('symptoms').insert({
      'symptom_type': symptomType,
      if (severity != null) 'severity': severity,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      // logged_at defaults to now() in DB
    });
  }

  Future<List<Map<String, dynamic>>> listRecent({int limit = 50}) async {
    final data = await _client
        .from('symptoms')
        .select('id, symptom_type, severity, notes, logged_at')
        .order('logged_at', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }
}

