import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/unified_service.dart';

class SymptomTrackerScreen extends StatefulWidget {
  const SymptomTrackerScreen({super.key});

  @override
  State<SymptomTrackerScreen> createState() => _SymptomTrackerScreenState();
}

class _SymptomTrackerScreenState extends State<SymptomTrackerScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;

  // Categorised symptoms → drives the UI
  final Map<String, List<String>> _categories = {
    'Respiratory': [
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
    'Neuro / Cognitive': [
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
    'Systemic / Other': [
      'Fever',
      'Chest Pain',
      'Muscle/Joint Pain',
      'Nausea',
      'Loss of Appetite',
      'Weight Changes',
      'Rash/Skin Issues',
      'Night Sweats',
      'General Weakness',
    ],
  };

  // Track severity for each symptom
  final Map<String, double> _severities = {};
  final Map<String, bool> _selectedSymptoms = {};
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize severities to 5.0 (middle value)
    for (final category in _categories.entries) {
      for (final symptom in category.value) {
        _severities[symptom] = 5.0;
        _selectedSymptoms[symptom] = false;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitSymptoms() async {
    final selectedSymptoms = _selectedSymptoms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one symptom'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Log each selected symptom
      for (final symptom in selectedSymptoms) {
        await _supabase.from('symptoms').insert({
          'user_id': user.id,
          'symptom_type': symptom.toLowerCase(),
          'severity': _severities[symptom]!.round(),
          'notes': _notesController.text.trim(),
        });
      }

      if (!mounted) return;

      // Clear selections after successful submission
      setState(() {
        for (final symptom in _selectedSymptoms.keys) {
          _selectedSymptoms[symptom] = false;
          _severities[symptom] = 5.0;
        }
        _notesController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Symptoms logged successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging symptoms: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Tracker'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red[100],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  Text(
                    'Select Symptoms',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ..._categories.entries.map((category) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text(category.key),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: category.value.map((symptom) {
                                return Column(
                                  children: [
                                    CheckboxListTile(
                                      title: Text(symptom),
                                      value: _selectedSymptoms[symptom],
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _selectedSymptoms[symptom] = value ?? false;
                                        });
                                      },
                                    ),
                                    if (_selectedSymptoms[symptom] == true)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('Severity:'),
                                                Text(
                                                  _severities[symptom]!.round().toString(),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                            Slider(
                                              value: _severities[symptom]!,
                                              min: 1,
                                              max: 10,
                                              divisions: 9,
                                              onChanged: (value) {
                                                setState(() {
                                                  _severities[symptom] = value;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    const Divider(),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitSymptoms,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(_isLoading ? 'Submitting...' : 'Submit'),
                  ),
                ],
              ),
            ),
    );
  }
}
