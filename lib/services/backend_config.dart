import 'dart:io' show Platform;

class BackendConfig {
  // Local dev - Use your computer's IP for physical device testing
  static String get baseLocal =>
      Platform.isAndroid ? 'http://127.0.0.1:8001' : 'http://127.0.0.1:8001';

  // Deployed (switch for physical device demo)
  static const String baseProd = 'https://breath-easy-thesis-backend.onrender.com';

  // Use local while testing in sim/emulator. Swap to baseProd for phone demo.
  static String get base => baseLocal; // Using local backend for immediate testing
}
