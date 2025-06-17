

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientIntakeFormScreen extends StatefulWidget {
  const PatientIntakeFormScreen({super.key});

  @override
  _PatientIntakeFormScreenState createState() =>
      _PatientIntakeFormScreenState();
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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        await FirebaseFirestore.instance.collection('patients').add({
          'name': _name,
          'age': int.tryParse(_age) ?? 0,
          'contactNumber': _contactNumber,
          'consentGiven': _consentGiven,
          'hasPreviousConditions': _hasPreviousConditions,
          'isSmoker': _isSmoker,
          'hasRespiratoryDiseaseHistory': _hasRespiratoryDiseaseHistory,
          'exposedToCovid': _exposedToCovid,
          'vaccinated': _vaccinated,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient Intake Form for $_name submitted successfully',
            ),
          ),
        );

        _resetForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit form: $e'),
          ),
        );
      }
    }
  }

  void _navigateToSymptomTracker() {
    if (_name.isEmpty || _age.isEmpty || !_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete the patient intake form first.')),
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
      appBar: AppBar(title: Text('Patient Intake Form')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
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
                decoration: InputDecoration(
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
                decoration: InputDecoration(
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
                title: Text('I consent to treatment'),
                value: _consentGiven,
                onChanged: (bool? value) {
                  setState(() {
                    _consentGiven = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('I have previous medical conditions'),
                value: _hasPreviousConditions,
                onChanged: (bool? value) {
                  setState(() {
                    _hasPreviousConditions = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('I am a smoker'),
                value: _isSmoker,
                onChanged: (bool? value) {
                  setState(() {
                    _isSmoker = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('History of respiratory diseases'),
                value: _hasRespiratoryDiseaseHistory,
                onChanged: (bool? value) {
                  setState(() {
                    _hasRespiratoryDiseaseHistory = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('Exposed to COVID-19'),
                value: _exposedToCovid,
                onChanged: (bool? value) {
                  setState(() {
                    _exposedToCovid = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('Vaccinated for COVID-19'),
                value: _vaccinated,
                onChanged: (bool? value) {
                  setState(() {
                    _vaccinated = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submitForm, child: Text('Submit')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToSymptomTracker,
                child: Text('Go to Symptom Tracker'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
