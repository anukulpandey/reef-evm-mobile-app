class TransactionPreviewField {
  const TransactionPreviewField({required this.label, required this.value});

  final String label;
  final String value;
}

class TransactionPreview {
  const TransactionPreview({
    required this.title,
    required this.methodName,
    required this.recipientAddress,
    required this.amountDisplay,
    required this.networkName,
    required this.chainId,
    this.recipientLabel = 'Recipient',
    this.contractAddress,
    this.gasLimit,
    this.gasPriceWei,
    this.estimatedFeeDisplay,
    this.fields = const <TransactionPreviewField>[],
    this.calldataHex,
  });

  final String title;
  final String methodName;
  final String recipientAddress;
  final String amountDisplay;
  final String networkName;
  final int chainId;
  final String recipientLabel;
  final String? contractAddress;
  final int? gasLimit;
  final BigInt? gasPriceWei;
  final String? estimatedFeeDisplay;
  final List<TransactionPreviewField> fields;
  final String? calldataHex;
}

class TransactionApprovalResult {
  const TransactionApprovalResult({required this.approved, this.txHash});

  final bool approved;
  final String? txHash;
}
