import 'dart:io' show Platform;

class BackendConfig {
  // Local dev
  static String get baseLocal =>
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  // Deployed (switch for physical device demo)
  static const String baseProd = 'https://breath-easy-thesis.onrender.com';

  // Use local while testing in sim/emulator. Swap to baseProd for phone demo.
  static String get base => baseLocal; // Temporarily using local for testing
}
