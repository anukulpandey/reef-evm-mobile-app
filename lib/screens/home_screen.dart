import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sliver_tools/sliver_tools.dart';
import '../models/fiat_currency.dart';
import '../models/token.dart';
import '../models/pool.dart';
import '../l10n/app_localizations.dart';
import '../core/config/dex_config.dart';
import '../providers/wallet_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/pool_provider.dart';
import '../providers/navigation_provider.dart';
import '../core/theme/reef_theme_colors.dart';
import '../core/theme/styles.dart';
import '../utils/amount_utils.dart';
import '../utils/fiat_formatter.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_components.dart';
import '../widgets/add_account_modal.dart';
import '../widgets/blurable_content.dart';
import '../widgets/common/reef_loading_widgets.dart';
import '../widgets/common/token_avatar.dart';
import '../widgets/home/activity_tab.dart';
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

  ReefThemeColors get _colors => context.reefColors;
  bool get _isDarkTheme => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);
    final fiatCurrency = settings.fiatCurrency;

    return Scaffold(
      backgroundColor: _colors.pageBackground,
      body: Container(
        color: _colors.pageBackground,
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
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPersistentHeader(
                        delegate: HomeBalanceHeaderDelegate(
                          portfolioFiatValue: FiatFormatter.formatValue(
                            walletState.portfolioUsd,
                            fiatCurrency,
                          ),
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
                        _buildMainContent(walletState, fiatCurrency),
                    ],
                  ),
                  if (walletState.isLoading)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: ReefLoadingPill(label: 'Refreshing wallet'),
                    ),
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
        color: _isDarkTheme ? _colors.cardBackground : _colors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: _isDarkTheme
                ? Colors.black.withOpacity(0.22)
                : const Color(0x14000000),
            offset: const Offset(0, 8),
            blurRadius: 22,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _isDarkTheme
                ? _colors.accentStrong.withOpacity(0.08)
                : Colors.white.withOpacity(0.7),
            offset: const Offset(0, -4),
            blurRadius: 18,
            spreadRadius: -10,
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
            _buildNavItem(2, l10n.activity),
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
          color: isSelected ? _colors.navBackground : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _isDarkTheme
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected ? _colors.textPrimary : _colors.textMuted,
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
          style: TextStyle(color: _colors.textMuted, fontSize: 14),
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

  Widget _buildMainContent(WalletState state, FiatCurrency fiatCurrency) {
    final l10n = AppLocalizations.of(context);
    if (_currentIndex == 0) {
      final tokens = state.portfolioTokens;
      if (state.isLoading && tokens.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 28, 12, 0),
            child: ReefLoadingCard(
              title: 'Loading tokens',
              subtitle: 'Fetching balances and pricing for your portfolio.',
            ),
          ),
        );
      }
      if (tokens.isEmpty) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                l10n.noTokensFound,
                style: TextStyle(color: _colors.textMuted),
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
              child: _buildTokenCard(token, state.showBalance, fiatCurrency),
            );
          }, childCount: tokens.length),
        ),
      );
    }

    if (_currentIndex == 1) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Text(
              l10n.noNftsFound,
              style: TextStyle(color: _colors.textMuted),
            ),
          ),
        ),
      );
    }

    return ActivityTab(
      address: state.activeAccount?.address ?? '',
      showBalances: state.showBalance,
    );
  }

  Widget _buildTokenCard(
    Token token,
    bool showBalance,
    FiatCurrency fiatCurrency,
  ) {
    final l10n = AppLocalizations.of(context);
    return ViewBoxContainer(
      color: _colors.cardBackground,
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
                      backgroundColor: _colors.cardBackgroundSecondary,
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
                              color: _colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            FiatFormatter.formatPrice(
                              token.usdPrice ?? 0,
                              fiatCurrency,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _colors.textMuted,
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
                                FiatFormatter.formatValue(
                                  token.usdValue ?? 0,
                                  fiatCurrency,
                                ),
                                gradient: textGradient(),
                                style: GoogleFonts.poppins(
                                  color: _colors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          BlurableContent(
                            showContent: showBalance,
                            child: Text(
                              '${AmountUtils.formatCompactToken(token.balance)} ${token.symbol}',
                              style: TextStyle(
                                color: _colors.textPrimary,
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
                    label: Text(
                      'Swap',
                      style: const TextStyle(
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
                      backgroundColor: _isDarkTheme
                          ? _colors.cardBackgroundSecondary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.3),
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
