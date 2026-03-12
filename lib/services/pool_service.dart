import '../models/pool.dart';

class PoolService {
  Future<List<Pool>> getPools() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock Data based on requirement
    return [
      Pool(
        pairName: "Reef - CS2",
        tvl: "\$1.2M",
        volume24h: "\$340K",
        percentChange: 2.4,
        tokenIcons: [
          "assets/reef.png",
          "assets/cs2.png",
        ], // Will use fallback if not exists
      ),
      Pool(
        pairName: "Reef - SOON",
        tvl: "\$800K",
        volume24h: "\$120K",
        percentChange: -1.2,
        tokenIcons: ["assets/reef.png", "assets/soon.png"],
      ),
      Pool(
        pairName: "Reef - Pirate Coin",
        tvl: "\$5.5M",
        volume24h: "\$2.1M",
        percentChange: 14.5,
        tokenIcons: ["assets/reef.png", "assets/pirate.png"],
      ),
      Pool(
        pairName: "Reef - Poseidon",
        tvl: "\$450K",
        volume24h: "\$50K",
        percentChange: 0.5,
        tokenIcons: ["assets/reef.png", "assets/poseidon.png"],
      ),
      Pool(
        pairName: "Pirate Coin - WaveCoin",
        tvl: "\$2.2M",
        volume24h: "\$900K",
        percentChange: 8.4,
        tokenIcons: ["assets/pirate.png", "assets/wave.png"],
      ),
      Pool(
        pairName: "Wrapped BTC - Wrapped ETH",
        tvl: "\$12.5M",
        volume24h: "\$4.5M",
        percentChange: 1.1,
        tokenIcons: ["assets/wbtc.png", "assets/weth.png"],
      ),
    ];
  }
}
