import 'package:flutter/material.dart';
import 'modern_home_screen.dart';
import 'patient_profile_screen.dart';
import 'view_history_screen.dart';
import 'ai_alerts_screen.dart';
import 'recommendations_screen.dart';

/// Main navigation screen with BottomNavigationBar
/// Integrates all app screens into a cohesive flow
class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? toggleTheme;
  
  const MainNavigationScreen({super.key, this.toggleTheme});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  // PageController to maintain state across tabs
  final PageController _pageController = PageController();

  // List of screens for each tab
  late final List<Widget> _screens = [
    const ModernHomeScreen(),
    PatientProfileScreen(toggleTheme: widget.toggleTheme),
    const ViewHistoryScreen(),
    const AIAlertsScreen(),
    const RecommendationsScreen(),
  ];

  // Navigation items configuration
  final List<BottomNavigationBarItem> _navigationItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home),
      activeIcon: Icon(Icons.home, size: 28),
      label: 'Home',
      tooltip: 'Dashboard',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person),
      activeIcon: Icon(Icons.person, size: 28),
      label: 'Profile',
      tooltip: 'Patient Profile & Information',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.timeline),
      activeIcon: Icon(Icons.timeline, size: 28),
      label: 'History',
      tooltip: 'Symptom Tracking & History',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.warning),
      activeIcon: Icon(Icons.warning, size: 28),
      label: 'Alerts',
      tooltip: 'AI Health Alerts',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.lightbulb),
      activeIcon: Icon(Icons.lightbulb, size: 28),
      label: 'Tips',
      tooltip: 'Health Recommendations',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Animate to the selected page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Show snackbar for empty screens (bonus feature)
    _showEmptyScreenMessage(index);
  }

  void _showEmptyScreenMessage(int index) {
    String? message;
    
    switch (index) {
      case 3: // AI Alerts
        message = '🤖 No AI alerts at the moment - your health looks good!';
        break;
      case 4: // Recommendations
        message = '💡 Check out our health tips to improve your wellness!';
        break;
    }

    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          items: _navigationItems,
          // Material 3 styling
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
          elevation: 8,
          // Rounded icons and smooth transitions
          selectedIconTheme: IconThemeData(
            size: 28,
            color: theme.colorScheme.primary,
          ),
          unselectedIconTheme: IconThemeData(
            size: 24,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          showUnselectedLabels: true,
          enableFeedback: true,
        ),
      ),
    );
  }
}
