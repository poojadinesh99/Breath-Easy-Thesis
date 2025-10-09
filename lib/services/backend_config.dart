import 'dart:io' show Platform;

// Use this for testing with a physical device on the same Wi-Fi network.
// Replace "YOUR_COMPUTER_IP" with the actual IP address of your computer.
const String _baseUrl = 'http://192.168.178.42:8000';

// Use this for testing with the Android Emulator.
// const String _baseUrl = 'http://10.0.2.2:8000';

// Use this for the deployed backend on Render.
// const String _baseUrl = 'https://breath-easy-backend-fresh.onrender.com';

class BackendConfig {
  // Production backend URL
  static const String baseProd = 'https://breath-easy-backend-fresh.onrender.com';

  // Development backend URL (for testing)
  static String get baseDev =>
      Platform.isAndroid ? 'http://192.168.178.42:8000' : 'http://localhost:8000';

  // Always use production URL for release builds
  static String get base => const bool.fromEnvironment('dart.vm.product')
      ? baseProd
      : baseDev;
}
