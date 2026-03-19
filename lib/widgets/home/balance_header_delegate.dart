import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/reef_theme_colors.dart';
import '../blurable_content.dart';
import '../official_components.dart';

class HomeBalanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String portfolioFiatValue;
  final bool showBalance;
  final String balanceTitle;
  final VoidCallback onToggleVisibility;

  HomeBalanceHeaderDelegate({
    required this.portfolioFiatValue,
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
    final colors = context.reefColors;
    if (shrinkOffset > 80) {
      return const SizedBox.shrink();
    }
    double opacity = ((shrinkOffset - 180) / 180).abs();
    if (opacity < 0) opacity = 0;
    if (opacity > 1) opacity = 1;

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        balanceTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: Icon(
                          showBalance
                              ? Icons.remove_red_eye
                              : Icons.visibility_off,
                          color: colors.textMuted,
                        ),
                        onPressed: onToggleVisibility,
                      ),
                    ],
                  ),
                  BlurableContent(
                    showContent: showBalance,
                    child: GradientText(
                      portfolioFiatValue,
                      gradient: textGradient(),
                      style: GoogleFonts.poppins(
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
