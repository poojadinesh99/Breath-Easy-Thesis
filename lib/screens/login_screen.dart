import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import 'app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SupabaseAuthService _authService = SupabaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true; // Toggle between login and signup views

  Future<void> _signInWithEmail() async {
    try {
      final user = await _authService.signIn(_emailController.text.trim(), _passwordController.text.trim());
      if (user != null) {
        if (user.emailConfirmedAt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please verify your email before signing in.')),
          );
          return;
        }
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _signUpWithEmail() async {
    try {
      final user = await _authService.signUp(_emailController.text.trim(), _passwordController.text.trim());
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up successful! Please check your email to verify your account.')),
        );
        setState(() {
          _isLogin = true; // Switch to login after signup
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.notWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    _isLogin
                        ? 'assets/icons/illustration_signup.png' // Placeholder for login illustration, can be changed
                        : 'assets/icons/illustration_signup.png', // Replace with actual signup illustration PNG filename
                    fit: BoxFit.contain,
                    height: 250,
                  ),
                ),
              ),
              Text(
                _isLogin ? 'Welcome Back' : 'Welcome',
                style: AppTheme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Please sign in to continue'
                    : 'Stay organised and live stress-free with Breath Easy app',
                style: AppTheme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E3F), // Dark blue color matching design
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLogin ? _signInWithEmail : _signUpWithEmail,
                  child: Text(
                    _isLogin ? 'Sign In' : 'Sign Up',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                    style: AppTheme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: _isLogin ? 'Sign Up' : 'Login',
                        style: const TextStyle(
                          color: Color(0xFF1E1E3F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
