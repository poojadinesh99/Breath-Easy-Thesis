import 'package:breath_easy/screens/demo_analysis_screen.dart';
import 'package:breath_easy/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'features/exercises/presentation/exercises_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/alerts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://fjxofvxbujivsqyfbldu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqeG9mdnhidWppdnNxeWZibGR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzNjE1MDgsImV4cCI6MjA2NTkzNzUwOH0.OEkUpvEX2lsB6eJI2NHg6xnFaM34kNi2CBo-61VTjzY',
  );
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
    const MonitoringScreen(),
    const ExercisesScreen(),
    const AlertsScreen(), // replaced placeholder with dynamic alerts screen
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
      routes: {
        '/home': (context) => const DashboardWithNav(),
        '/login': (context) => const LoginScreen(),
        '/demo': (context) => const DemoAnalysisScreen(),
      },
      home: Builder(
        builder: (context) {
          final session = Supabase.instance.client.auth.currentSession;
          return session == null ? const LoginScreen() : const DashboardWithNav();
        },
      ),
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

class DashboardWithNav extends StatefulWidget {
  const DashboardWithNav({Key? key}) : super(key: key);

  @override
  State<DashboardWithNav> createState() => _DashboardWithNavState();
}

class _DashboardWithNavState extends State<DashboardWithNav> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const MonitoringScreen(),
    const ExercisesScreen(),
    const AlertsScreen(), // replaced placeholder with dynamic alerts
    const PlaceholderWidget(title: 'Profile'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor), label: 'Monitoring'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Exercises'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
