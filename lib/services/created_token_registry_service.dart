import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../models/token.dart';

class CreatedTokenRegistryService {
  const CreatedTokenRegistryService();

  Future<List<Token>> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.createdTokens);
    if (raw == null || raw.trim().isEmpty) return const <Token>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <Token>[];

    return decoded
        .whereType<Map>()
        .map(
          (entry) => _tokenFromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveToken(Token token) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getTokens();
    final byAddress = <String, Token>{
      for (final entry in current) entry.address.toLowerCase(): entry,
    };
    byAddress[token.address.toLowerCase()] = token;

    final encoded = jsonEncode(
      byAddress.values.map(_tokenToJson).toList(growable: false),
    );
    await prefs.setString(StorageKeys.createdTokens, encoded);
  }

  Map<String, dynamic> _tokenToJson(Token token) {
    return <String, dynamic>{
      'symbol': token.symbol,
      'name': token.name,
      'decimals': token.decimals,
      'balance': token.balance,
      'address': token.address,
      'iconUrl': token.iconUrl,
    };
  }

  Token _tokenFromJson(Map<String, dynamic> json) {
    return Token(
      symbol: (json['symbol'] ?? 'TOKEN').toString(),
      name: (json['name'] ?? 'Token').toString(),
      decimals: (json['decimals'] as num?)?.toInt() ?? 18,
      balance: (json['balance'] ?? '0').toString(),
      address: (json['address'] ?? '').toString(),
      iconUrl: json['iconUrl']?.toString(),
    );
  }
}
