import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/breath_analysis_screen.dart';
import 'screens/speech_analysis_screen.dart';
import 'screens/view_history_screen.dart';
import 'screens/symptom_tracker_screen.dart';
import 'screens/simple_auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://fjxofvxbujivsqyfbldu.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqeG9mdnhidWppdnNxeWZibGR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzNjE1MDgsImV4cCI6MjA2NTkzNzUwOH0.OEkUpvEX2lsB6eJI2NHg6xnFaM34kNi2CBo-61VTjzY',
    );
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }
  runApp(const BreatheasyApp());
}

class BreatheasyApp extends StatefulWidget {
  const BreatheasyApp({Key? key}) : super(key: key);

  @override
  State<BreatheasyApp> createState() => _BreatheasyAppState();
}

class _BreatheasyAppState extends State<BreatheasyApp> {
  bool _isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
    await prefs.setBool('isDarkTheme', _isDarkTheme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breath Easy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.blue[300],
          elevation: 1,
          centerTitle: true,
        ),
      ),
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      onGenerateRoute: (settings) {
        // Define your routes here
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/breath':
            return MaterialPageRoute(builder: (_) => const BreathAnalysisScreen());
          case '/speech':
            return MaterialPageRoute(builder: (_) => const SpeechAnalysisScreen());
          case '/history':
            return MaterialPageRoute(builder: (_) => const ViewHistoryScreen());
          case '/symptoms':
            return MaterialPageRoute(builder: (_) => const SymptomTrackerScreen());
          case '/simple_auth':
            return MaterialPageRoute(builder: (_) => const SimpleAuthScreen());
          default:
            return null;
        }
      },
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Handle connection state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Force rebuild
                        setState(() {});
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Always show main navigation for this app (simplified auth flow)
          return MainNavigationScreen(toggleTheme: toggleTheme);
        },
      ),
    );
  }
}
