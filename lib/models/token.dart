class Token {
  final String symbol;
  final String name;
  final int decimals;
  final String balance;
  final String address; // contract address or 'native'
  final String? iconUrl;

  Token({
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.balance,
    required this.address,
    this.iconUrl,
  });
}
