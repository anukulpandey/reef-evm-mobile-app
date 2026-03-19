class TokenCreatorRequest {
  const TokenCreatorRequest({
    required this.name,
    required this.symbol,
    required this.initialSupply,
    required this.burnable,
    required this.mintable,
    this.iconUrl = '',
  });

  final String name;
  final String symbol;
  final String initialSupply;
  final bool burnable;
  final bool mintable;
  final String iconUrl;

  String get normalizedName => name.trim();

  String get normalizedSymbol => symbol.trim().toUpperCase();

  String? get normalizedIconUrl {
    final value = iconUrl.trim();
    return value.isEmpty ? null : value;
  }

  TokenCreatorRequest copyWith({
    String? name,
    String? symbol,
    String? initialSupply,
    bool? burnable,
    bool? mintable,
    String? iconUrl,
  }) {
    return TokenCreatorRequest(
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      initialSupply: initialSupply ?? this.initialSupply,
      burnable: burnable ?? this.burnable,
      mintable: mintable ?? this.mintable,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }
}
