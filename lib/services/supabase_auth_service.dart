import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get current user
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    if (res.session != null) {
      return res.user;
    } else {
      throw Exception('Sign in failed');
    }
  }

  // Sign up with email and password
  Future<User?> signUp(String email, String password) async {
    final res = await _client.auth.signUp(email: email, password: password);
    if (res.user != null) {
      return res.user;
    } else {
      throw Exception('Sign up failed');
    }
  }

  // Anonymous login
  Future<User?> signInAnonymously() async {
    // Supabase Flutter SDK does not support anonymous login directly.
    // As a workaround, you can create a temporary user or skip auth.
    // Here, we throw unimplemented error.
    throw UnimplementedError('Anonymous login is not supported by Supabase Flutter SDK.');
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Check if Supabase connection is working by querying users table
  Future<bool> isConnected() async {
    try {
      final response = await _client.from('users').select().limit(1).maybeSingle();
      if (response == null) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
