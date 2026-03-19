class DappTransactionRequest {
  const DappTransactionRequest({
    this.from,
    this.to,
    required this.valueWei,
    this.dataHex,
    this.gasLimit,
    this.gasPriceWei,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.nonce,
    this.chainId,
  });

  final String? from;
  final String? to;
  final BigInt valueWei;
  final String? dataHex;
  final int? gasLimit;
  final BigInt? gasPriceWei;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final int? nonce;
  final int? chainId;

  bool get isContractCall =>
      (dataHex?.trim().isNotEmpty ?? false) && (dataHex?.trim() != '0x');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'from': from,
      'to': to,
      'valueWei': valueWei.toString(),
      'dataHex': dataHex,
      'gasLimit': gasLimit,
      'gasPriceWei': gasPriceWei?.toString(),
      'maxFeePerGasWei': maxFeePerGasWei?.toString(),
      'maxPriorityFeePerGasWei': maxPriorityFeePerGasWei?.toString(),
      'nonce': nonce,
      'chainId': chainId,
    };
  }

  factory DappTransactionRequest.fromRpc(Map<String, dynamic> json) {
    return DappTransactionRequest(
      from: _normalizeOptionalString(json['from']),
      to: _normalizeOptionalString(json['to']),
      valueWei: _parseBigInt(json['value']) ?? BigInt.zero,
      dataHex:
          _normalizeOptionalString(json['data']) ??
          _normalizeOptionalString(json['input']),
      gasLimit: _parseBigInt(json['gas'])?.toInt(),
      gasPriceWei: _parseBigInt(json['gasPrice']),
      maxFeePerGasWei: _parseBigInt(json['maxFeePerGas']),
      maxPriorityFeePerGasWei: _parseBigInt(json['maxPriorityFeePerGas']),
      nonce: _parseBigInt(json['nonce'])?.toInt(),
      chainId: _parseBigInt(json['chainId'])?.toInt(),
    );
  }

  static BigInt? _parseBigInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is BigInt) return raw;
    if (raw is int) return BigInt.from(raw);
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      if (text.startsWith('0x') || text.startsWith('0X')) {
        return BigInt.tryParse(text.substring(2), radix: 16);
      }
      return BigInt.tryParse(text);
    }
    return null;
  }

  static String? _normalizeOptionalString(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }
}
