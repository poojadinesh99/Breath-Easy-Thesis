import 'package:flutter/material.dart';

class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'FAQ', icon: Icon(Icons.quiz)),
            Tab(text: 'Help', icon: Icon(Icons.help)),
            Tab(text: 'Contact', icon: Icon(Icons.contact_support)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFaqTab(),
          _buildHelpTab(),
          _buildContactTab(),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    final faqs = [
      {
        'question': 'How accurate are the breath analysis results?',
        'answer': 'Our breath analysis uses advanced AI algorithms trained on medical data with 90%+ accuracy. However, results should not replace professional medical diagnosis.',
      },
      {
        'question': 'Is my health data secure?',
        'answer': 'Yes, all your health data is encrypted and stored securely. We follow HIPAA compliance standards and never share your data without explicit consent.',
      },
      {
        'question': 'How often should I perform breath analysis?',
        'answer': 'For general monitoring, we recommend daily analysis. For specific conditions, follow your healthcare provider\'s recommendations.',
      },
      {
        'question': 'Can I use this app to replace my doctor visits?',
        'answer': 'No, this app is for monitoring and early detection only. Always consult healthcare professionals for medical diagnosis and treatment.',
      },
      {
        'question': 'What should I do if I get concerning results?',
        'answer': 'If you receive concerning results, contact your healthcare provider immediately. The app includes emergency contact features for urgent situations.',
      },
      {
        'question': 'How do I delete my account and data?',
        'answer': 'Go to Settings > Account > Delete Account. This will permanently remove all your data from our servers within 30 days.',
      },
      {
        'question': 'Why do I need to give microphone permission?',
        'answer': 'Microphone access is required for breath and speech analysis. We only record during active analysis sessions and delete recordings after processing.',
      },
      {
        'question': 'Can multiple family members use the same device?',
        'answer': 'Yes, but each person should have their own account for accurate health tracking and personalized recommendations.',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final faq = faqs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(
              faq['question']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            leading: Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  faq['answer']!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection(
            'Getting Started',
            Icons.play_circle,
            [
              'Create your account with email verification',
              'Complete the patient intake form',
              'Allow microphone permissions for analysis',
              'Perform your first breath analysis',
              'Review your health dashboard',
            ],
          ),
          
          _buildHelpSection(
            'Performing Analysis',
            Icons.mic,
            [
              'Find a quiet environment',
              'Hold device 6 inches from your mouth',
              'Follow the on-screen breathing instructions',
              'Speak clearly during speech analysis',
              'Wait for processing to complete',
            ],
          ),
          
          _buildHelpSection(
            'Understanding Results',
            Icons.analytics,
            [
              'Green indicators show normal results',
              'Yellow indicates attention needed',
              'Red requires immediate medical attention',
              'View detailed analysis in History tab',
              'Track trends over time in Dashboard',
            ],
          ),
          
          _buildHelpSection(
            'Troubleshooting',
            Icons.build,
            [
              'Ensure strong internet connection',
              'Check microphone permissions',
              'Restart the app if analysis fails',
              'Clear app cache in device settings',
              'Update to latest app version',
            ],
          ),
          
          _buildHelpSection(
            'Best Practices',
            Icons.thumb_up,
            [
              'Use the app at the same time daily',
              'Avoid analysis immediately after eating',
              'Keep device clean and microphone clear',
              'Store device in stable position during recording',
              'Regular calibration for best accuracy',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We\'re Here to Help',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is available 24/7 to assist you',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          _buildContactCard('Emergency Support', Icons.emergency, [
            'For medical emergencies, call 911 immediately',
            'For urgent health concerns: +1 (555) 911-HELP',
            'Emergency chat available in app',
          ]),
          
          _buildContactCard('General Support', Icons.headset_mic, [
            'Email: support@breatheasy.app',
            'Phone: +1 (555) 123-4567',
            'Live chat: Available 8 AM - 10 PM EST',
            'Response time: Within 24 hours',
          ]),
          
          _buildContactCard('Technical Support', Icons.computer, [
            'Email: tech@breatheasy.app',
            'Phone: +1 (555) 234-5678',
            'Remote assistance available',
            'Bug reports and feature requests welcome',
          ]),
          
          _buildContactCard('Medical Consultation', Icons.medical_services, [
            'Speak with certified respiratory therapists',
            'Schedule: +1 (555) 345-6789',
            'Email: medical@breatheasy.app',
            'Available Monday-Friday 9 AM - 5 PM EST',
          ]),
          
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Open in-app support chat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening support chat...')),
              );
            },
            icon: const Icon(Icons.chat),
            label: const Text('Start Live Chat'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, IconData icon, List<String> items) {
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
            ...items.asMap().entries.map((entry) {
              int index = entry.key;
              String item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(String title, IconData icon, List<String> items) {
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
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}
