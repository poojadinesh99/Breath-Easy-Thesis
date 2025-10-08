import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientIntakeFormScreen extends StatefulWidget {
  const PatientIntakeFormScreen({super.key});

  @override
  _PatientIntakeFormScreenState createState() => _PatientIntakeFormScreenState();
}

class _PatientIntakeFormScreenState extends State<PatientIntakeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _age = '';
  String _contactNumber = '';
  bool _consentGiven = false;
  bool _hasPreviousConditions = false;

  // Additional fields for respiratory disease monitoring
  bool _isSmoker = false;
  bool _hasRespiratoryDiseaseHistory = false;
  bool _exposedToCovid = false;
  bool _vaccinated = false;

  bool _isSubmitting = false;

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _consentGiven = false;
      _hasPreviousConditions = false;
      _isSmoker = false;
      _hasRespiratoryDiseaseHistory = false;
      _exposedToCovid = false;
      _vaccinated = false;
      _name = '';
      _age = '';
      _contactNumber = '';
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.from('patients').insert({
        'user_id': user.id,
        'name': _name,
        'age': int.tryParse(_age) ?? 0,
        'contact_number': _contactNumber,
        'consent_given': _consentGiven,
        'has_previous_conditions': _hasPreviousConditions,
        'is_smoker': _isSmoker,
        'has_respiratory_disease_history': _hasRespiratoryDiseaseHistory,
        'exposed_to_covid': _exposedToCovid,
        'vaccinated': _vaccinated,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient Intake Form for $_name submitted successfully')),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit form: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _navigateToSymptomTracker() {
    if (_name.isEmpty || _age.isEmpty || !_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the patient intake form first.')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/symptom_tracker',
      arguments: {
        'patientName': _name,
        'age': int.tryParse(_age) ?? 0,
        'consent': _consentGiven,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Intake Form')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age <= 0) {
                    return 'Please enter a valid age';
                  }
                  return null;
                },
                onSaved: (value) => _age = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your contact number';
                  }
                  return null;
                },
                onSaved: (value) => _contactNumber = value!.trim(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('I consent to treatment'),
                value: _consentGiven,
                onChanged: (bool? value) {
                  setState(() { _consentGiven = value ?? false; });
                },
              ),
              CheckboxListTile(
                title: const Text('I have previous medical conditions'),
                value: _hasPreviousConditions,
                onChanged: (bool? value) {
                  setState(() { _hasPreviousConditions = value ?? false; });
                },
              ),
              CheckboxListTile(
                title: const Text('I am a smoker'),
                value: _isSmoker,
                onChanged: (bool? value) {
                  setState(() { _isSmoker = value ?? false; });
                },
              ),
              CheckboxListTile(
                title: const Text('History of respiratory diseases'),
                value: _hasRespiratoryDiseaseHistory,
                onChanged: (bool? value) {
                  setState(() { _hasRespiratoryDiseaseHistory = value ?? false; });
                },
              ),
              CheckboxListTile(
                title: const Text('Exposed to COVID-19'),
                value: _exposedToCovid,
                onChanged: (bool? value) {
                  setState(() { _exposedToCovid = value ?? false; });
                },
              ),
              CheckboxListTile(
                title: const Text('Vaccinated for COVID-19'),
                value: _vaccinated,
                onChanged: (bool? value) {
                  setState(() { _vaccinated = value ?? false; });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToSymptomTracker,
                  child: const Text('Go to Symptom Tracker'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
