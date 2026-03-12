class Token {
  final String symbol;
  final String name;
  final int decimals;
  final String balance;
  final String address; // contract address or 'native'
  final String? iconUrl;
  final double? usdPrice;
  final double? usdValue;

  Token({
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.balance,
    required this.address,
    this.iconUrl,
    this.usdPrice,
    this.usdValue,
  });

  Token copyWith({
    String? symbol,
    String? name,
    int? decimals,
    String? balance,
    String? address,
    String? iconUrl,
    double? usdPrice,
    double? usdValue,
  }) {
    return Token(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      decimals: decimals ?? this.decimals,
      balance: balance ?? this.balance,
      address: address ?? this.address,
      iconUrl: iconUrl ?? this.iconUrl,
      usdPrice: usdPrice ?? this.usdPrice,
      usdValue: usdValue ?? this.usdValue,
    );
  }
}
