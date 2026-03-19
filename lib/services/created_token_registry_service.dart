import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../models/created_token_entry.dart';
import '../models/token.dart';

class CreatedTokenRegistryService {
  const CreatedTokenRegistryService();

  Future<List<Token>> getTokens() async {
    final entries = await getEntries();
    return entries.map((entry) => entry.token).toList(growable: false);
  }

  Future<List<CreatedTokenEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.createdTokens);
    if (raw == null || raw.trim().isEmpty) return const <CreatedTokenEntry>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <CreatedTokenEntry>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (entry) => _entryFromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CreatedTokenEntry>> getEntriesCreatedBy(String address) async {
    final entries = await getEntries();
    return entries
        .where((entry) => entry.matchesCreator(address))
        .toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
  }

  Future<void> saveToken(
    Token token, {
    String? creatorAddress,
    DateTime? createdAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getEntries();
    final byAddress = <String, CreatedTokenEntry>{
      for (final entry in current) entry.token.address.toLowerCase(): entry,
    };
    byAddress[token.address.toLowerCase()] = CreatedTokenEntry(
      token: token,
      creatorAddress: creatorAddress,
      createdAt: createdAt ?? DateTime.now(),
    );

    final encoded = jsonEncode(
      byAddress.values.map(_entryToJson).toList(growable: false),
    );
    await prefs.setString(StorageKeys.createdTokens, encoded);
  }

  Map<String, dynamic> _entryToJson(CreatedTokenEntry entry) {
    return <String, dynamic>{
      'symbol': entry.token.symbol,
      'name': entry.token.name,
      'decimals': entry.token.decimals,
      'balance': entry.token.balance,
      'address': entry.token.address,
      'iconUrl': entry.token.iconUrl,
      'creatorAddress': entry.creatorAddress,
      'createdAt': entry.createdAt?.toIso8601String(),
    };
  }

  CreatedTokenEntry _entryFromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    return CreatedTokenEntry(
      token: Token(
        symbol: (json['symbol'] ?? 'TOKEN').toString(),
        name: (json['name'] ?? 'Token').toString(),
        decimals: (json['decimals'] as num?)?.toInt() ?? 18,
        balance: (json['balance'] ?? '0').toString(),
        address: (json['address'] ?? '').toString(),
        iconUrl: json['iconUrl']?.toString(),
      ),
      creatorAddress: json['creatorAddress']?.toString(),
      createdAt: createdAtRaw == null || createdAtRaw.isEmpty
          ? null
          : DateTime.tryParse(createdAtRaw),
    );
  }
}
