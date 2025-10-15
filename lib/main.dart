import 'package:breath_easy/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/breath_analysis_screen.dart';
import 'screens/speech_analysis_screen.dart';
import 'screens/view_history_screen.dart';
import 'screens/symptom_tracker_screen.dart';

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

class BreatheasyApp extends StatelessWidget {
  const BreatheasyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breatheasy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          elevation: 1,
          centerTitle: true,
        ),
      ),
      onGenerateRoute: (settings) {
        // Define your routes here
        switch (settings.name) {
          case '/breath':
            return MaterialPageRoute(builder: (_) => const BreathAnalysisScreen());
          case '/speech':
            return MaterialPageRoute(builder: (_) => const SpeechAnalysisScreen());
          case '/history':
            return MaterialPageRoute(builder: (_) => const ViewHistoryScreen());
          case '/symptoms':
            return MaterialPageRoute(builder: (_) => const SymptomTrackerScreen());
          default:
            return null;
        }
      },
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('An error occurred'),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data?.session != null) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
