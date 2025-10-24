import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.privacy_tip,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your Privacy Matters',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildPolicySection(
              context,
              'Information We Collect',
              Icons.data_usage,
              [
                'Personal Information: Name, age, contact number',
                'Health Information: Respiratory health data, medical history',
                'Audio Data: Voice recordings for breath and speech analysis',
                'Usage Data: App usage patterns and preferences',
                'Device Information: Device type, operating system version',
              ],
            ),
            
            _buildPolicySection(
              context,
              'How We Use Your Information',
              Icons.settings,
              [
                'Provide respiratory health monitoring and analysis',
                'Generate personalized health recommendations',
                'Track your health progress over time',
                'Improve our app functionality and user experience',
                'Send important health alerts and notifications',
              ],
            ),
            
            _buildPolicySection(
              context,
              'Data Security',
              Icons.security,
              [
                'All data is encrypted in transit and at rest',
                'Secure cloud storage with industry-standard protection',
                'Regular security audits and monitoring',
                'Access controls and authentication protocols',
                'No data sharing with third parties without consent',
              ],
            ),
            
            _buildPolicySection(
              context,
              'Your Rights',
              Icons.gavel,
              [
                'Access your personal data at any time',
                'Request correction of inaccurate information',
                'Delete your account and associated data',
                'Export your data in a portable format',
                'Withdraw consent for data processing',
              ],
            ),
            
            _buildPolicySection(
              context,
              'Data Retention',
              Icons.schedule,
              [
                'Health data retained for 7 years for medical purposes',
                'Audio recordings deleted after analysis completion',
                'Account data retained until account deletion',
                'Anonymous usage statistics may be retained longer',
                'Backups are securely deleted within 30 days',
              ],
            ),
            
            _buildPolicySection(
              context,
              'Contact Us',
              Icons.contact_support,
              [
                'Email: privacy@breatheasy.app',
                'Phone: +1 (555) 123-4567',
                'Address: 123 Health Tech Blvd, Medical City, MC 12345',
                'Data Protection Officer: privacy-officer@breatheasy.app',
              ],
            ),
            
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This privacy policy is effective immediately and will remain in effect except with respect to any changes in its provisions in the future.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(BuildContext context, String title, IconData icon, List<String> items) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
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
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}
