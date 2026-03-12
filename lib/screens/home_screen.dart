import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sliver_tools/sliver_tools.dart';
import '../models/token.dart';
import '../models/pool.dart';
import '../l10n/app_localizations.dart';
import '../core/config/dex_config.dart';
import '../providers/wallet_provider.dart';
import '../providers/pool_provider.dart';
import '../providers/navigation_provider.dart';
import '../core/theme/styles.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_components.dart';
import '../widgets/add_account_modal.dart';
import '../widgets/blurable_content.dart';
import '../widgets/common/token_avatar.dart';
import '../widgets/home/balance_header_delegate.dart';
import 'pool_detail_screen.dart';
import 'send_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        color: Styles.primaryBackgroundColor,
        child: Column(
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
                  walletState.displayAccountName,
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    delegate: HomeBalanceHeaderDelegate(
                      portfolioUsd: walletState.portfolioUsd,
                      showBalance: walletState.showBalance,
                      balanceTitle: l10n.balanceTitle,
                      onToggleVisibility: () => ref
                          .read(walletProvider.notifier)
                          .toggleBalanceVisibility(),
                    ),
                  ),
                  SliverPinnedHeader(child: _buildNavSection()),
                  if (walletState.activeAccount == null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildNoAccountState(context),
                      ),
                    )
                  else
                    _buildMainContent(walletState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavSection() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Styles.primaryBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: const HSLColor.fromAHSL(
              1,
              256.3636363636,
              0.379310344828,
              0.843137254902,
            ).toColor(),
            offset: const Offset(10, 10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
          BoxShadow(
            color: const HSLColor.fromAHSL(
              1,
              256.3636363636,
              0.379310344828,
              1,
            ).toColor(),
            offset: const Offset(-10, -10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, l10n.tokens),
            _buildNavItem(1, l10n.nfts),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: isSelected ? Styles.whiteColor : Colors.transparent,
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2.5),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Styles.textColor
                : Styles.textColor.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccountState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 60,
          color: Styles.textLightColor,
        ),
        const Gap(16),
        Text(
          l10n.noAccountAvailable,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Styles.textLightColor, fontSize: 14),
        ),
        const Gap(24),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(80),
            gradient: Styles.buttonGradient,
            boxShadow: [
              BoxShadow(
                color: Styles.secondaryAccentColorDark.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddAccountModal(),
              );
            },
            child: Text(
              l10n.addAccount,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(WalletState state) {
    final l10n = AppLocalizations.of(context);
    if (_currentIndex == 0) {
      final tokens = state.portfolioTokens;
      if (tokens.isEmpty) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                l10n.noTokensFound,
                style: const TextStyle(color: Styles.textLightColor),
              ),
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final token = tokens[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: _buildTokenCard(token, state.showBalance),
            );
          }, childCount: tokens.length),
        ),
      );
    } else {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Text(
              l10n.noNftsFound,
              style: const TextStyle(color: Styles.textLightColor),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTokenCard(Token token, bool showBalance) {
    final l10n = AppLocalizations.of(context);
    return ViewBoxContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final rightMaxWidth = (constraints.maxWidth * 0.38).clamp(
                  110.0,
                  165.0,
                );
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: TokenAvatar(
                        size: 32,
                        iconUrl: token.iconUrl,
                        fallbackSeed: token.symbol,
                        resolveFallbackIcon: true,
                        badgeText: _wrappedEtherBadge(token),
                      ),
                    ),
                    const Gap(15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            token.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Styles.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatUsdPrice(token.usdPrice ?? 0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Styles.textLightColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    SizedBox(
                      width: rightMaxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          BlurableContent(
                            showContent: showBalance,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: GradientText(
                                _formatUsdValue(token.usdValue ?? 0),
                                gradient: textGradient(),
                                style: GoogleFonts.poppins(
                                  color: Styles.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          BlurableContent(
                            showContent: showBalance,
                            child: Text(
                              '${token.balance} ${token.symbol}',
                              style: const TextStyle(
                                color: Styles.textColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const Gap(15),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(80),
                      gradient: Styles.buttonGradient,
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: Text(
                        l10n.send,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => _showSendTokenDialog(context, token),
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Styles.secondaryAccentColorDark,
                      size: 18,
                    ),
                    label: const Text(
                      'Swap',
                      style: TextStyle(
                        color: Styles.secondaryAccentColorDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Styles.secondaryAccentColorDark,
                        width: 1.5,
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                    onPressed: () => _openSwapForToken(token),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSendTokenDialog(BuildContext context, Token token) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SendScreen(token: token)));
  }

  Future<void> _openSwapForToken(Token token) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final pools = await ref.read(poolsProvider.future);
      if (!mounted) return;
      final matchingPool = _findBestPoolForToken(token, pools);
      if (matchingPool != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PoolDetailScreen(pool: matchingPool, swapOnly: true),
          ),
        );
        return;
      }
    } catch (_) {
      // Fall through to pools tab if direct pool lookup fails.
    }

    ref.read(navigationTabProvider.notifier).setIndex(2);
    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('No direct ${token.symbol} pool found.')),
    );
  }

  Pool? _findBestPoolForToken(Token token, List<Pool> pools) {
    if (pools.isEmpty) return null;
    final tokenAddress = token.address.trim().toLowerCase();
    final wrappedReefAddress = DexConfig.wrappedReefAddress.toLowerCase();
    final tokenIsReefLike = _isReefLikeToken(token.symbol, token.address);

    bool poolContainsToken(Pool pool) {
      final token0 = pool.token0Address.trim().toLowerCase();
      final token1 = pool.token1Address.trim().toLowerCase();
      if (tokenIsReefLike) {
        return token0 == wrappedReefAddress || token1 == wrappedReefAddress;
      }
      return token0 == tokenAddress || token1 == tokenAddress;
    }

    bool poolContainsReef(Pool pool) {
      final token0 = pool.token0Address.trim().toLowerCase();
      final token1 = pool.token1Address.trim().toLowerCase();
      return token0 == wrappedReefAddress || token1 == wrappedReefAddress;
    }

    final directMatches = pools.where(poolContainsToken).toList();
    if (directMatches.isEmpty) return null;

    for (final pool in directMatches) {
      if (poolContainsReef(pool)) return pool;
    }
    return directMatches.first;
  }

  static String _formatUsdPrice(double value) {
    if (!value.isFinite || value <= 0) return 'Price: \$0.00';
    if (value >= 1) {
      return 'Price: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value)}';
    }
    return 'Price: ${NumberFormat.currency(symbol: '\$', decimalDigits: 6).format(value)}';
  }

  static String _formatUsdValue(double value) {
    if (!value.isFinite || value <= 0) return '\$0.00';
    if (value >= 0.01) {
      return NumberFormat.currency(
        symbol: '\$',
        decimalDigits: 2,
      ).format(value);
    }
    return NumberFormat.currency(symbol: '\$', decimalDigits: 6).format(value);
  }

  static String? _wrappedEtherBadge(Token token) {
    final symbol = token.symbol.trim().toUpperCase();
    final name = token.name.trim().toUpperCase();
    final isWrappedEther =
        symbol == 'WETH' ||
        symbol.startsWith('WETH') ||
        name == 'WRAPPED ETHER' ||
        name == 'WRAPPED ETH' ||
        name.contains('WRAPPED ETHER');
    return isWrappedEther ? 'W' : null;
  }

  static bool _isReefLikeToken(String symbol, String address) {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final normalizedAddress = address.trim().toLowerCase();
    return normalizedSymbol == 'REEF' ||
        normalizedSymbol == 'WREEF' ||
        normalizedAddress == 'native' ||
        normalizedAddress == DexConfig.wrappedReefAddress.toLowerCase();
  }
}
