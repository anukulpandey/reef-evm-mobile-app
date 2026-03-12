import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();
  static const _keyPrefix = 'wallet_';

  Future<void> saveAccount(
    String address,
    String privateKey, {
    String? mnemonic,
  }) async {
    await _storage.write(key: '${_keyPrefix}pk_$address', value: privateKey);
    if (mnemonic != null) {
      await _storage.write(key: '${_keyPrefix}mn_$address', value: mnemonic);
    }

    // Save to shared prefs so we know which accounts exist without decrypting
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    if (!accounts.contains(address)) {
      accounts.add(address);
      await prefs.setStringList('accounts', accounts);
    }
  }

  Future<String?> getPrivateKey(String address) async {
    return await _storage.read(key: '${_keyPrefix}pk_$address');
  }

  Future<String?> getMnemonic(String address) async {
    return await _storage.read(key: '${_keyPrefix}mn_$address');
  }

  Future<List<String>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('accounts') ?? [];
  }

  Future<void> clearAccount(String address) async {
    await _storage.delete(key: '${_keyPrefix}pk_$address');
    await _storage.delete(key: '${_keyPrefix}mn_$address');
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    accounts.remove(address);
    await prefs.setStringList('accounts', accounts);
  }
}
