import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final bool useBiometrics = prefs.getBool('use_biometrics') ?? false;

    if (!useBiometrics) {
      // By default, if biometrics aren't explicitly enabled, we still want to protect launch
      // For this test app, we'll allow passthrough if not explicitly enabled, but typically
      // we'd prompt for a custom PIN.
      return true;
    }

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        return await auth.authenticate(
          localizedReason: 'Please authenticate to access your wallet',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
      }
      return true; // Fallback if device doesn't support
    } catch (e) {
      print('Auth error: $e');
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometrics', enabled);
  }

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('use_biometrics') ?? false;
  }
}
