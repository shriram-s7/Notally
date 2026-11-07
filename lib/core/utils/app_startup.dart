import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AppStartup {
  static Future<void> initialize() async {
    await _setupSystemChannels();
    await _setupLocalAuth();
  }

  static Future<void> _setupSystemChannels() async {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static Future<void> _setupLocalAuth() async {
    final auth = LocalAuthentication();
    if (await auth.canCheckBiometrics || await auth.isDeviceSupported()) {
      try {
        await auth.getAvailableBiometrics();
      } catch (_) {}
    }
  }
}
