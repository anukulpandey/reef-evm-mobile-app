import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../core/config/dex_config.dart';
import '../models/activity_item.dart';
import '../utils/amount_utils.dart';
import '../utils/token_icon_resolver.dart';

class ActivityService {
  ActivityService({
    http.Client? client,
    String? explorerApiV2,
    String? explorerBaseUrl,
    String? subgraphEndpoint,
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
           ),
       _subgraphEndpoint =
           subgraphEndpoint ??
           const String.fromEnvironment(
             'SUBGRAPH_GRAPHQL_ENDPOINT',
             defaultValue:
                 'http://127.0.0.1:8000/subgraphs/name/uniswap-v2-localhost',
           );

  final http.Client _client;
  final String _explorerApiV2;
  final String _explorerBaseUrl;
  final String _subgraphEndpoint;

  static const int _reefDecimals = 18;
  static const String _reefSymbol = 'REEF';
  static const String _wreefSymbol = 'WREEF';
  static const String _zeroAddress =
      '0x0000000000000000000000000000000000000000';
  static const int _swapSequenceWindowMs = 120000;
  static const String _accountSwapsQuery = r'''
    query AccountSwaps($address: String!, $first: Int!) {
      senderSwaps: swaps(
        first: $first
        where: { sender: $address }
        orderBy: timestamp
        orderDirection: desc
      ) {
        id
        timestamp
        sender
        to
        amount0In
        amount1In
        amount0Out
        amount1Out
        amountUSD
        pair {
          id
          token0 { id symbol decimals }
          token1 { id symbol decimals }
        }
        transaction { id }
      }
      receiverSwaps: swaps(
        first: $first
        where: { to: $address }
        orderBy: timestamp
        orderDirection: desc
      ) {
        id
        timestamp
        sender
        to
        amount0In
        amount1In
        amount0Out
        amount1Out
        amountUSD
        pair {
          id
          token0 { id symbol decimals }
          token1 { id symbol decimals }
        }
        transaction { id }
      }
    }
  ''';

  String get explorerBaseUrl =>
      _explorerBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  String accountExplorerUrl(String address) =>
      '$explorerBaseUrl/account/$address';

  String transactionExplorerUrl(String hash) => '$explorerBaseUrl/tx/$hash';

  Future<List<ActivityItem>> fetchActivity(String address) async {
    final normalizedAddress = address.trim().toLowerCase();
    if (normalizedAddress.isEmpty) return const <ActivityItem>[];

    final responses = await Future.wait<dynamic>(<Future<dynamic>>[
      _getJson('$_explorerApiV2/addresses/$normalizedAddress/transactions'),
      _getJson('$_explorerApiV2/addresses/$normalizedAddress/token-transfers'),
      _fetchSubgraphAccountSwaps(normalizedAddress),
    ]);

    final txPayload = responses[0];
    final transfersPayload = responses[1];
    final subgraphSwaps = responses[2] as List<Map<String, dynamic>>;

    final txItems = _extractItems(txPayload);
    final transferItems = _extractItems(transfersPayload);

    final txMetaByHash = <String, _TransactionMeta>{};
    for (final tx in txItems) {
      final hash = _asString(tx['hash']).toLowerCase();
      if (hash.isEmpty) continue;
      txMetaByHash[hash] = _TransactionMeta(
        timestampMs: _toTimestampMs(tx['timestamp']),
        feeAmount: _resolveTransactionFee(tx),
      );
    }

    final nativeTransactions = txItems
        .map((tx) => _mapNativeTransaction(tx, normalizedAddress))
        .whereType<_MappedActivityItem>()
        .toList();
    final erc20Transfers = transferItems
        .map((transfer) => _mapErc20Transfer(transfer, normalizedAddress))
        .whereType<_MappedActivityItem>()
        .toList();

    final sortedRaw = <_MappedActivityItem>[
      ...erc20Transfers,
      ...nativeTransactions,
    ]..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

    final txEntriesByHash = <String, List<_MappedActivityItem>>{};
    for (final tx in sortedRaw) {
      final hash = tx.txHash?.toLowerCase();
      if (hash == null || hash.isEmpty) continue;
      txEntriesByHash.putIfAbsent(hash, () => <_MappedActivityItem>[]).add(tx);
    }

    final consumedIds = <String>{};
    final merged = <_MappedActivityItem>[];
    final normalizedSwaps =
        subgraphSwaps
            .map(_normalizeSubgraphSwap)
            .whereType<_NormalizedSubgraphSwap>()
            .toList()
          ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

    final wrappedReef = DexConfig.wrappedReefAddress.toLowerCase();

    for (final swap in normalizedSwaps) {
      final txHashLower = swap.txHash.toLowerCase();
      final relatedHashes = <String>{txHashLower};

      final directEntries =
          txEntriesByHash[txHashLower] ?? const <_MappedActivityItem>[];
      for (final entry in directEntries) {
        consumedIds.add(entry.id);
      }

      void consumeWrapLegs(double amount) {
        for (final candidate in sortedRaw) {
          if (consumedIds.contains(candidate.id)) continue;
          if (!_isReefSymbol(candidate.symbol)) continue;

          final deltaMs = (candidate.timestampMs - swap.timestampMs).abs();
          if (deltaMs > _swapSequenceWindowMs) continue;
          if (!_isAmountRoughlyEqual(candidate.amount, amount)) continue;

          final candidateFrom = _toLowerAddress(candidate.fromAddress);
          final candidateTo = _toLowerAddress(candidate.toAddress);
          final isNativeWrap =
              candidate.isNativeAsset &&
              candidate.type == ActivityItemType.sent &&
              candidateTo == wrappedReef;
          final isMintWrap =
              candidate.type == ActivityItemType.received &&
              candidateFrom == _zeroAddress;
          final isWreefTransfer =
              candidate.type == ActivityItemType.sent &&
              candidateTo == wrappedReef;

          if (isNativeWrap || isMintWrap || isWreefTransfer) {
            consumedIds.add(candidate.id);
            final hash = candidate.txHash?.toLowerCase();
            if (hash != null && hash.isNotEmpty) {
              relatedHashes.add(hash);
            }
          }
        }
      }

      if (_isReefSymbol(swap.fromSymbol)) {
        consumeWrapLegs(swap.fromAmount);
      }
      if (_isReefSymbol(swap.toSymbol)) {
        consumeWrapLegs(swap.toAmount);
      }

      final feeAmount = relatedHashes.fold<double>(
        0,
        (sum, hash) => sum + (txMetaByHash[hash]?.feeAmount ?? 0),
      );

      merged.add(
        _MappedActivityItem(
          item: ActivityItem(
            id: 'swap:$txHashLower',
            txHash: swap.txHash,
            tokenAddress: swap.toTokenAddress,
            tokenIconUrl: TokenIconResolver.resolveTokenIconUrl(
              address: swap.toTokenAddress,
              symbol: swap.toSymbol,
            ),
            isNativeAsset: false,
            type: ActivityItemType.swap,
            amount: swap.toAmount,
            symbol: swap.toSymbol,
            timestamp: DateTime.fromMillisecondsSinceEpoch(swap.timestampMs),
            swapDetails: ActivitySwapDetails(
              fromAmount: swap.fromAmount,
              fromSymbol: swap.fromSymbol,
              fromTokenAddress: swap.fromTokenAddress,
              toAmount: swap.toAmount,
              toSymbol: swap.toSymbol,
              toTokenAddress: swap.toTokenAddress,
              feeAmount: feeAmount,
              feeSymbol: _reefSymbol,
            ),
          ),
          timestampMs: swap.timestampMs,
        ),
      );
    }

    for (final tx in sortedRaw) {
      if (consumedIds.contains(tx.id)) continue;
      merged.add(tx);
    }

    merged.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return merged.take(80).map((entry) => entry.item).toList(growable: false);
  }

  Future<dynamic> _getJson(String url) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: const <String, String>{'accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <String, dynamic>{'items': <dynamic>[]};
      }
      return jsonDecode(response.body);
    } catch (_) {
      return const <String, dynamic>{'items': <dynamic>[]};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSubgraphAccountSwaps(
    String address,
  ) async {
    try {
      final response = await _postWithEndpointFallback(
        _accountSwapsQuery,
        variables: <String, dynamic>{'address': address, 'first': 120},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>)
        return const <Map<String, dynamic>>[];
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        return const <Map<String, dynamic>>[];
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return const <Map<String, dynamic>>[];

      final swaps = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      for (final key in const <String>['senderSwaps', 'receiverSwaps']) {
        final items = data[key];
        if (items is! List) continue;
        for (final item in items.whereType<Map<String, dynamic>>()) {
          final id = _asString(item['id']);
          if (id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);
          swaps.add(item);
        }
      }
      return swaps;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<http.Response> _postWithEndpointFallback(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final endpoints = <String>{
      _subgraphEndpoint,
      if (_subgraphEndpoint.endsWith('/graphql'))
        _subgraphEndpoint.substring(
          0,
          _subgraphEndpoint.length - '/graphql'.length,
        ),
    };

    http.Response? lastResponse;
    for (final endpoint in endpoints) {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{'content-type': 'application/json'},
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
    }

    return lastResponse ??
        http.Response(
          '{"errors":[{"message":"No subgraph endpoint available"}]}',
          500,
        );
  }

  List<Map<String, dynamic>> _extractItems(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final items = payload['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  _MappedActivityItem? _mapNativeTransaction(
    Map<String, dynamic> tx,
    String lowerAddress,
  ) {
    final valueRaw = AmountUtils.parsePositiveBigInt(tx['value']);
    if (valueRaw <= BigInt.zero) return null;

    final fromHash = _asNestedString(tx, 'from', 'hash');
    final toHash = _asNestedString(tx, 'to', 'hash');
    final isSent = fromHash.toLowerCase() == lowerAddress;
    final timestampMs = _toTimestampMs(tx['timestamp']);

    return _MappedActivityItem(
      item: ActivityItem(
        id: 'native:${_asString(tx['hash'])}',
        txHash: _asString(tx['hash']),
        tokenAddress: null,
        tokenIconUrl: null,
        isNativeAsset: true,
        type: isSent ? ActivityItemType.sent : ActivityItemType.received,
        amount: _toFiniteNumber(valueRaw, _reefDecimals),
        symbol: _reefSymbol,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      ),
      timestampMs: timestampMs,
      fromAddress: fromHash,
      toAddress: toHash,
    );
  }

  _MappedActivityItem? _mapErc20Transfer(
    Map<String, dynamic> transfer,
    String lowerAddress,
  ) {
    final tokenType = _asString(transfer['token_type']).toUpperCase();
    if (tokenType.isNotEmpty && tokenType != 'ERC-20') return null;

    final fromHash = _asNestedString(transfer, 'from', 'hash');
    final toHash = _asNestedString(transfer, 'to', 'hash');
    final fromLower = fromHash.toLowerCase();
    final toLower = toHash.toLowerCase();
    if (fromLower != lowerAddress && toLower != lowerAddress) return null;

    final amountRaw = AmountUtils.parsePositiveBigInt(
      _asNestedValue(transfer, 'total', 'value'),
    );
    final decimals = _parseDecimals(
      _asNestedValue(transfer, 'total', 'decimals'),
      _reefDecimals,
    );
    final amount = _toFiniteNumber(amountRaw, decimals);
    if (amount <= 0) return null;

    final symbol = _normalizeTokenSymbol(
      _asNestedString(transfer, 'token', 'symbol'),
    );
    final tokenAddress = _asNestedString(
      transfer,
      'token',
      'address_hash',
    ).ifEmpty(_asNestedString(transfer, 'token', 'address'));
    final tokenIconUrl = _asNestedString(transfer, 'token', 'icon_url');
    final timestampMs = _toTimestampMs(transfer['timestamp']);

    final txHash = _asString(transfer['transaction_hash']);
    final logIndex = transfer['log_index']?.toString() ?? '';
    final isSent = fromLower == lowerAddress;

    return _MappedActivityItem(
      item: ActivityItem(
        id: 'erc20:$txHash:$logIndex',
        txHash: txHash.isEmpty ? null : txHash,
        tokenAddress: tokenAddress.isEmpty ? null : tokenAddress,
        tokenIconUrl: TokenIconResolver.resolveTokenIconUrl(
          address: tokenAddress,
          symbol: symbol,
          iconUrl: tokenIconUrl.isEmpty ? null : tokenIconUrl,
        ),
        isNativeAsset: false,
        type: isSent ? ActivityItemType.sent : ActivityItemType.received,
        amount: amount,
        symbol: symbol,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      ),
      timestampMs: timestampMs,
      fromAddress: fromHash,
      toAddress: toHash,
    );
  }

  _NormalizedSubgraphSwap? _normalizeSubgraphSwap(Map<String, dynamic> swap) {
    final txHash = _asNestedString(swap, 'transaction', 'id');
    if (txHash.isEmpty) return null;

    final pair = _asMap(swap['pair']);
    final token0 = _asMap(pair['token0']);
    final token1 = _asMap(pair['token1']);

    final amount0In = _toNumberSafe(swap['amount0In']);
    final amount1In = _toNumberSafe(swap['amount1In']);
    final amount0Out = _toNumberSafe(swap['amount0Out']);
    final amount1Out = _toNumberSafe(swap['amount1Out']);

    double fromAmount;
    String fromSymbol;
    String? fromTokenAddress;
    double toAmount;
    String toSymbol;
    String? toTokenAddress;

    if (amount0In > 0 && amount1Out > 0) {
      fromAmount = amount0In;
      fromSymbol = _normalizeTokenSymbol(token0['symbol']);
      fromTokenAddress = _asString(token0['id']);
      toAmount = amount1Out;
      toSymbol = _normalizeTokenSymbol(token1['symbol']);
      toTokenAddress = _asString(token1['id']);
    } else if (amount1In > 0 && amount0Out > 0) {
      fromAmount = amount1In;
      fromSymbol = _normalizeTokenSymbol(token1['symbol']);
      fromTokenAddress = _asString(token1['id']);
      toAmount = amount0Out;
      toSymbol = _normalizeTokenSymbol(token0['symbol']);
      toTokenAddress = _asString(token0['id']);
    } else {
      final fallbackIn = amount0In > 0
          ? _SwapLeg(
              amount: amount0In,
              symbol: _normalizeTokenSymbol(token0['symbol']),
              tokenAddress: _asString(token0['id']),
            )
          : _SwapLeg(
              amount: amount1In,
              symbol: _normalizeTokenSymbol(token1['symbol']),
              tokenAddress: _asString(token1['id']),
            );
      final fallbackOut = amount0Out > 0
          ? _SwapLeg(
              amount: amount0Out,
              symbol: _normalizeTokenSymbol(token0['symbol']),
              tokenAddress: _asString(token0['id']),
            )
          : _SwapLeg(
              amount: amount1Out,
              symbol: _normalizeTokenSymbol(token1['symbol']),
              tokenAddress: _asString(token1['id']),
            );

      fromAmount = fallbackIn.amount;
      fromSymbol = fallbackIn.symbol;
      fromTokenAddress = fallbackIn.tokenAddress;
      toAmount = fallbackOut.amount;
      toSymbol = fallbackOut.symbol;
      toTokenAddress = fallbackOut.tokenAddress;
    }

    if (fromAmount <= 0 ||
        toAmount <= 0 ||
        fromSymbol.isEmpty ||
        toSymbol.isEmpty ||
        fromSymbol == toSymbol) {
      return null;
    }

    return _NormalizedSubgraphSwap(
      txHash: txHash,
      timestampMs: _toSubgraphTimestampMs(swap['timestamp']),
      fromAmount: fromAmount,
      fromSymbol: fromSymbol,
      fromTokenAddress: _nullIfEmpty(fromTokenAddress),
      toAmount: toAmount,
      toSymbol: toSymbol,
      toTokenAddress: _nullIfEmpty(toTokenAddress),
    );
  }

  double _resolveTransactionFee(Map<String, dynamic> tx) {
    final feeRaw = AmountUtils.parsePositiveBigInt(
      _asNestedValue(tx, 'fee', 'value') ??
          tx['tx_fee'] ??
          tx['transaction_fee'],
    );
    if (feeRaw > BigInt.zero) {
      final feeDecimals = _parseDecimals(
        _asNestedValue(tx, 'fee', 'decimals'),
        _reefDecimals,
      );
      return _toFiniteNumber(feeRaw, feeDecimals);
    }

    final gasPrice = AmountUtils.parsePositiveBigInt(tx['gas_price']);
    final gasUsed = AmountUtils.parsePositiveBigInt(tx['gas_used']);
    if (gasPrice > BigInt.zero && gasUsed > BigInt.zero) {
      return _toFiniteNumber(gasPrice * gasUsed, _reefDecimals);
    }

    return 0;
  }

  int _toTimestampMs(dynamic value) {
    final raw = _asString(value);
    if (raw.isEmpty) return DateTime.now().millisecondsSinceEpoch;
    final parsed = DateTime.tryParse(raw);
    return parsed?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
  }

  int _toSubgraphTimestampMs(dynamic value) {
    final numeric = _toNumberSafe(value);
    if (numeric > 0) {
      if (numeric > 10000000000) return numeric.toInt();
      return (numeric * 1000).toInt();
    }
    return _toTimestampMs(value);
  }

  String formatDate(DateTime timestamp) {
    return DateFormat('MMM d, y').format(timestamp);
  }

  String formatTime(DateTime timestamp) {
    return DateFormat('h:mm a').format(timestamp);
  }

  bool isAmountRoughlyEqual(double a, double b) => _isAmountRoughlyEqual(a, b);

  static bool _isAmountRoughlyEqual(double a, double b) {
    final scale = <double>[a.abs(), b.abs(), 1].reduce((a, b) => a > b ? a : b);
    return (a - b).abs() <= scale * 0.0001;
  }

  static String _normalizeTokenSymbol(dynamic symbol) {
    final normalized = _asString(symbol).toUpperCase();
    return normalized == _wreefSymbol
        ? _reefSymbol
        : normalized.ifEmpty('TOKEN');
  }

  static bool _isReefSymbol(String? symbol) {
    final normalized = _normalizeTokenSymbol(symbol);
    return normalized == _reefSymbol;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return const <String, dynamic>{};
  }

  static dynamic _asNestedValue(
    Map<String, dynamic> source,
    String key,
    String nestedKey,
  ) {
    final nested = source[key];
    if (nested is Map<String, dynamic>) return nested[nestedKey];
    return null;
  }

  static String _asNestedString(
    Map<String, dynamic> source,
    String key,
    String nestedKey,
  ) {
    final value = _asNestedValue(source, key, nestedKey);
    return _asString(value);
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    return value.isEmpty ? null : value;
  }

  static int _parseDecimals(dynamic value, int fallback) {
    final parsed = int.tryParse(_asString(value));
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  static double _toNumberSafe(dynamic value) {
    return double.tryParse(_asString(value)) ?? 0;
  }

  static double _toFiniteNumber(BigInt raw, int decimals) {
    return AmountUtils.parseNumeric(
      AmountUtils.formatAmountFromRaw(raw, decimals, maxPrecision: decimals),
    );
  }

  static String? _toLowerAddress(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class _TransactionMeta {
  const _TransactionMeta({required this.timestampMs, required this.feeAmount});

  final int timestampMs;
  final double feeAmount;
}

class _MappedActivityItem {
  const _MappedActivityItem({
    required this.item,
    required this.timestampMs,
    this.fromAddress,
    this.toAddress,
  });

  final ActivityItem item;
  final int timestampMs;
  final String? fromAddress;
  final String? toAddress;

  String get id => item.id;
  String? get txHash => item.txHash;
  bool get isNativeAsset => item.isNativeAsset;
  ActivityItemType get type => item.type;
  double get amount => item.amount;
  String get symbol => item.symbol;
}

class _NormalizedSubgraphSwap {
  const _NormalizedSubgraphSwap({
    required this.txHash,
    required this.timestampMs,
    required this.fromAmount,
    required this.fromSymbol,
    required this.fromTokenAddress,
    required this.toAmount,
    required this.toSymbol,
    required this.toTokenAddress,
  });

  final String txHash;
  final int timestampMs;
  final double fromAmount;
  final String fromSymbol;
  final String? fromTokenAddress;
  final double toAmount;
  final String toSymbol;
  final String? toTokenAddress;
}

class _SwapLeg {
  const _SwapLeg({
    required this.amount,
    required this.symbol,
    required this.tokenAddress,
  });

  final double amount;
  final String symbol;
  final String? tokenAddress;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
