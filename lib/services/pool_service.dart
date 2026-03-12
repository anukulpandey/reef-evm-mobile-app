import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/pool.dart';

class PoolService {
  PoolService({http.Client? client, String? graphQlEndpoint})
    : _client = client ?? http.Client(),
      _graphQlEndpoint =
          graphQlEndpoint ??
          const String.fromEnvironment(
            'SUBGRAPH_GRAPHQL_ENDPOINT',
            defaultValue:
                'http://127.0.0.1:8000/subgraphs/name/uniswap-v2-localhost',
          );

  final http.Client _client;
  final String _graphQlEndpoint;

  Future<List<Pool>> getPools() async {
    const query = r'''
      query Pools {
        pairs(first: 50, orderBy: reserveUSD, orderDirection: desc) {
          id
          reserveUSD
          volumeUSD
          token0 { symbol }
          token1 { symbol }
        }
      }
    ''';

    final response = await _postWithEndpointFallback(query);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Subgraph request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw Exception('Subgraph returned errors');
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    final pairs = data?['pairs'] as List<dynamic>? ?? <dynamic>[];

    return pairs.map((dynamic item) {
      final pair = item as Map<String, dynamic>;
      final token0 = pair['token0'] as Map<String, dynamic>? ?? const {};
      final token1 = pair['token1'] as Map<String, dynamic>? ?? const {};
      final reserveUsd = _parseDouble(pair['reserveUSD']);
      final volumeUsd = _parseDouble(pair['volumeUSD']);
      final symbol0 = (token0['symbol'] as String?)?.trim();
      final symbol1 = (token1['symbol'] as String?)?.trim();

      return Pool(
        pairName:
            '${symbol0?.isNotEmpty == true ? symbol0 : 'Token0'} - ${symbol1?.isNotEmpty == true ? symbol1 : 'Token1'}',
        tvl: _formatCompactUsd(reserveUsd),
        volume24h: _formatCompactUsd(volumeUsd),
        percentChange: 0,
        tokenIcons: const <String>[],
      );
    }).toList();
  }

  Future<http.Response> _postWithEndpointFallback(String query) async {
    final endpoints = <String>{
      _graphQlEndpoint,
      if (_graphQlEndpoint.endsWith('/graphql'))
        _graphQlEndpoint.substring(
          0,
          _graphQlEndpoint.length - '/graphql'.length,
        ),
    };

    http.Response? lastResponse;
    for (final endpoint in endpoints) {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(<String, dynamic>{'query': query}),
          )
          .timeout(const Duration(seconds: 15));
      lastResponse = response;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
    }

    return lastResponse ??
        http.Response(
          '{"errors":[{"message":"No subgraph endpoint available"}]}',
          500,
        );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _formatCompactUsd(double amount) {
    return NumberFormat.compactCurrency(
      symbol: '\$',
      decimalDigits: amount >= 1000 ? 1 : 2,
    ).format(amount);
  }
}
