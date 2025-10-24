import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'enhanced_patient_intake_form.dart';
import 'patient_profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'help_faq_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoSyncEnabled = true;
  double _recordingQuality = 1.0; // 0.0 = Low, 0.5 = Medium, 1.0 = High
  String _analysisFrequency = 'daily'; // daily, weekly, manual
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _darkModeEnabled = prefs.getBool('isDarkTheme') ?? false; // Use consistent key
        _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
        _recordingQuality = prefs.getDouble('recording_quality') ?? 1.0;
        _analysisFrequency = prefs.getString('analysis_frequency') ?? 'daily';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('sound_enabled', _soundEnabled);
      await prefs.setBool('vibration_enabled', _vibrationEnabled);
      // Dark theme is saved immediately when toggled, no need to save again
      await prefs.setBool('auto_sync_enabled', _autoSyncEnabled);
      await prefs.setDouble('recording_quality', _recordingQuality);
      await prefs.setString('analysis_frequency', _analysisFrequency);

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      
      // Clear all user preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon, size: 24) : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Profile Section
            if (user != null)
              _buildSettingsSection(
                title: 'Profile',
                icon: Icons.person,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        user.email?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(user.email ?? 'No email'),
                    subtitle: Text('User ID: ${user.id.substring(0, 8)}...'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  _buildActionTile(
                    title: 'Patient Profile',
                    subtitle: 'View and edit your medical information',
                    icon: Icons.medical_information,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PatientProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionTile(
                    title: 'Update Patient Info',
                    subtitle: 'Modify your intake form data',
                    icon: Icons.edit,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EnhancedPatientIntakeFormScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

            // Notification Settings
            _buildSettingsSection(
              title: 'Notifications',
              icon: Icons.notifications,
              children: [
                _buildSwitchTile(
                  title: 'Enable Notifications',
                  subtitle: 'Receive health alerts and reminders',
                  value: _notificationsEnabled,
                  icon: Icons.notifications_active,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Sound',
                  subtitle: 'Play notification sounds',
                  value: _soundEnabled,
                  icon: Icons.volume_up,
                  onChanged: (value) {
                    if (_notificationsEnabled) {
                      setState(() {
                        _soundEnabled = value;
                      });
                    }
                  },
                ),
                _buildSwitchTile(
                  title: 'Vibration',
                  subtitle: 'Vibrate for notifications',
                  value: _vibrationEnabled,
                  icon: Icons.vibration,
                  onChanged: (value) {
                    if (_notificationsEnabled) {
                      setState(() {
                        _vibrationEnabled = value;
                      });
                    }
                  },
                ),
              ],
            ),

            // Recording & Analysis Settings
            _buildSettingsSection(
              title: 'Recording & Analysis',
              icon: Icons.mic,
              children: [
                ListTile(
                  leading: const Icon(Icons.high_quality),
                  title: const Text('Recording Quality'),
                  subtitle: Text(_recordingQuality == 0.0 
                      ? 'Low (faster, less storage)' 
                      : _recordingQuality == 0.5 
                          ? 'Medium (balanced)' 
                          : 'High (best quality)'),
                  contentPadding: EdgeInsets.zero,
                ),
                Slider(
                  value: _recordingQuality,
                  min: 0.0,
                  max: 1.0,
                  divisions: 2,
                  onChanged: (value) {
                    setState(() {
                      _recordingQuality = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Analysis Frequency'),
                  subtitle: Text(_analysisFrequency == 'daily' 
                      ? 'Daily reminders' 
                      : _analysisFrequency == 'weekly' 
                          ? 'Weekly reminders' 
                          : 'Manual only'),
                  trailing: DropdownButton<String>(
                    value: _analysisFrequency,
                    items: const [
                      DropdownMenuItem(value: 'manual', child: Text('Manual')),
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _analysisFrequency = value;
                        });
                      }
                    },
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),

            // App Settings
            _buildSettingsSection(
              title: 'App Settings',
              icon: Icons.settings_applications,
              children: [
                _buildSwitchTile(
                  title: 'Auto Sync',
                  subtitle: 'Automatically sync data with cloud',
                  value: _autoSyncEnabled,
                  icon: Icons.sync,
                  onChanged: (value) {
                    setState(() {
                      _autoSyncEnabled = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme',
                  value: _darkModeEnabled,
                  icon: Icons.dark_mode,
                  onChanged: (value) async {
                    // Get theme and context before async operations
                    final theme = Theme.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    
                    setState(() {
                      _darkModeEnabled = value;
                    });
                    
                    // Save immediately and show restart message
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isDarkTheme', _darkModeEnabled);
                    
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _darkModeEnabled 
                                      ? 'Dark mode enabled! Restart app to see changes.'
                                      : 'Light mode enabled! Restart app to see changes.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: _darkModeEnabled 
                              ? Colors.grey[800] 
                              : theme.colorScheme.primary,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),

            // Support & Info
            _buildSettingsSection(
              title: 'Support & Information',
              icon: Icons.help,
              children: [
                _buildActionTile(
                  title: 'Help & FAQ',
                  subtitle: 'Get help with using the app',
                  icon: Icons.help_outline,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HelpFaqScreen()),
                    );
                  },
                ),
                _buildActionTile(
                  title: 'Privacy Policy',
                  subtitle: 'View our privacy policy',
                  icon: Icons.privacy_tip,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                _buildActionTile(
                  title: 'About',
                  subtitle: 'App version and information',
                  icon: Icons.info_outline,
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Breath Easy',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.air, size: 48),
                      children: [
                        const Text('AI-powered breath and speech analysis for health monitoring.'),
                      ],
                    );
                  },
                ),
              ],
            ),

            // Account Actions
            if (user != null)
              _buildSettingsSection(
                title: 'Account',
                icon: Icons.account_circle,
                children: [
                  _buildActionTile(
                    title: 'Sign Out',
                    subtitle: 'Log out of your account',
                    icon: Icons.logout,
                    textColor: Colors.red,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _signOut();
                              },
                              child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
