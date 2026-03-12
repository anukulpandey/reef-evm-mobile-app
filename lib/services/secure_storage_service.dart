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
    final normalizedAddress = address.trim().toLowerCase();
    await _storage.write(
      key: '${_keyPrefix}pk_$normalizedAddress',
      value: privateKey,
    );
    if (mnemonic != null) {
      await _storage.write(
        key: '${_keyPrefix}mn_$normalizedAddress',
        value: mnemonic,
      );
    }

    // Save to shared prefs so we know which accounts exist without decrypting
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? <String>[];
    final exists = accounts.any(
      (existing) => existing.trim().toLowerCase() == normalizedAddress,
    );
    if (!exists) {
      accounts.add(normalizedAddress);
      await prefs.setStringList('accounts', accounts.toSet().toList());
    }
  }

  Future<String?> getPrivateKey(String address) async {
    final normalizedAddress = address.trim().toLowerCase();
    final exact = await _storage.read(
      key: '${_keyPrefix}pk_$normalizedAddress',
    );
    if (exact != null && exact.trim().isNotEmpty) return exact;

    // Legacy fallback for mixed-case keys.
    final allSecure = await _storage.readAll();
    for (final entry in allSecure.entries) {
      if (!entry.key.startsWith('${_keyPrefix}pk_')) continue;
      final storedAddress = entry.key.substring('${_keyPrefix}pk_'.length);
      if (storedAddress.trim().toLowerCase() == normalizedAddress) {
        return entry.value;
      }
    }
    return null;
  }

  Future<String?> getMnemonic(String address) async {
    final normalizedAddress = address.trim().toLowerCase();
    final exact = await _storage.read(
      key: '${_keyPrefix}mn_$normalizedAddress',
    );
    if (exact != null && exact.trim().isNotEmpty) return exact;

    // Legacy fallback for mixed-case keys.
    final allSecure = await _storage.readAll();
    for (final entry in allSecure.entries) {
      if (!entry.key.startsWith('${_keyPrefix}mn_')) continue;
      final storedAddress = entry.key.substring('${_keyPrefix}mn_'.length);
      if (storedAddress.trim().toLowerCase() == normalizedAddress) {
        return entry.value;
      }
    }
    return null;
  }

  Future<List<String>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getStringList('accounts') ?? <String>[];

    // Recover any legacy accounts that may exist in secure storage but are
    // missing from SharedPreferences index.
    final allSecure = await _storage.readAll();
    final discovered = <String>[];
    final prefix = '${_keyPrefix}pk_';
    for (final key in allSecure.keys) {
      if (!key.startsWith(prefix)) continue;
      final address = key.substring(prefix.length).trim();
      if (address.isNotEmpty) discovered.add(address);
    }

    final merged = <String>[];
    final seen = <String>{};
    for (final address in [...fromPrefs, ...discovered]) {
      final normalized = address.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      merged.add(address.trim());
    }

    if (merged.length != fromPrefs.length ||
        !fromPrefs.every((value) => merged.contains(value))) {
      await prefs.setStringList('accounts', merged);
    }

    return merged;
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
    final normalizedAddress = address.trim().toLowerCase();
    await _storage.delete(key: '${_keyPrefix}pk_$normalizedAddress');
    await _storage.delete(key: '${_keyPrefix}mn_$normalizedAddress');

    final allSecure = await _storage.readAll();
    for (final key in allSecure.keys) {
      if (key.startsWith('${_keyPrefix}pk_') ||
          key.startsWith('${_keyPrefix}mn_')) {
        final suffix = key.contains('${_keyPrefix}pk_')
            ? key.substring('${_keyPrefix}pk_'.length)
            : key.substring('${_keyPrefix}mn_'.length);
        if (suffix.trim().toLowerCase() == normalizedAddress) {
          await _storage.delete(key: key);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('accounts') ?? <String>[];
    final filtered = accounts
        .where((value) => value.trim().toLowerCase() != normalizedAddress)
        .toList();
    await prefs.setStringList('accounts', filtered);

    final raw = prefs.getString(_accountNamesKey);
    final decoded = _decodeStringMap(raw);
    decoded.remove(normalizedAddress);
    await prefs.setString(_accountNamesKey, jsonEncode(decoded));

    final lastActive = prefs
        .getString(_lastActiveAccountKey)
        ?.trim()
        .toLowerCase();
    if (lastActive == normalizedAddress) {
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
