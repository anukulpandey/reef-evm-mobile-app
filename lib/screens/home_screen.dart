import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sliver_tools/sliver_tools.dart';
import '../models/token.dart';
import '../l10n/app_localizations.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';
import '../utils/token_icon_resolver.dart';
import '../widgets/official_top_bar.dart';
import '../widgets/official_components.dart';
import '../widgets/add_account_modal.dart';
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
                    delegate: _BalanceHeaderDelegate(
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
              child: _buildTokenCard(token),
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

  Widget _buildTokenCard(Token token) {
    final l10n = AppLocalizations.of(context);
    return ViewBoxContainer(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: _buildTokenIcon(token),
                ),
                const Gap(15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.name,
                      style: GoogleFonts.poppins(
                        color: Styles.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatUsdPrice(token.usdPrice ?? 0),
                      style: const TextStyle(
                        color: Styles.textLightColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GradientText(
                      _formatUsdValue(token.usdValue ?? 0),
                      gradient: textGradient(),
                      style: GoogleFonts.poppins(
                        color: Styles.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
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
              ],
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenIcon(Token token) {
    final iconUrl =
        token.iconUrl ??
        TokenIconResolver.resolveTokenIconUrl(
          address: token.address,
          symbol: token.symbol,
        );
    final imageProvider = _resolveImageProvider(iconUrl);
    final svgData = _resolveSvgData(iconUrl);

    if (svgData != null) {
      return ClipOval(
        child: SvgPicture.string(
          svgData,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imageProvider != null) {
      return ClipOval(
        child: Image(
          image: imageProvider,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.circle, color: Styles.primaryColor, size: 14),
        ),
      );
    }

    return const Icon(Icons.circle, color: Styles.primaryColor, size: 14);
  }

  static ImageProvider? _resolveImageProvider(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final normalized = iconUrl.trim();
    final dataUri = _tryParseDataUri(normalized);
    if (dataUri != null) {
      if (dataUri.mimeType.contains('svg')) return null;
      final bytes = dataUri.contentAsBytes();
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return NetworkImage(normalized);
  }

  static String? _resolveSvgData(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final uriData = _tryParseDataUri(iconUrl.trim());
    if (uriData == null || !uriData.mimeType.contains('svg')) return null;
    final bytes = uriData.contentAsBytes();
    if (bytes.isEmpty) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static UriData? _tryParseDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    try {
      return UriData.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showSendTokenDialog(BuildContext context, Token token) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SendScreen(token: token)));
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
}

class _BalanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double portfolioUsd;
  final bool showBalance;
  final String balanceTitle;
  final VoidCallback onToggleVisibility;

  _BalanceHeaderDelegate({
    required this.portfolioUsd,
    required this.showBalance,
    required this.balanceTitle,
    required this.onToggleVisibility,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    if (shrinkOffset > 80) {
      return const SizedBox.shrink();
    }
    double opacity = ((shrinkOffset - 180) / 180).abs();
    if (opacity < 0) opacity = 0;
    if (opacity > 1) opacity = 1;

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  balanceTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Styles.primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    showBalance ? Icons.remove_red_eye : Icons.visibility_off,
                    color: Styles.textLightColor,
                  ),
                  onPressed: onToggleVisibility,
                ),
              ],
            ),
            Center(
              child: GradientText(
                showBalance
                    ? (portfolioUsd >= 0.01
                          ? NumberFormat.currency(
                              symbol: '\$',
                              decimalDigits: 2,
                            ).format(portfolioUsd)
                          : NumberFormat.currency(
                              symbol: '\$',
                              decimalDigits: 6,
                            ).format(portfolioUsd))
                    : '******',
                gradient: textGradient(),
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Styles.textColor,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 180;
  @override
  double get minExtent => 0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
