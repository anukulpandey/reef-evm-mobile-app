import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/styles.dart';
import '../../core/theme/reef_theme_colors.dart';
import '../../models/pool.dart';
import '../common/token_avatar.dart';

class PoolListCard extends StatelessWidget {
  const PoolListCard({
    super.key,
    required this.pool,
    required this.onTap,
    required this.tvlLabel,
    required this.volume24hLabel,
  });

  final Pool pool;
  final VoidCallback onTap;
  final String tvlLabel;
  final String volume24hLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final token0Symbol = _displaySymbol(pool.token0Symbol);
    final token1Symbol = _displaySymbol(pool.token1Symbol);
    final ticker =
        '${_tickerSymbol(token0Symbol)}/${_tickerSymbol(token1Symbol)}';
    final change = pool.percentChange;
    final hasPositiveChange = change >= 0;
    final changeText = '${change.abs().toStringAsFixed(1)}%';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140E0A1A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 58,
                  height: 46,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TokenPairAvatar(
                      firstIconUrl: pool.tokenIcons.isNotEmpty
                          ? pool.tokenIcons[0]
                          : null,
                      secondIconUrl: pool.tokenIcons.length > 1
                          ? pool.tokenIcons[1]
                          : null,
                      firstSeed: token0Symbol,
                      secondSeed: token1Symbol,
                      avatarSize: 34,
                      overlapOffset: 24,
                      resolveFallbackIcon: true,
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$token0Symbol - $token1Symbol',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Styles.fsCardTitle,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        '$tvlLabel : ${pool.tvl}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(1),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$volume24hLabel : ${pool.volume24h} ',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: hasPositiveChange
                                  ? changeText
                                  : '-$changeText',
                              style: TextStyle(
                                color: hasPositiveChange
                                    ? Styles.greenColor
                                    : const Color(0xFFE04D4D),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ticker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Gap(10),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: colors.cardBackgroundSecondary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
