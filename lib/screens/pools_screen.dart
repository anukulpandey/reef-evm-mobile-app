import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../models/token.dart';
import '../providers/pool_provider.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/pools/create_pool_sheet.dart';
import '../widgets/pools/pool_list_card.dart';
import 'pool_detail_screen.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsyncValue = ref.watch(poolsProvider);
    final walletState = ref.watch(walletProvider);
    final l10n = AppLocalizations.of(context);
    final poolCount = poolsAsyncValue.asData?.value.length;
    final canCreatePool = _countUniqueTokens(walletState.portfolioTokens) >= 2;

    return Scaffold(
      backgroundColor: const Color(0xFF2B0052),
      body: Column(
        children: [
          Material(
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/reef-header.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment(-0.82, 1.0),
                ),
              ),
              child: topBar(
                context,
                walletState.activeAccount?.address,
                walletState.displayAccountName,
              ),
            ),
          ),
          const Gap(10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tokenPools,
                        style: const TextStyle(
                          fontSize: Styles.fsPageTitle,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        poolCount == null
                            ? 'Loading pools...'
                            : '$poolCount pools indexed',
                        style: const TextStyle(
                          color: Color(0xFFCABDE5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB536A5), Color(0xFF6D38BC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x80F17BDC)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2B080314),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _onCreatePoolTap(
                      context,
                      ref,
                      canCreatePool: canCreatePool,
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      canCreatePool ? 'New Pool' : 'Need 2 Tokens',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Expanded(
            child: poolsAsyncValue.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (err, stack) => Center(
                child: Text(
                  '${l10n.errorPrefix}: $err',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              data: (pools) {
                if (pools.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBF9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFD8CDEB)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No pools indexed yet.',
                              style: TextStyle(
                                color: Styles.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Gap(6),
                            const Text(
                              'Create a new pool to bootstrap liquidity on Reef.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Styles.textLightColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Gap(14),
                            ElevatedButton(
                              onPressed: () => _onCreatePoolTap(
                                context,
                                ref,
                                canCreatePool: canCreatePool,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Styles.secondaryAccentColorDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Create Pool',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pools.length,
                  itemBuilder: (context, index) {
                    final pool = pools[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PoolListCard(
                        pool: pool,
                        tvlLabel: l10n.tvlLabel,
                        volume24hLabel: l10n.volume24hLabel,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PoolDetailScreen(pool: pool),
                            ),
                          );
                        },
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

  void _onCreatePoolTap(
    BuildContext context,
    WidgetRef ref, {
    required bool canCreatePool,
  }) {
    if (!canCreatePool) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create at least two tokens first.')),
      );
      return;
    }

    final walletState = ref.read(walletProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePoolSheet(
        portfolioTokens: walletState.portfolioTokens,
        onPoolCreated: () {
          ref.invalidate(poolsProvider);
        },
      ),
    );
  }

  static int _countUniqueTokens(List<Token> tokens) {
    final unique = <String>{};
    for (final token in tokens) {
      final normalizedAddress = token.address.trim().toLowerCase();
      final key =
          normalizedAddress == 'native' || token.symbol.toUpperCase() == 'REEF'
          ? 'native'
          : normalizedAddress;
      unique.add(key);
    }
    return unique.length;
  }
}
