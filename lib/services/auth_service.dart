import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();
  static const String _appPasswordKey = 'app_password';

  Future<bool> authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final bool useBiometrics = prefs.getBool('use_biometrics') ?? false;
    final hasPassword =
        (prefs.getString(_appPasswordKey)?.trim() ?? '').isNotEmpty;

    if (!useBiometrics) {
      return !hasPassword;
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
      return !hasPassword; // Fallback if device doesn't support
    } catch (e) {
      print('Auth error: $e');
      return false;
    }
  }

  Future<bool> authenticateForTransaction({
    String localizedReason = 'Authenticate to confirm this transaction',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool useBiometrics = prefs.getBool('use_biometrics') ?? false;

    if (!useBiometrics) {
      return true;
    }

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      return await auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      print('Transaction auth error: $e');
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

  Future<void> setAppPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appPasswordKey, password);
  }

  Future<bool> hasAppPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString(_appPasswordKey)?.trim() ?? '';
    return password.isNotEmpty;
  }

  Future<bool> verifyAppPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString(_appPasswordKey)?.trim() ?? '';
    if (password.isEmpty) return true;
    return input.trim() == password;
  }
}
