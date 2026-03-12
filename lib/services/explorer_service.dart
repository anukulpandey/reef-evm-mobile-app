import '../models/token.dart';
import '../utils/token_icon_resolver.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ExplorerService {
  ExplorerService({
    http.Client? client,
    String? explorerApiV2,
    String? explorerBaseUrl,
  }) : _client = client ?? http.Client(),
       _explorerApiV2 =
           explorerApiV2 ??
           const String.fromEnvironment(
             'EXPLORER_API_V2',
             defaultValue: 'http://127.0.0.1/api/v2',
           ),
       _explorerBaseUrl =
           explorerBaseUrl ??
           const String.fromEnvironment(
             'EXPLORER_BASE_URL',
             defaultValue: 'http://127.0.0.1',
           );

  final http.Client _client;
  final String _explorerApiV2;
  final String _explorerBaseUrl;

  Future<List<Token>> fetchErc20TokensForAddress(String address) async {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) return const <Token>[];

    final v2Tokens = await _fetchV2TokenBalances(normalizedAddress);
    if (v2Tokens.isNotEmpty) return v2Tokens;

    return _fetchLegacyTokenBalances(normalizedAddress);
  }

  Future<String?> fetchNativeBalanceForAddress(String address) async {
    final normalizedAddress = address.trim();
    if (normalizedAddress.isEmpty) return null;
    final uri = Uri.parse('$_explorerApiV2/addresses/$normalizedAddress');

    try {
      final response = await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final payload = _tryDecodeJson(response.body);
      if (payload is! Map<String, dynamic>) return null;

      final raw = _parsePositiveBigInt(payload['coin_balance']);
      if (raw <= BigInt.zero) return '0';
      return _formatTokenAmount(raw, 18);
    } catch (_) {
      return null;
    }
  }

  Future<List<Token>> fetchAllErc20Tokens() async {
    final collectedItems = <dynamic>[];
    Map<String, String>? nextPageParams;

    for (var page = 0; page < 25; page++) {
      final params = <String, String>{
        'type': 'ERC-20',
        if (nextPageParams != null) ...nextPageParams,
      };
      final query = Uri(queryParameters: params).query;
      final uri = Uri.parse('$_explorerApiV2/tokens?$query');

      http.Response response;
      try {
        response = await _client
            .get(uri, headers: const {'accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        break;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        break;
      }

      final payload = _tryDecodeJson(response.body);
      if (payload is! Map<String, dynamic>) break;
      final items = payload['items'];
      if (items is List && items.isNotEmpty) {
        collectedItems.addAll(items);
      }
      nextPageParams = _extractV2NextPageParams(payload);
      if (nextPageParams == null || nextPageParams.isEmpty) break;
    }

    return _parseTokenCatalog(collectedItems);
  }

  Future<List<Token>> _fetchV2TokenBalances(String address) async {
    final collectedItems = <dynamic>[];
    Map<String, String>? nextPageParams;
    var hasV2Response = false;

    for (var page = 0; page < 25; page++) {
      final query = (nextPageParams == null || nextPageParams.isEmpty)
          ? ''
          : '?${Uri(queryParameters: nextPageParams).query}';
      final uri = Uri.parse(
        '$_explorerApiV2/addresses/$address/token-balances$query',
      );
      http.Response response;
      try {
        response = await _client
            .get(uri, headers: const {'accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        break;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        break;
      }

      hasV2Response = true;
      final payload = _tryDecodeJson(response.body);
      final pageItems = _extractV2Items(payload);
      if (pageItems.isNotEmpty) {
        collectedItems.addAll(pageItems);
      }

      nextPageParams = _extractV2NextPageParams(payload);
      if (nextPageParams == null || nextPageParams.isEmpty) {
        break;
      }
    }

    if (!hasV2Response) return const <Token>[];
    return _parseV2Tokens(collectedItems);
  }

  Future<List<Token>> _fetchLegacyTokenBalances(String address) async {
    final uri = Uri.parse(
      '$_explorerBaseUrl/api?module=account&action=tokenlist&address=$address',
    );
    try {
      final response = await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <Token>[];
      }
      final payload = _tryDecodeJson(response.body);
      return _parseLegacyTokens(payload);
    } catch (_) {
      return const <Token>[];
    }
  }

  List<dynamic> _extractV2Items(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      final items = payload['items'];
      if (items is List) return items;
    }
    return const <dynamic>[];
  }

  Map<String, String>? _extractV2NextPageParams(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    final rawParams = payload['next_page_params'];
    if (rawParams is! Map<String, dynamic>) return null;

    final result = <String, String>{};
    rawParams.forEach((key, value) {
      if (value != null) result[key] = value.toString();
    });
    return result.isEmpty ? null : result;
  }

  List<Token> _parseV2Tokens(List<dynamic> items) {
    final byAddress = <String, _TokenAccumulator>{};

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      final token = item['token'];
      if (token is! Map<String, dynamic>) continue;

      final tokenType = (token['type'] ?? 'ERC-20').toString().toUpperCase();
      if (!tokenType.contains('ERC-20')) continue;

      final rawBalance = _parsePositiveBigInt(item['value']);
      if (rawBalance <= BigInt.zero) continue;

      final address = (token['address_hash'] ?? token['address'] ?? '')
          .toString()
          .trim();
      if (!_isHexAddress(address)) continue;

      final normalizedAddress = _normalizeAddress(address);
      final symbol = (token['symbol'] ?? 'TOKEN')
          .toString()
          .trim()
          .toUpperCase();
      final fallbackName =
          'Token ${normalizedAddress.substring(0, 6)}...${normalizedAddress.substring(normalizedAddress.length - 4)}';
      final name = (token['name'] ?? fallbackName).toString().trim();
      final decimals = _parseDecimals(token['decimals']);
      final iconUrl = token['icon_url']?.toString();

      byAddress[normalizedAddress] = _TokenAccumulator(
        token: Token(
          symbol: symbol,
          name: name,
          decimals: decimals,
          balance: _formatTokenAmount(rawBalance, decimals),
          address: normalizedAddress,
          iconUrl: TokenIconResolver.resolveTokenIconUrl(
            address: normalizedAddress,
            symbol: symbol,
            iconUrl: iconUrl,
          ),
        ),
        rawBalance: rawBalance,
      );
    }

    final values = byAddress.values.toList()
      ..sort((a, b) => b.rawBalance.compareTo(a.rawBalance));
    return values.map((entry) => entry.token).toList();
  }

  List<Token> _parseLegacyTokens(dynamic payload) {
    if (payload is! Map<String, dynamic>) return const <Token>[];
    final result = payload['result'];
    if (result is! List) return const <Token>[];

    final byAddress = <String, _TokenAccumulator>{};
    for (final item in result) {
      if (item is! Map<String, dynamic>) continue;

      final rawBalance = _parsePositiveBigInt(item['balance']);
      if (rawBalance <= BigInt.zero) continue;

      final address = (item['contractAddress'] ?? '').toString().trim();
      if (!_isHexAddress(address)) continue;
      final normalizedAddress = _normalizeAddress(address);

      final symbol = (item['tokenSymbol'] ?? 'TOKEN')
          .toString()
          .trim()
          .toUpperCase();
      final fallbackName =
          'Token ${normalizedAddress.substring(0, 6)}...${normalizedAddress.substring(normalizedAddress.length - 4)}';
      final name = (item['tokenName'] ?? fallbackName).toString().trim();
      final decimals = _parseDecimals(item['tokenDecimal']);
      final iconUrl = item['iconUrl']?.toString();

      byAddress[normalizedAddress] = _TokenAccumulator(
        token: Token(
          symbol: symbol,
          name: name,
          decimals: decimals,
          balance: _formatTokenAmount(rawBalance, decimals),
          address: normalizedAddress,
          iconUrl: TokenIconResolver.resolveTokenIconUrl(
            address: normalizedAddress,
            symbol: symbol,
            iconUrl: iconUrl,
          ),
        ),
        rawBalance: rawBalance,
      );
    }

    final values = byAddress.values.toList()
      ..sort((a, b) => b.rawBalance.compareTo(a.rawBalance));
    return values.map((entry) => entry.token).toList();
  }

  List<Token> _parseTokenCatalog(List<dynamic> items) {
    final byAddress = <String, Token>{};

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final type = (item['type'] ?? 'ERC-20').toString().toUpperCase();
      if (!type.contains('ERC-20')) continue;

      final address = (item['address_hash'] ?? '').toString().trim();
      if (!_isHexAddress(address)) continue;

      final normalizedAddress = _normalizeAddress(address);
      final symbol = (item['symbol'] ?? 'TOKEN')
          .toString()
          .trim()
          .toUpperCase();
      final fallbackName =
          'Token ${normalizedAddress.substring(0, 6)}...${normalizedAddress.substring(normalizedAddress.length - 4)}';
      final name = (item['name'] ?? fallbackName).toString().trim();
      final decimals = _parseDecimals(item['decimals']);
      final iconUrl = item['icon_url']?.toString();

      byAddress[normalizedAddress] = Token(
        symbol: symbol,
        name: name,
        decimals: decimals,
        balance: '0',
        address: normalizedAddress,
        iconUrl: TokenIconResolver.resolveTokenIconUrl(
          address: normalizedAddress,
          symbol: symbol,
          iconUrl: iconUrl,
        ),
      );
    }

    return byAddress.values.toList();
  }

  dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static BigInt _parsePositiveBigInt(dynamic value) {
    if (value == null) return BigInt.zero;
    final text = value.toString().trim();
    if (text.isEmpty) return BigInt.zero;
    BigInt parsed;
    if (text.startsWith('0x') || text.startsWith('0X')) {
      parsed = BigInt.tryParse(text.substring(2), radix: 16) ?? BigInt.zero;
    } else {
      final intPart = text.split('.').first;
      parsed = BigInt.tryParse(intPart) ?? BigInt.zero;
    }
    if (parsed < BigInt.zero) return BigInt.zero;
    return parsed;
  }

  static int _parseDecimals(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < 0 || parsed > 255) return 18;
    return parsed;
  }

  static String _formatTokenAmount(BigInt raw, int decimals) {
    if (raw == BigInt.zero) return '0';
    if (decimals <= 0) return raw.toString();

    final divisor = BigInt.from(10).pow(decimals);
    final whole = raw ~/ divisor;
    final fractionRaw = raw
        .remainder(divisor)
        .toString()
        .padLeft(decimals, '0');

    final precision = decimals > 6 ? 6 : decimals;
    var fraction = fractionRaw.substring(0, precision);
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');

    if (fraction.isEmpty) return whole.toString();
    return '$whole.$fraction';
  }

  static String _normalizeAddress(String value) {
    return value.trim().toLowerCase();
  }

  static bool _isHexAddress(String value) {
    final normalized = value.trim();
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(normalized);
  }
}

class _TokenAccumulator {
  _TokenAccumulator({required this.token, required this.rawBalance});

  final Token token;
  final BigInt rawBalance;
}
