import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final bool useBiometrics =
        prefs.getBool(StorageKeys.useBiometrics) ?? false;
    final hasPassword =
        (prefs.getString(StorageKeys.appPassword)?.trim() ?? '').isNotEmpty;

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
    final bool useBiometrics =
        prefs.getBool(StorageKeys.useBiometrics) ?? false;

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
    await prefs.setBool(StorageKeys.useBiometrics, enabled);
  }

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.useBiometrics) ?? false;
  }

  Future<void> setAppPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.appPassword, password);
  }

  Future<bool> hasAppPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString(StorageKeys.appPassword)?.trim() ?? '';
    return password.isNotEmpty;
  }

  Future<bool> verifyAppPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final password = prefs.getString(StorageKeys.appPassword)?.trim() ?? '';
    if (password.isEmpty) return true;
    return input.trim() == password;
  }
}
