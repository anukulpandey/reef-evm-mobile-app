import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart';

import '../models/pool.dart';
import '../models/pool_transaction.dart';
import '../utils/token_icon_resolver.dart';

class PoolService {
  PoolService({
    http.Client? client,
    String? graphQlEndpoint,
    String? explorerApiV2,
  }) : _client = client ?? http.Client(),
       _graphQlEndpoint =
           graphQlEndpoint ??
           const String.fromEnvironment(
             'SUBGRAPH_GRAPHQL_ENDPOINT',
             defaultValue:
                 'http://127.0.0.1:8000/subgraphs/name/uniswap-v2-localhost',
           ),
       _explorerApiV2 =
           explorerApiV2 ??
           const String.fromEnvironment(
             'EXPLORER_API_V2',
             defaultValue: 'http://127.0.0.1/api/v2',
           );

  final http.Client _client;
  final String _graphQlEndpoint;
  final String _explorerApiV2;
  final Map<String, String?> _tokenIconCache = <String, String?>{};
  static const double _defaultReefUsd = 0.000073;
  static const String _localRpcUrl = String.fromEnvironment(
    'REEF_RPC_URL',
    defaultValue: 'http://127.0.0.1:8545',
  );
  static const String _localPairAddress = String.fromEnvironment(
    'PAIR_ADDRESS',
    defaultValue: '',
  );
  static const String _localTokenAddress = String.fromEnvironment(
    'TOKEN_ADDRESS',
    defaultValue: '',
  );
  static const String _localWrappedAddress = String.fromEnvironment(
    'REEFSWAP_WREEF',
    defaultValue: '',
  );

  Future<List<Pool>> getPools() async {
    const query = r'''
      query Pools {
        pairs(first: 50, orderBy: reserveUSD, orderDirection: desc) {
          id
          reserve0
          reserve1
          reserveUSD
          volumeUSD
          token0Price
          token1Price
          token0 { id symbol name decimals }
          token1 { id symbol name decimals }
        }
      }
    ''';

    final response = await _postWithEndpointFallback(query);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _loadLocalPoolsFallback();
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      return _loadLocalPoolsFallback();
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    final pairs = data?['pairs'] as List<dynamic>? ?? <dynamic>[];
    if (pairs.isEmpty) {
      return _loadLocalPoolsFallback();
    }
    final tokenAddresses = <String>{};
    for (final item in pairs) {
      final pair = item as Map<String, dynamic>;
      final token0 = pair['token0'] as Map<String, dynamic>? ?? const {};
      final token1 = pair['token1'] as Map<String, dynamic>? ?? const {};
      final token0Id = token0['id'] as String?;
      final token1Id = token1['id'] as String?;
      if (token0Id != null && token0Id.trim().isNotEmpty) {
        tokenAddresses.add(_normalizeAddress(token0Id));
      }
      if (token1Id != null && token1Id.trim().isNotEmpty) {
        tokenAddresses.add(_normalizeAddress(token1Id));
      }
    }

    final explorerIcons = await _loadExplorerTokenIcons(tokenAddresses);

    final mapped = pairs.map((dynamic item) {
      final pair = item as Map<String, dynamic>;
      final token0 = pair['token0'] as Map<String, dynamic>? ?? const {};
      final token1 = pair['token1'] as Map<String, dynamic>? ?? const {};
      final reserveUsd = _parseDouble(pair['reserveUSD']);
      final volumeUsd = _parseDouble(pair['volumeUSD']);
      final token0Id = token0['id'] as String?;
      final token1Id = token1['id'] as String?;
      final symbol0 = (token0['symbol'] as String?)?.trim();
      final symbol1 = (token1['symbol'] as String?)?.trim();
      final reserve0 = _parseDouble(pair['reserve0']);
      final reserve1 = _parseDouble(pair['reserve1']);
      final token0Price = _parseDouble(pair['token0Price']);
      final token1Price = _parseDouble(pair['token1Price']);
      final token0Decimals = _parseInt(token0['decimals'], fallback: 18);
      final token1Decimals = _parseInt(token1['decimals'], fallback: 18);
      final icon0 = token0Id == null
          ? null
          : explorerIcons[_normalizeAddress(token0Id)];
      final icon1 = token1Id == null
          ? null
          : explorerIcons[_normalizeAddress(token1Id)];

      return Pool(
        id: (pair['id'] as String?)?.trim() ?? '',
        pairName:
            '${symbol0?.isNotEmpty == true ? symbol0 : 'Token0'} - ${symbol1?.isNotEmpty == true ? symbol1 : 'Token1'}',
        token0Symbol: symbol0?.isNotEmpty == true ? symbol0! : 'Token0',
        token1Symbol: symbol1?.isNotEmpty == true ? symbol1! : 'Token1',
        token0Address: token0Id?.trim().toLowerCase() ?? '',
        token1Address: token1Id?.trim().toLowerCase() ?? '',
        token0Decimals: token0Decimals,
        token1Decimals: token1Decimals,
        tvl: _formatCompactUsd(reserveUsd),
        volume24h: _formatCompactUsd(volumeUsd),
        reserve0: reserve0,
        reserve1: reserve1,
        reserveUsd: reserveUsd,
        volumeUsd: volumeUsd,
        token0Price: token0Price,
        token1Price: token1Price,
        percentChange: 0,
        tokenIcons: <String>[
          TokenIconResolver.resolveTokenIconUrl(
            address: token0Id,
            symbol: symbol0,
            iconUrl: icon0,
          ),
          TokenIconResolver.resolveTokenIconUrl(
            address: token1Id,
            symbol: symbol1,
            iconUrl: icon1,
          ),
        ],
      );
    }).toList();
    if (mapped.isEmpty) {
      return _loadLocalPoolsFallback();
    }
    return mapped;
  }

  Future<List<PoolTransactionEvent>> getPairTransactions(
    String pairId, {
    int first = 250,
  }) async {
    final normalizedPairId = pairId.trim().toLowerCase();
    if (normalizedPairId.isEmpty) return const <PoolTransactionEvent>[];

    const query = r'''
      query PairTransactions($pairId: String!, $first: Int!) {
        swaps(first: $first, where: { pair: $pairId }, orderBy: timestamp, orderDirection: asc) {
          id
          timestamp
          amount0In
          amount1In
          amount0Out
          amount1Out
          amountUSD
          transaction { id }
        }
        mints(first: $first, where: { pair: $pairId }, orderBy: timestamp, orderDirection: asc) {
          id
          timestamp
          amount0
          amount1
          amountUSD
          transaction { id }
        }
        burns(first: $first, where: { pair: $pairId }, orderBy: timestamp, orderDirection: asc) {
          id
          timestamp
          amount0
          amount1
          amountUSD
          transaction { id }
        }
      }
    ''';

    final response = await _postWithEndpointFallback(
      query,
      variables: <String, dynamic>{'pairId': normalizedPairId, 'first': first},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <PoolTransactionEvent>[];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const <PoolTransactionEvent>[];
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      return const <PoolTransactionEvent>[];
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return const <PoolTransactionEvent>[];

    final swaps = _parseSwapEvents(data['swaps']);
    final mints = _parseMintBurnEvents(
      data['mints'],
      type: PoolTransactionType.mint,
    );
    final burns = _parseMintBurnEvents(
      data['burns'],
      type: PoolTransactionType.burn,
    );
    final all = <PoolTransactionEvent>[...swaps, ...mints, ...burns]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  Future<double> getReefUsdPrice() async {
    const gateTicker =
        'https://api.gateio.ws/api/v4/spot/tickers?currency_pair=REEF_USDT';
    try {
      final response = await _client
          .get(
            Uri.parse(gateTicker),
            headers: const {'accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _defaultReefUsd;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return _defaultReefUsd;
      final first = decoded.first;
      if (first is! Map<String, dynamic>) return _defaultReefUsd;

      final price = _parseDouble(first['last']);
      if (price <= 0 || !price.isFinite) return _defaultReefUsd;
      return price;
    } catch (_) {
      return _defaultReefUsd;
    }
  }

  Future<Map<String, double>> getTokenUsdPrices() async {
    const query = r'''
      query TokenPrices {
        pairs(first: 300, orderBy: reserveUSD, orderDirection: desc) {
          id
          reserveUSD
          reserve0
          reserve1
          token0 { id symbol }
          token1 { id symbol }
        }
      }
    ''';

    final response = await _postWithEndpointFallback(query);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _loadLocalTokenUsdFallback();
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return _loadLocalTokenUsdFallback();
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty)
      return _loadLocalTokenUsdFallback();

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return _loadLocalTokenUsdFallback();
    final pairs = data['pairs'];
    if (pairs is! List || pairs.isEmpty) return _loadLocalTokenUsdFallback();

    final reefUsd = await getReefUsdPrice();
    final priceByToken = <String, _WeightedPrice>{};

    for (final item in pairs) {
      if (item is! Map<String, dynamic>) continue;
      final token0 = item['token0'];
      final token1 = item['token1'];
      if (token0 is! Map<String, dynamic> || token1 is! Map<String, dynamic>) {
        continue;
      }

      final token0Id = _normalizeAddress(token0['id']?.toString() ?? '');
      final token1Id = _normalizeAddress(token1['id']?.toString() ?? '');
      if (token0Id.isEmpty || token1Id.isEmpty) continue;

      final token0Symbol = token0['symbol']?.toString() ?? '';
      final token1Symbol = token1['symbol']?.toString() ?? '';
      final token0IsReef = _isReefLike(token0Symbol);
      final token1IsReef = _isReefLike(token1Symbol);

      final reserve0 = _parseDouble(item['reserve0']);
      final reserve1 = _parseDouble(item['reserve1']);
      final reserveUsd = _parseDouble(item['reserveUSD']);

      if (reserve0 <= 0 || reserve1 <= 0) continue;

      final token0PriceInToken1 = reserve1 / reserve0;
      final token1PriceInToken0 = reserve0 / reserve1;
      var token0Usd = 0.0;
      var token1Usd = 0.0;

      if (token0IsReef) {
        token0Usd = reefUsd;
        token1Usd = token1PriceInToken0 > 0
            ? token1PriceInToken0 * token0Usd
            : 0;
      } else if (token1IsReef) {
        token1Usd = reefUsd;
        token0Usd = token0PriceInToken1 > 0
            ? token0PriceInToken1 * token1Usd
            : 0;
      }

      if ((token0Usd <= 0 || token1Usd <= 0) && reserveUsd > 0) {
        if (token0PriceInToken1 > 0) {
          final token1UsdFromTotal =
              reserveUsd / ((reserve0 * token0PriceInToken1) + reserve1);
          if (token1UsdFromTotal.isFinite && token1UsdFromTotal > 0) {
            token1Usd = token1UsdFromTotal;
            token0Usd = token0PriceInToken1 * token1UsdFromTotal;
          }
        } else if (token1PriceInToken0 > 0) {
          final token0UsdFromTotal =
              reserveUsd / ((reserve1 * token1PriceInToken0) + reserve0);
          if (token0UsdFromTotal.isFinite && token0UsdFromTotal > 0) {
            token0Usd = token0UsdFromTotal;
            token1Usd = token1PriceInToken0 * token0UsdFromTotal;
          }
        }
      }

      if (token0Usd <= 0 && token1Usd > 0 && token0PriceInToken1 > 0) {
        token0Usd = token0PriceInToken1 * token1Usd;
      }
      if (token1Usd <= 0 && token0Usd > 0 && token1PriceInToken0 > 0) {
        token1Usd = token1PriceInToken0 * token0Usd;
      }

      if (token0Usd <= 0 && token1Usd <= 0 && reserveUsd > 0) {
        final avg = reserveUsd / (reserve0 + reserve1);
        if (avg.isFinite && avg > 0) {
          token0Usd = avg;
          token1Usd = avg;
        }
      }

      if (token0Usd > 0 && token0Usd.isFinite) {
        _putWeightedPrice(
          map: priceByToken,
          tokenAddress: token0Id,
          usdPrice: token0Usd,
          weight: reserveUsd,
        );
      }
      if (token1Usd > 0 && token1Usd.isFinite) {
        _putWeightedPrice(
          map: priceByToken,
          tokenAddress: token1Id,
          usdPrice: token1Usd,
          weight: reserveUsd,
        );
      }
    }

    final out = <String, double>{};
    for (final entry in priceByToken.entries) {
      out[entry.key] = entry.value.price;
    }
    return out.isEmpty ? _loadLocalTokenUsdFallback() : out;
  }

  Future<Map<String, String?>> _loadExplorerTokenIcons(
    Iterable<String> addresses,
  ) async {
    final unique = addresses.where((it) => it.trim().isNotEmpty).toSet();
    if (unique.isEmpty) return const <String, String?>{};

    final entries = await Future.wait(
      unique.map((address) async {
        final iconUrl = await _fetchExplorerTokenIconUrl(address);
        return MapEntry<String, String?>(address, iconUrl);
      }),
    );
    return Map<String, String?>.fromEntries(entries);
  }

  Future<String?> _fetchExplorerTokenIconUrl(String address) async {
    final normalized = _normalizeAddress(address);
    if (_tokenIconCache.containsKey(normalized)) {
      return _tokenIconCache[normalized];
    }

    try {
      final response = await _client
          .get(Uri.parse('$_explorerApiV2/tokens/$normalized'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _tokenIconCache[normalized] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _tokenIconCache[normalized] = null;
        return null;
      }

      final iconUrl = decoded['icon_url'];
      if (iconUrl is String && iconUrl.trim().isNotEmpty) {
        final normalizedUrl = iconUrl.trim();
        _tokenIconCache[normalized] = normalizedUrl;
        return normalizedUrl;
      }
    } catch (_) {
      // Icon lookup failures should not break pools loading.
    }

    _tokenIconCache[normalized] = null;
    return null;
  }

  Future<http.Response> _postWithEndpointFallback(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
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
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {'content-type': 'application/json'},
              body: jsonEncode(<String, dynamic>{
                'query': query,
                if (variables != null) 'variables': variables,
              }),
            )
            .timeout(const Duration(seconds: 15));
        lastResponse = response;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
      } catch (_) {
        continue;
      }
    }

    return lastResponse ??
        http.Response(
          '{"errors":[{"message":"No subgraph endpoint available"}]}',
          500,
        );
  }

  Future<List<Pool>> _loadLocalPoolsFallback() async {
    if (_localPairAddress.trim().isEmpty) return const <Pool>[];

    final rpcClient = http.Client();
    final web3 = Web3Client(_localRpcUrl, rpcClient);
    try {
      const pairAbi = '''
        [{"inputs":[],"name":"getReserves","outputs":[{"internalType":"uint112","name":"reserve0","type":"uint112"},{"internalType":"uint112","name":"reserve1","type":"uint112"},{"internalType":"uint32","name":"blockTimestampLast","type":"uint32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"token0","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"token1","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"}]
      ''';
      const erc20MetaAbi = '''
        [{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"stateMutability":"view","type":"function"}]
      ''';

      final pairContract = DeployedContract(
        ContractAbi.fromJson(pairAbi, 'ReefswapPair'),
        EthereumAddress.fromHex(_localPairAddress),
      );
      final token0Fn = pairContract.function('token0');
      final token1Fn = pairContract.function('token1');
      final reservesFn = pairContract.function('getReserves');

      final token0Address =
          (await web3.call(
                contract: pairContract,
                function: token0Fn,
                params: const <dynamic>[],
              )).first
              as EthereumAddress;
      final token1Address =
          (await web3.call(
                contract: pairContract,
                function: token1Fn,
                params: const <dynamic>[],
              )).first
              as EthereumAddress;
      final reserves = await web3.call(
        contract: pairContract,
        function: reservesFn,
        params: const <dynamic>[],
      );
      final reserve0Raw = reserves[0] as BigInt;
      final reserve1Raw = reserves[1] as BigInt;

      final token0Meta = await _loadLocalTokenMetadata(
        web3: web3,
        abiJson: erc20MetaAbi,
        address: token0Address,
      );
      final token1Meta = await _loadLocalTokenMetadata(
        web3: web3,
        abiJson: erc20MetaAbi,
        address: token1Address,
      );

      final reserve0 = _rawToDecimal(reserve0Raw, token0Meta.decimals);
      final reserve1 = _rawToDecimal(reserve1Raw, token1Meta.decimals);
      final reefUsd = await getReefUsdPrice();
      final token0IsReef = _isReefLike(token0Meta.symbol);
      final token1IsReef = _isReefLike(token1Meta.symbol);
      var token0PriceUsd = 0.0;
      var token1PriceUsd = 0.0;
      if (token0IsReef && reserve0 > 0 && reserve1 > 0) {
        token0PriceUsd = reefUsd;
        token1PriceUsd = (reserve0 / reserve1) * reefUsd;
      } else if (token1IsReef && reserve0 > 0 && reserve1 > 0) {
        token1PriceUsd = reefUsd;
        token0PriceUsd = (reserve1 / reserve0) * reefUsd;
      }
      final reserveUsd =
          (reserve0 * token0PriceUsd) + (reserve1 * token1PriceUsd);

      return <Pool>[
        Pool(
          id: _localPairAddress.trim().toLowerCase(),
          pairName: '${token0Meta.symbol} - ${token1Meta.symbol}',
          token0Symbol: token0Meta.symbol,
          token1Symbol: token1Meta.symbol,
          token0Address: token0Address.hexEip55.toLowerCase(),
          token1Address: token1Address.hexEip55.toLowerCase(),
          token0Decimals: token0Meta.decimals,
          token1Decimals: token1Meta.decimals,
          tvl: _formatCompactUsd(reserveUsd),
          volume24h: _formatCompactUsd(0),
          reserve0: reserve0,
          reserve1: reserve1,
          reserveUsd: reserveUsd,
          volumeUsd: 0,
          token0Price: token0PriceUsd,
          token1Price: token1PriceUsd,
          percentChange: 0,
          tokenIcons: <String>[
            TokenIconResolver.resolveTokenIconUrl(
              address: token0Address.hexEip55,
              symbol: token0Meta.symbol,
            ),
            TokenIconResolver.resolveTokenIconUrl(
              address: token1Address.hexEip55,
              symbol: token1Meta.symbol,
            ),
          ],
        ),
      ];
    } catch (_) {
      return const <Pool>[];
    } finally {
      web3.dispose();
      rpcClient.close();
    }
  }

  Future<Map<String, double>> _loadLocalTokenUsdFallback() async {
    final pools = await _loadLocalPoolsFallback();
    if (pools.isEmpty) return const <String, double>{};
    final first = pools.first;
    final prices = <String, double>{};
    if (first.token0Address.trim().isNotEmpty && first.token0Price > 0) {
      prices[first.token0Address.trim().toLowerCase()] = first.token0Price;
    }
    if (first.token1Address.trim().isNotEmpty && first.token1Price > 0) {
      prices[first.token1Address.trim().toLowerCase()] = first.token1Price;
    }
    if (_localWrappedAddress.trim().isNotEmpty &&
        !prices.containsKey(_localWrappedAddress.trim().toLowerCase())) {
      prices[_localWrappedAddress.trim().toLowerCase()] =
          await getReefUsdPrice();
    }
    return prices;
  }

  Future<_LocalTokenMetadata> _loadLocalTokenMetadata({
    required Web3Client web3,
    required String abiJson,
    required EthereumAddress address,
  }) async {
    final normalized = address.hexEip55.toLowerCase();
    final fallbackSymbol =
        normalized == _localWrappedAddress.trim().toLowerCase()
        ? 'WREEF'
        : normalized == _localTokenAddress.trim().toLowerCase()
        ? 'GST'
        : 'TOKEN';
    final contract = DeployedContract(
      ContractAbi.fromJson(abiJson, 'ERC20Meta'),
      address,
    );

    Future<T?> tryCall<T>(ContractFunction function) async {
      try {
        final result = await web3.call(
          contract: contract,
          function: function,
          params: const <dynamic>[],
        );
        if (result.isEmpty) return null;
        return result.first as T;
      } catch (_) {
        return null;
      }
    }

    final symbol = (await tryCall<String>(
      contract.function('symbol'),
    ))?.trim().toUpperCase();
    final name = (await tryCall<String>(contract.function('name')))?.trim();
    final decimalsValue = await tryCall<BigInt>(contract.function('decimals'));

    return _LocalTokenMetadata(
      symbol: symbol?.isNotEmpty == true ? symbol! : fallbackSymbol,
      name: name?.isNotEmpty == true ? name! : fallbackSymbol,
      decimals: decimalsValue?.toInt() ?? 18,
    );
  }

  static double _rawToDecimal(BigInt value, int decimals) {
    if (value == BigInt.zero) return 0;
    return value.toDouble() / BigInt.from(10).pow(decimals).toDouble();
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _formatCompactUsd(double amount) {
    return NumberFormat.compactCurrency(
      symbol: '\$',
      decimalDigits: amount >= 1000 ? 1 : 2,
    ).format(amount);
  }

  static String _normalizeAddress(String value) {
    return value.trim().toLowerCase();
  }

  static bool _isReefLike(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    return normalized == 'REEF' || normalized == 'WREEF';
  }

  static void _putWeightedPrice({
    required Map<String, _WeightedPrice> map,
    required String tokenAddress,
    required double usdPrice,
    required double weight,
  }) {
    final normalizedWeight = weight > 0 && weight.isFinite ? weight : 1.0;
    final current = map[tokenAddress];
    if (current == null || normalizedWeight >= current.weight) {
      map[tokenAddress] = _WeightedPrice(
        price: usdPrice,
        weight: normalizedWeight,
      );
    }
  }

  static List<PoolTransactionEvent> _parseSwapEvents(dynamic source) {
    if (source is! List) return const <PoolTransactionEvent>[];
    return source.whereType<Map<String, dynamic>>().map((item) {
      final amount0In = _parseDouble(item['amount0In']);
      final amount1In = _parseDouble(item['amount1In']);
      final amount0Out = _parseDouble(item['amount0Out']);
      final amount1Out = _parseDouble(item['amount1Out']);
      final token0Amount = amount0In > 0 ? amount0In : amount0Out;
      final token1Amount = amount1In > 0 ? amount1In : amount1Out;
      final tx = item['transaction'] as Map<String, dynamic>? ?? const {};
      return PoolTransactionEvent(
        id: (item['id'] ?? '').toString(),
        type: PoolTransactionType.swap,
        timestamp: _parseInt(item['timestamp']),
        token0Amount: token0Amount,
        token1Amount: token1Amount,
        usdAmount: _parseDouble(item['amountUSD']),
        transactionHash: (tx['id'] ?? '').toString(),
      );
    }).toList();
  }

  static List<PoolTransactionEvent> _parseMintBurnEvents(
    dynamic source, {
    required PoolTransactionType type,
  }) {
    if (source is! List) return const <PoolTransactionEvent>[];
    return source.whereType<Map<String, dynamic>>().map((item) {
      final tx = item['transaction'] as Map<String, dynamic>? ?? const {};
      return PoolTransactionEvent(
        id: (item['id'] ?? '').toString(),
        type: type,
        timestamp: _parseInt(item['timestamp']),
        token0Amount: _parseDouble(item['amount0']),
        token1Amount: _parseDouble(item['amount1']),
        usdAmount: _parseDouble(item['amountUSD']),
        transactionHash: (tx['id'] ?? '').toString(),
      );
    }).toList();
  }
}

class _WeightedPrice {
  const _WeightedPrice({required this.price, required this.weight});

  final double price;
  final double weight;
}

class _LocalTokenMetadata {
  const _LocalTokenMetadata({
    required this.symbol,
    required this.name,
    required this.decimals,
  });

  final String symbol;
  final String name;
  final int decimals;
}
