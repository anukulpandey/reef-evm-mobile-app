import 'package:flutter/foundation.dart';

enum ActivityItemType { sent, received, swap }

@immutable
class ActivitySwapDetails {
  const ActivitySwapDetails({
    required this.fromAmount,
    required this.fromSymbol,
    required this.fromTokenAddress,
    required this.toAmount,
    required this.toSymbol,
    required this.toTokenAddress,
    required this.feeAmount,
    required this.feeSymbol,
  });

  final double fromAmount;
  final String fromSymbol;
  final String? fromTokenAddress;
  final double toAmount;
  final String toSymbol;
  final String? toTokenAddress;
  final double feeAmount;
  final String feeSymbol;
}

@immutable
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.symbol,
    required this.timestamp,
    required this.isNativeAsset,
    this.txHash,
    this.tokenAddress,
    this.tokenIconUrl,
    this.swapDetails,
  });

  final String id;
  final String? txHash;
  final String? tokenAddress;
  final String? tokenIconUrl;
  final bool isNativeAsset;
  final ActivityItemType type;
  final double amount;
  final String symbol;
  final DateTime timestamp;
  final ActivitySwapDetails? swapDetails;
}
