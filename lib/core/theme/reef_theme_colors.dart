import 'package:flutter/material.dart';

@immutable
class ReefThemeColors extends ThemeExtension<ReefThemeColors> {
  const ReefThemeColors({
    required this.appBackground,
    required this.pageBackground,
    required this.deepBackground,
    required this.cardBackground,
    required this.cardBackgroundSecondary,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.inputFill,
    required this.inputBorder,
    required this.accent,
    required this.accentStrong,
    required this.success,
    required this.danger,
    required this.topBarChipBackground,
    required this.topBarChipText,
    required this.topBarChipIcon,
    required this.navBackground,
    required this.navUnselected,
  });

  final Color appBackground;
  final Color pageBackground;
  final Color deepBackground;
  final Color cardBackground;
  final Color cardBackgroundSecondary;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color inputFill;
  final Color inputBorder;
  final Color accent;
  final Color accentStrong;
  final Color success;
  final Color danger;
  final Color topBarChipBackground;
  final Color topBarChipText;
  final Color topBarChipIcon;
  final Color navBackground;
  final Color navUnselected;

  static const ReefThemeColors light = ReefThemeColors(
    appBackground: Color(0xFFEFEAF7),
    pageBackground: Color(0xFFD9D6E3),
    deepBackground: Color(0xFF2B0052),
    cardBackground: Color(0xFFF2EFF9),
    cardBackgroundSecondary: Color(0xFFE8E3F2),
    borderColor: Color(0xFFD6CEE8),
    textPrimary: Color(0xFF2A223D),
    textSecondary: Color(0xFF4A4260),
    textMuted: Color(0xFF8B86A2),
    inputFill: Colors.white,
    inputBorder: Color(0xFFD0C9E0),
    accent: Color(0xFFB9359A),
    accentStrong: Color(0xFF742CB2),
    success: Color(0xFF26B686),
    danger: Color(0xFFE35454),
    topBarChipBackground: Color(0xFFEEEBF6),
    topBarChipText: Color(0xFFB9359A),
    topBarChipIcon: Color(0xFF313A52),
    navBackground: Colors.white,
    navUnselected: Color(0x70000000),
  );

  static const ReefThemeColors dark = ReefThemeColors(
    appBackground: Color(0xFF17002D),
    pageBackground: Color(0xFF1E0B3B),
    deepBackground: Color(0xFF140129),
    cardBackground: Color(0xFF271648),
    cardBackgroundSecondary: Color(0xFF22123E),
    borderColor: Color(0xFF4A2F73),
    textPrimary: Color(0xFFF3EEFF),
    textSecondary: Color(0xFFD1C6EB),
    textMuted: Color(0xFFA79BBC),
    inputFill: Color(0xFF312151),
    inputBorder: Color(0xFF6C4AA0),
    accent: Color(0xFFA742D5),
    accentStrong: Color(0xFF7A3ED5),
    success: Color(0xFF34CC98),
    danger: Color(0xFFFF6C6C),
    topBarChipBackground: Color(0xFF29144D),
    topBarChipText: Color(0xFFE08DFF),
    topBarChipIcon: Color(0xFFE8DDFF),
    navBackground: Color(0xFF1D0E37),
    navUnselected: Color(0xFF8C83A2),
  );

  @override
  ReefThemeColors copyWith({
    Color? appBackground,
    Color? pageBackground,
    Color? deepBackground,
    Color? cardBackground,
    Color? cardBackgroundSecondary,
    Color? borderColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? inputFill,
    Color? inputBorder,
    Color? accent,
    Color? accentStrong,
    Color? success,
    Color? danger,
    Color? topBarChipBackground,
    Color? topBarChipText,
    Color? topBarChipIcon,
    Color? navBackground,
    Color? navUnselected,
  }) {
    return ReefThemeColors(
      appBackground: appBackground ?? this.appBackground,
      pageBackground: pageBackground ?? this.pageBackground,
      deepBackground: deepBackground ?? this.deepBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBackgroundSecondary:
          cardBackgroundSecondary ?? this.cardBackgroundSecondary,
      borderColor: borderColor ?? this.borderColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      topBarChipBackground: topBarChipBackground ?? this.topBarChipBackground,
      topBarChipText: topBarChipText ?? this.topBarChipText,
      topBarChipIcon: topBarChipIcon ?? this.topBarChipIcon,
      navBackground: navBackground ?? this.navBackground,
      navUnselected: navUnselected ?? this.navUnselected,
    );
  }

  @override
  ReefThemeColors lerp(ThemeExtension<ReefThemeColors>? other, double t) {
    if (other is! ReefThemeColors) return this;
    return ReefThemeColors(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      deepBackground: Color.lerp(deepBackground, other.deepBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBackgroundSecondary: Color.lerp(
        cardBackgroundSecondary,
        other.cardBackgroundSecondary,
        t,
      )!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      topBarChipBackground: Color.lerp(
        topBarChipBackground,
        other.topBarChipBackground,
        t,
      )!,
      topBarChipText: Color.lerp(topBarChipText, other.topBarChipText, t)!,
      topBarChipIcon: Color.lerp(topBarChipIcon, other.topBarChipIcon, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navUnselected: Color.lerp(navUnselected, other.navUnselected, t)!,
    );
  }
}

extension ReefThemeContext on BuildContext {
  ReefThemeColors get reefColors =>
      Theme.of(this).extension<ReefThemeColors>() ?? ReefThemeColors.dark;
}
