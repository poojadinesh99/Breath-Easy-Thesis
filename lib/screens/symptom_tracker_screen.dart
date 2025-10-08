import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_auth_service.dart';

/// A refreshed, livelier take on the symptom tracker.
///
/// * Cleaner layout with ExpansionTiles per category.
/// * Severity scale for **every** symptom (0‑10) using sliders.
/// * Optional free‑form notes.
/// * Writes each selected symptom directly to the `symptoms` table.
class SymptomTrackerScreen extends StatefulWidget {
  const SymptomTrackerScreen({Key? key}) : super(key: key);

  @override
  State<SymptomTrackerScreen> createState() => _SymptomTrackerScreenState();
}

class _SymptomTrackerScreenState extends State<SymptomTrackerScreen> {
  // Service that wraps your DB layer (Supabase / Postgres etc.)
  final SupabaseAuthService _authService = SupabaseAuthService();
  final uuid = const Uuid();

  // Categorised symptoms → drives the UI
  final Map<String, List<String>> _categories = {
    '🫁 Respiratory': [
      'Cough',
      'Breathlessness',
      'Wheezing',
      'Sore Throat',
      'Runny Nose',
      'Dry Throat / Dry Mouth',
      'Hoarseness / Voice Changes',
      'Increased Mucus',
      'Rapid Breathing',
      'Bluish Lips/Fingertips',
    ],
    '🧠 Neuro / Cognitive': [
      'Fatigue',
      'Brain Fog',
      'Memory Issues',
      'Headaches',
      'Dizziness',
      'Tingling / Numbness',
      'Sleep Issues',
      'Anxiety / Depression',
      'Sensitivity to Light/Noise',
    ],
    '🫀 Systemic / Other': [
      'Fever',
      'Chest Pain',
      'Joint Pain',
      'Muscle Weakness',
      'Heart Palpitations',
      'GI Issues',
      'Skin Rashes / Discoloration',
      'Loss of Smell / Taste',
      'Menstrual Irregularities',
      'Eye Pain / Vision Changes',
      'Post‑Exertional Malaise (PEM)',
      'Other',
    ],
  };

  /// Severity for each symptom; 0 = not selected.
  final Map<String, int> _severity = {};

  final TextEditingController _notesController = TextEditingController();

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // DB write helper
  Future<void> _submit() async {
    try {
      final now = DateTime.now().toUtc();

      final user = _authService.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // Prepare symptoms list for insertSymptoms method
      List<Map<String, dynamic>> symptomsList = _severity.entries
          .where((e) => e.value > 0)
          .map((e) => {'name': e.key, 'intensity': e.value.toDouble()})
          .toList();

      await _authService.insertSymptoms(
        userId: user.id,
        symptoms: symptomsList,
        customSymptom: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('👩‍⚕️  Symptoms saved – feel better soon!')),
        );
        setState(() {
          _severity.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uh‑oh, DB error: $e')),
        );
      }
    }
  }

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // UI helpers
  Widget _symptomTile(String symptom) {
    final current = _severity[symptom] ?? 0;

    return ListTile(
      title: Text(symptom),
      subtitle: current == 0
          ? const Text('Tap + to add')
          : Slider(
              value: current.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: current.toString(),
              onChanged: (val) {
                setState(() => _severity[symptom] = val.round());
              },
            ),
      trailing: current == 0
          ? IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _severity[symptom] = 5),
            )
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _severity.remove(symptom)),
            ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Tracker'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Category cards
          ..._categories.entries.map(
            (category) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExpansionTile(
                title: Text(
                  category.key,
                  style: theme.textTheme.titleMedium,
                ),
                children: category.value.map(_symptomTile).toList(),
              ),
            ),
          ),

          // Free‑form notes
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Additional notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Submit button
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _severity.values.any((v) => v > 0) ? _submit : null,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
