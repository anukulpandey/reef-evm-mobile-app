class Pool {
  final String id;
  final String pairName;
  final String token0Symbol;
  final String token1Symbol;
  final String token0Address;
  final String token1Address;
  final int token0Decimals;
  final int token1Decimals;
  final String tvl;
  final String volume24h;
  final double reserve0;
  final double reserve1;
  final double reserveUsd;
  final double volumeUsd;
  final double token0Price;
  final double token1Price;
  final double percentChange;
  final List<String> tokenIcons;

  Pool({
    required this.id,
    required this.pairName,
    required this.token0Symbol,
    required this.token1Symbol,
    required this.token0Address,
    required this.token1Address,
    required this.token0Decimals,
    required this.token1Decimals,
    required this.tvl,
    required this.volume24h,
    required this.reserve0,
    required this.reserve1,
    required this.reserveUsd,
    required this.volumeUsd,
    required this.token0Price,
    required this.token1Price,
    required this.percentChange,
    required this.tokenIcons,
  });
}
