class Pool {
  final String pairName;
  final String tvl;
  final String volume24h;
  final double percentChange;
  final List<String> tokenIcons;

  Pool({
    required this.pairName,
    required this.tvl,
    required this.volume24h,
    required this.percentChange,
    required this.tokenIcons,
  });
}
