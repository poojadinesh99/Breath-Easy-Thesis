 import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientIntakeFormScreen extends StatefulWidget {
  const PatientIntakeFormScreen({super.key});

  @override
  State<PatientIntakeFormScreen> createState() => _PatientIntakeFormScreenState();
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

    setState(() => _isSubmitting = true);
    
    try {
      var user = Supabase.instance.client.auth.currentUser;
      
      // For testing purposes: create an anonymous session if no user is logged in
      if (user == null) {
        try {
          final response = await Supabase.instance.client.auth.signInAnonymously();
          user = response.user;
          print('Created anonymous user for patient intake: ${user?.id}');
        } catch (e) {
          print('Failed to create anonymous user: $e');
          // Navigate to authentication screen
          if (mounted) {
            print('Showing authentication dialog...');
            final shouldAuth = await showDialog<bool>(
              context: context,
              barrierDismissible: false, // Force user to make a choice
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Authentication Required'),
                  ],
                ),
                content: const Text(
                  'Anonymous authentication is disabled. To save your patient data securely, please authenticate with an email account.',
                  style: TextStyle(fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                      print('User cancelled authentication');
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      print('User chose to authenticate');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Authenticate'),
                  ),
                ],
              ),
            );
            
            print('Dialog result: $shouldAuth');
            
            if (shouldAuth == true) {
              print('Navigating to auth screen...');
              final authResult = await Navigator.pushNamed(context, '/simple_auth');
              print('Auth screen result: $authResult');
              
              // Wait a moment for auth to complete
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Try to get user again after auth
              user = Supabase.instance.client.auth.currentUser;
              print('User after auth: ${user?.id}');
              
              if (user == null) {
                print('Still no user after auth attempt - trying to refresh session');
                // Try to refresh the session
                try {
                  await Supabase.instance.client.auth.refreshSession();
                  user = Supabase.instance.client.auth.currentUser;
                  print('User after session refresh: ${user?.id}');
                } catch (refreshError) {
                  print('Session refresh failed: $refreshError');
                }
              }
            }
            
            if (user == null) {
              print('Still no user after auth attempt');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Authentication failed. Please try signing up or signing in manually from the Auth screen.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              return;
            }
          }
        }
      }

      // Ensure we have a valid user before proceeding
      if (user?.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Use the authenticated user ID (this ensures the foreign key constraint is satisfied)
      final userId = user!.id;

      await Supabase.instance.client.from('patients').insert({
        'user_id': userId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Intake Form'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.medical_information,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome to Breath Easy',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please fill out this form to help us provide you with the best respiratory health monitoring.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Personal Information Section
                _buildSectionCard(
                  'Personal Information',
                  Icons.person,
                  [
                    _buildTextFormField(
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                      onSaved: (value) => _name = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      label: 'Age',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your age';
                        }
                        final age = int.tryParse(value.trim());
                        if (age == null || age < 1 || age > 120) {
                          return 'Please enter a valid age (1-120)';
                        }
                        return null;
                      },
                      onSaved: (value) => _age = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      label: 'Contact Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your contact number';
                        }
                        return null;
                      },
                      onSaved: (value) => _contactNumber = value?.trim() ?? '',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Health Information Section
                _buildSectionCard(
                  'Health Information',
                  Icons.local_hospital,
                  [
                    _buildSwitchTile(
                      'Do you smoke or have a history of smoking?',
                      Icons.smoking_rooms,
                      _isSmoker,
                      (value) => setState(() => _isSmoker = value),
                    ),
                    _buildSwitchTile(
                      'Do you have any respiratory disease history?',
                      Icons.air,
                      _hasRespiratoryDiseaseHistory,
                      (value) => setState(() => _hasRespiratoryDiseaseHistory = value),
                    ),
                    _buildSwitchTile(
                      'Have you been exposed to COVID-19?',
                      Icons.coronavirus,
                      _exposedToCovid,
                      (value) => setState(() => _exposedToCovid = value),
                    ),
                    _buildSwitchTile(
                      'Are you vaccinated against COVID-19?',
                      Icons.vaccines,
                      _vaccinated,
                      (value) => setState(() => _vaccinated = value),
                    ),
                    _buildSwitchTile(
                      'Do you have any previous medical conditions?',
                      Icons.medical_services,
                      _hasPreviousConditions,
                      (value) => setState(() => _hasPreviousConditions = value),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Consent Section
                _buildSectionCard(
                  'Consent & Privacy',
                  Icons.privacy_tip,
                  [
                    _buildConsentTile(),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Form'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitForm,
                        icon: _isSubmitting 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                        label: Text(_isSubmitting ? 'Submitting...' : 'Submit Form'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
    );
  }

  Widget _buildSwitchTile(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SwitchListTile(
        title: Text(title),
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildConsentTile() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: CheckboxListTile(
        title: const Text('I consent to the collection and use of my health data'),
        subtitle: const Text('Your data will be used only for health monitoring purposes and will be kept secure.'),
        secondary: Icon(Icons.security, color: Theme.of(context).colorScheme.primary),
        value: _consentGiven,
        onChanged: (value) => setState(() => _consentGiven = value ?? false),
        activeColor: Theme.of(context).colorScheme.primary,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
