import 'dart:io' show Platform;

// Use this for testing with a physical device on the same Wi-Fi network.
// Replace "YOUR_COMPUTER_IP" with the actual IP address of your computer.
const String _baseUrl = 'http://192.168.178.42:8000';

// Use this for testing with the Android Emulator.
// const String _baseUrl = 'http://10.0.2.2:8000';

// Use this for the deployed backend on Render.
// const String _baseUrl = 'https://breath-easy-backend-fresh.onrender.com';

class BackendConfig {
  // Local dev - Use your computer's IP for physical device testing
  static String get baseLocal =>
      Platform.isAndroid ? 'http://127.0.0.1:8001' : 'http://127.0.0.1:8001';

  // Deployed (switch for physical device demo)
  static const String baseProd = 'https://breath-easy-thesis-backend.onrender.com';

  // Use local while testing in sim/emulator. Swap to baseProd for phone demo.
  static String get base => baseLocal; // Using local backend for immediate testing
}
