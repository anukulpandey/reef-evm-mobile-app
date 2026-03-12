import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();
  static const _keyPrefix = 'wallet_';
  static const _accountNamesKey = 'account_names_v1';
  static const _lastActiveAccountKey = 'last_active_account_v1';

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

  Future<void> saveAccountName(String address, String name) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountNamesKey);
    final decoded = _decodeStringMap(raw);
    decoded[normalized] = name.trim();
    await prefs.setString(_accountNamesKey, jsonEncode(decoded));
  }

  Future<String?> getAccountName(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountNamesKey);
    final decoded = _decodeStringMap(raw);
    final value = decoded[normalized]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setLastActiveAccount(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActiveAccountKey, normalized);
  }

  Future<String?> getLastActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastActiveAccountKey)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> clearAccount(String address) async {
    await _storage.delete(key: '${_keyPrefix}pk_$address');
    await _storage.delete(key: '${_keyPrefix}mn_$address');
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? [];
    accounts.remove(address);
    await prefs.setStringList('accounts', accounts);

    final raw = prefs.getString(_accountNamesKey);
    final decoded = _decodeStringMap(raw);
    decoded.remove(address.trim().toLowerCase());
    await prefs.setString(_accountNamesKey, jsonEncode(decoded));

    final lastActive = prefs.getString(_lastActiveAccountKey);
    if (lastActive == address) {
      await prefs.remove(_lastActiveAccountKey);
    }
  }

  Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, String>{};
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return <String, String>{};
      final map = <String, String>{};
      data.forEach((key, value) {
        map[key] = value?.toString() ?? '';
      });
      return map;
    } catch (_) {
      return <String, String>{};
    }
  }
}
