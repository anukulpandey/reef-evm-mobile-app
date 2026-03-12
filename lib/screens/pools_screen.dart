import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../l10n/app_localizations.dart';
import '../providers/pool_provider.dart';
import '../providers/wallet_provider.dart';
import '../core/theme/styles.dart';
import '../utils/token_icon_resolver.dart';
import '../widgets/official_top_bar.dart';
import 'pool_detail_screen.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsyncValue = ref.watch(poolsProvider);
    final walletState = ref.watch(walletProvider);
    final l10n = AppLocalizations.of(context);

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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.tokenPools,
                style: const TextStyle(
                  fontSize: Styles.fsPageTitle,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
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
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pools.length,
                  itemBuilder: (context, index) {
                    final pool = pools[index];
                    final token0Symbol = _displaySymbol(pool.token0Symbol);
                    final token1Symbol = _displaySymbol(pool.token1Symbol);
                    final ticker =
                        '${_tickerSymbol(token0Symbol)}/${_tickerSymbol(token1Symbol)}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PoolDetailScreen(pool: pool),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEAF1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 64,
                                  height: 52,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        top: 8,
                                        child: _buildTokenAvatar(
                                          iconUrl: pool.tokenIcons.isNotEmpty
                                              ? pool.tokenIcons[0]
                                              : null,
                                          fallbackSeed: token0Symbol,
                                        ),
                                      ),
                                      Positioned(
                                        left: 20,
                                        top: 8,
                                        child: _buildTokenAvatar(
                                          iconUrl: pool.tokenIcons.length > 1
                                              ? pool.tokenIcons[1]
                                              : null,
                                          fallbackSeed: token1Symbol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$token0Symbol - $token1Symbol',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: Styles.fsCardTitle,
                                          color: Color(0xFF1F1C2A),
                                        ),
                                      ),
                                      const Gap(2),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${l10n.tvlLabel} : ',
                                              style: TextStyle(
                                                color: Color(0xFF353142),
                                                fontSize: Styles.fsBody,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            TextSpan(
                                              text: pool.tvl,
                                              style: const TextStyle(
                                                color: Color(0xFF353142),
                                                fontSize: Styles.fsBody,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Gap(1),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${l10n.volume24hLabel} : ',
                                              style: TextStyle(
                                                color: Color(0xFF353142),
                                                fontSize: Styles.fsBody,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            TextSpan(
                                              text: pool.volume24h,
                                              style: const TextStyle(
                                                color: Color(0xFF353142),
                                                fontSize: Styles.fsBody,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' 0 %',
                                              style: TextStyle(
                                                color: Color(0xFF26B686),
                                                fontSize: Styles.fsBody,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        ticker,
                                        style: const TextStyle(
                                          color: Color(0xFF413D4C),
                                          fontSize: Styles.fsBody,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Gap(4),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF9C98A9),
                                        size: 23,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  static Widget _buildTokenAvatar({
    required String? iconUrl,
    required String fallbackSeed,
  }) {
    final provider = _resolveImageProvider(iconUrl);
    final svgData = _resolveSvgData(iconUrl);
    final fallback = _buildDeterministicFallbackIcon(fallbackSeed);
    return SizedBox(
      width: 26,
      height: 26,
      child: svgData != null
          ? ClipOval(
              child: SvgPicture.string(
                svgData,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            )
          : provider == null
          ? fallback
          : ClipOval(
              child: Image(
                image: provider,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }

  static Widget _buildDeterministicFallbackIcon(String seed) {
    final fallbackSvgData = _resolveSvgData(TokenIconResolver.getIconUrl(seed));
    if (fallbackSvgData == null) {
      return const Icon(Icons.circle, size: 12, color: Colors.white);
    }
    return ClipOval(
      child: SvgPicture.string(
        fallbackSvgData,
        width: 26,
        height: 26,
        fit: BoxFit.cover,
      ),
    );
  }

  static ImageProvider? _resolveImageProvider(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final normalized = iconUrl.trim();
    final dataUri = _tryParseDataUri(normalized);
    if (dataUri != null) {
      if (dataUri.mimeType.contains('svg')) {
        return null;
      }
      final bytes = dataUri.contentAsBytes();
      if (bytes.isNotEmpty) {
        return MemoryImage(bytes);
      }
      return null;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return NetworkImage(normalized);
  }

  static String? _resolveSvgData(String? iconUrl) {
    if (iconUrl == null || iconUrl.trim().isEmpty) return null;
    final data = _tryParseDataUri(iconUrl.trim());
    if (data == null) return null;
    if (!data.mimeType.contains('svg')) return null;
    final bytes = data.contentAsBytes();
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

  static String _displaySymbol(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper == 'WREEF' || upper == 'REEF') return 'Reef';
    return raw.trim();
  }

  static String _tickerSymbol(String symbol) {
    final upper = symbol.trim().toUpperCase();
    const shortMap = <String, String>{
      'PIRATE COIN': 'PC',
      'WAVECOIN': 'WACO',
      'WRAPPED BTC': 'WTBC',
      'WRAPPED ETH': 'WETH',
      'REEF': 'REEF',
      'POSEIDON': 'POS',
    };
    return shortMap[upper] ?? upper.replaceAll(' ', '');
  }
}
