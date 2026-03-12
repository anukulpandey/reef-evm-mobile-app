enum PoolTransactionType { swap, mint, burn }

class PoolTransactionEvent {
  const PoolTransactionEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.token0Amount,
    required this.token1Amount,
    required this.usdAmount,
    required this.transactionHash,
  });

  final String id;
  final PoolTransactionType type;
  final int timestamp;
  final double token0Amount;
  final double token1Amount;
  final double usdAmount;
  final String transactionHash;
}
