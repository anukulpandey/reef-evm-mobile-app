import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/reef_theme_colors.dart';

class ReefLoadingCard extends StatelessWidget {
  const ReefLoadingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 44 : 52,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.cardBackgroundSecondary,
              border: Border.all(color: colors.borderColor.withOpacity(0.85)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: colors.accentStrong.withOpacity(0.22),
                  size: compact ? 20 : 24,
                ),
                SizedBox(
                  width: compact ? 22 : 24,
                  height: compact ? 22 : 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.accentStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.textPrimary,
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const Gap(4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReefLoadingPill extends StatelessWidget {
  const ReefLoadingPill({
    super.key,
    required this.label,
    this.icon = Icons.sync_rounded,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.reefColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground.withOpacity(isDark ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accentStrong),
            ),
          ),
          const Gap(10),
          Icon(icon, size: 16, color: colors.accentStrong),
          const Gap(6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
