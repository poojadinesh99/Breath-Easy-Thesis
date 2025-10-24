import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple utility to test database connection and table existence
class DatabaseDiagnostic {
  static Future<void> runDiagnostic() async {
    print('=== Database Diagnostic ===');
    
    try {
      final supabase = Supabase.instance.client;
      
      // Test 1: Check if we can connect
      print('1. Testing connection...');
      final user = supabase.auth.currentUser;
      print('   Current user: ${user?.id ?? "No user"}');
      
      // Test 2: Try to query each table
      final tables = [
        'analysis_history',
        'patients', 
        'symptoms',
        'ai_alerts',
        'recordings',
        'exercises'
      ];
      
      for (String table in tables) {
        try {
          print('2. Testing table: $table');
          final response = await supabase
              .from(table)
              .select('id')
              .limit(1);
          print('   ✅ Table $table exists and accessible');
        } catch (e) {
          print('   ❌ Table $table error: $e');
        }
      }
      
      // Test 3: Try creating anonymous user
      if (user == null) {
        print('3. Testing anonymous user creation...');
        try {
          final response = await supabase.auth.signInAnonymously();
          print('   ✅ Anonymous user created: ${response.user?.id}');
        } catch (e) {
          print('   ❌ Anonymous user creation failed: $e');
        }
      }
      
    } catch (e) {
      print('❌ General error: $e');
    }
    
    print('=== Diagnostic Complete ===');
  }
}
