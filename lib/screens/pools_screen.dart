import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pool_provider.dart';
import '../widgets/gradient_header.dart';
import '../widgets/glass_card.dart';
import '../core/theme/app_colors.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsyncValue = ref.watch(poolsProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: Text(
              'Token Pools',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
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
                      child: GlassCard(
                        height: 110, // Fixed height for pool cards
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            // Mock Icons Stack
                            SizedBox(
                              width: 60,
                              height: 40,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.blueAccent,
                                      child: Text(pool.pairName[0]),
                                    ),
                                  ),
                                  Positioned(
                                    left: 20,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.purpleAccent,
                                      child: Text(
                                        pool.pairName
                                            .split('-')
                                            .last
                                            .trim()[0],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    pool.pairName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "TVL: ${pool.tvl}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${pool.percentChange > 0 ? '+' : ''}${pool.percentChange}%",
                                  style: TextStyle(
                                    color:
                                        pool.percentChange >= 0
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Vol: ${pool.volume24h}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
