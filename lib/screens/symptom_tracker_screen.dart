import 'package:flutter/material.dart';
import 'package:breath_easy/services/firebase_auth_service.dart';

class SymptomTrackerScreen extends StatefulWidget {
  const SymptomTrackerScreen({super.key});

  @override
  _SymptomTrackerScreenState createState() => _SymptomTrackerScreenState();
}

class _SymptomTrackerScreenState extends State<SymptomTrackerScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();

  final Map<String, bool> _symptoms = {
    // Respiratory
    'Cough': false,
    'Breathlessness': false,
    'Wheezing': false,
    'Sore Throat': false,
    'Runny Nose': false,
    'Dry Throat / Dry Mouth': false,
    'Hoarseness / Voice Changes': false,
    'Increased Mucus': false,
    'Rapid Breathing': false,
    'Bluish Lips/Fingertips': false,

    // Neuro/Cognitive
    'Fatigue': false,
    'Brain Fog': false,
    'Memory Issues': false,
    'Headaches': false,
    'Dizziness': false,
    'Tingling / Numbness': false,
    'Sleep Issues': false,
    'Anxiety / Depression': false,
    'Sensitivity to Light/Noise': false,

    // Systemic / Other
    'Fever': false,
    'Chest Pain': false,
    'Joint Pain': false,
    'Muscle Weakness': false,
    'Heart Palpitations': false,
    'GI Issues': false,
    'Skin Rashes / Discoloration': false,
    'Loss of Smell / Taste': false,
    'Menstrual Irregularities': false,
    'Eye Pain / Vision Changes': false,

    'Post-Exertional Malaise (PEM)': false,
    'Other': false,
  };

  final Map<String, double> _intensities = {
    'Cough': 0,
    'Breathlessness': 0,
    'Fatigue': 0,
    'Chest Pain': 0,
    'Brain Fog': 0,
    'Dizziness': 0,
    'Muscle Weakness': 0,
    'GI Issues': 0,
    'Post-Exertional Malaise (PEM)': 0,
  };

  String? _otherSymptomText;

  void _submitSymptoms() async {
    try {
      // Prepare symptoms list with name and intensity
      List<Map<String, dynamic>> symptomsList = [];
      _symptoms.forEach((name, selected) {
        if (selected) {
          symptomsList.add({
            'name': name,
            'intensity': _intensities.containsKey(name) ? _intensities[name] : null,
          });
        }
      });

      final patientInfo = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (patientInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Patient info not found. Please fill patient intake form first.")),
        );
        return;
      }

      await _authService.logSession(
        patientName: patientInfo['patientName'] ?? '',
        age: patientInfo['age'] ?? 0,
        consent: patientInfo['consent'] ?? false,
        symptoms: symptomsList,
        customSymptom: _otherSymptomText,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Session data saved!")));

      // Reset the form after successful submission
      setState(() {
        _symptoms.updateAll((key, value) => false);
        _intensities.updateAll((key, value) => 0);
        _otherSymptomText = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildSection(String title, List<String> symptomKeys) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...symptomKeys.map((symptom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                title: Text(symptom),
                value: _symptoms[symptom] ?? false,
                onChanged: (bool? value) {
                  setState(() {
                    _symptoms[symptom] = value ?? false;
                  });
                },
              ),
              if ((_symptoms[symptom] ?? false) &&
                  _intensities.containsKey(symptom))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Slider(
                    value: _intensities[symptom]!,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: _intensities[symptom]!.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _intensities[symptom] = value;
                      });
                    },
                  ),
                ),
              if (symptom == 'Other' && _symptoms[symptom]!)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Describe other symptoms',
                    ),
                    onChanged: (value) => _otherSymptomText = value,
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Symptom Tracker")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSection("🫁 Respiratory Symptoms", [
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
            ]),
            _buildSection("🧠 Neurological / Cognitive Symptoms", [
              'Fatigue',
              'Brain Fog',
              'Memory Issues',
              'Headaches',
              'Dizziness',
              'Tingling / Numbness',
              'Sleep Issues',
              'Anxiety / Depression',
              'Sensitivity to Light/Noise',
            ]),
            _buildSection("🫀 Systemic / Other Symptoms", [
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
              'Post-Exertional Malaise (PEM)',
              'Other',
            ]),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitSymptoms,
              child: Text("Submit Symptoms"),
            ),
          ],
        ),
      ),
    );
  }
}
