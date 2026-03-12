import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/pool_provider.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_components.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsyncValue = ref.watch(poolsProvider);
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: Styles.primaryBackgroundColor,
      body: Column(
        children: [
          Material(
            elevation: 3,
            shadowColor: Colors.black45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/reef-header.png"),
                  fit: BoxFit.cover,
                  alignment: Alignment(-0.82, 1.0),
                ),
              ),
              child: topBar(
                context,
                walletState.activeAccount?.address,
                'Account 1',
              ),
            ),
          ),
          const Gap(16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Token Pools',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Styles.primaryColor),
              ),
            ),
          ),
          const Gap(8),
          Expanded(
            child: poolsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (pools) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pools.length,
                  itemBuilder: (context, index) {
                    final pool = pools[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ViewBoxContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 60,
                                height: 40,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.blueAccent,
                                        child: Text(pool.pairName[0], style: const TextStyle(fontSize: 12, color: Colors.white)),
                                      ),
                                    ),
                                    Positioned(
                                      left: 18,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.purpleAccent,
                                        child: Text(pool.pairName.split('-').last.trim()[0], style: const TextStyle(fontSize: 12, color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pool.pairName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Styles.textColor)),
                                    Text("TVL: ${pool.tvl}", style: const TextStyle(color: Styles.textLightColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${pool.percentChange > 0 ? '+' : ''}${pool.percentChange}%",
                                    style: TextStyle(
                                      color: pool.percentChange >= 0 ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text("Vol: ${pool.volume24h}", style: const TextStyle(color: Styles.textLightColor, fontSize: 12)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
