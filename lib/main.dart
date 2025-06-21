import 'package:breath_easy/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'features/exercises/presentation/exercises_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://fjxofvxbujivsqyfbldu.supabase.co', //  Supabase API URL from project setup
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqeG9mdnhidWppdnNxeWZibGR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzNjE1MDgsImV4cCI6MjA2NTkzNzUwOH0.OEkUpvEX2lsB6eJI2NHg6xnFaM34kNi2CBo-61VTjzY', // Replace with your current anon public key from Supabase project
  );
  
   // DEV ONLY: Clear session on app start
  await Supabase.instance.client.auth.signOut();

  runApp(const BreatheasyApp());
}

class BreatheasyApp extends StatefulWidget {
  const BreatheasyApp({Key? key}) : super(key: key);

  @override
  State<BreatheasyApp> createState() => _BreatheasyAppState();
}

class _BreatheasyAppState extends State<BreatheasyApp> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const PlaceholderWidget(title: 'Monitoring'),
    const ExercisesScreen(),
    const PlaceholderWidget(title: 'Alerts'),
    const PlaceholderWidget(title: 'Profile'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breatheasy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
routes: {
  '/': (context) => const SplashScreen(),
  '/home': (context) => const HomeScreen(),
  '/login': (context) => const LoginScreen(),
  '/splash': (context) => const SplashScreen(), // Optional but used in signOut
},

    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  final String title;

  const PlaceholderWidget({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title Screen\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}
