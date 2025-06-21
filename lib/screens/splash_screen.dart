import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SupabaseAuthService _authService = SupabaseAuthService();
  bool _isNavigated = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (!_isNavigated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigate(session != null ? const HomeScreen() : const LoginScreen());
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _checkAuthentication() async {
    // Optional delay to show splash
    await Future.delayed(const Duration(seconds: 1));
    final user = _authService.getCurrentUser();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigate(user != null ? const HomeScreen() : const LoginScreen());
    });
  }

  void _navigate(Widget screen) {
    if (_isNavigated) return;
    _isNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
