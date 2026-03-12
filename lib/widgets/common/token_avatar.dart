import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/styles.dart';
import '../../utils/icon_data_utils.dart';
import '../../utils/token_icon_resolver.dart';

class TokenAvatar extends StatelessWidget {
  const TokenAvatar({
    super.key,
    required this.size,
    required this.fallbackSeed,
    this.iconUrl,
    this.resolveFallbackIcon = false,
    this.useDeterministicFallback = false,
    this.badgeText,
    this.imageFit = BoxFit.cover,
    this.imagePadding = EdgeInsets.zero,
    this.avatarBackgroundColor,
  });

  final double size;
  final String fallbackSeed;
  final String? iconUrl;
  final bool resolveFallbackIcon;
  final bool useDeterministicFallback;
  final String? badgeText;
  final BoxFit imageFit;
  final EdgeInsetsGeometry imagePadding;
  final Color? avatarBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final normalizedSeed = fallbackSeed.trim();
    final resolvedIconUrl =
        iconUrl ??
        (resolveFallbackIcon && normalizedSeed.isNotEmpty
            ? TokenIconResolver.getIconUrl(normalizedSeed)
            : null);

    final imageProvider = IconDataUtils.resolveImageProvider(resolvedIconUrl);
    final svgData = IconDataUtils.resolveSvgData(resolvedIconUrl);
    final fallback = useDeterministicFallback
        ? _buildDeterministicFallback(normalizedSeed, size)
        : _buildDefaultFallback(size);

    Widget avatarContent;
    if (svgData != null) {
      avatarContent = ClipOval(
        child: Container(
          color: avatarBackgroundColor,
          padding: imagePadding,
          child: SvgPicture.string(
            svgData,
            width: size,
            height: size,
            fit: imageFit,
          ),
        ),
      );
    } else if (imageProvider != null) {
      avatarContent = ClipOval(
        child: Container(
          color: avatarBackgroundColor,
          padding: imagePadding,
          child: Image(
            image: imageProvider,
            width: size,
            height: size,
            fit: imageFit,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    } else {
      avatarContent = fallback;
    }

    final avatar = SizedBox(width: size, height: size, child: avatarContent);
    final normalizedBadge = badgeText?.trim() ?? '';
    if (normalizedBadge.isEmpty) return avatar;

    final badgeSize = (size * 0.42).clamp(10.0, 16.0).toDouble();
    final badgeFontSize = (badgeSize * 0.58).clamp(8.0, 11.0).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: const Color(0xFF5A31B5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                normalizedBadge,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: badgeFontSize,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDefaultFallback(double size) {
    return Icon(Icons.circle, color: Styles.primaryColor, size: size * 0.5);
  }

  static Widget _buildDeterministicFallback(String seed, double size) {
    final initial = seed.isEmpty ? '?' : seed.substring(0, 1).toUpperCase();
    final bg = Color(0xFF000000 + (seed.hashCode.abs() % 0x00FFFFFF));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: math.max(10, size * 0.45),
        ),
      ),
    );
  }
}

class TokenPairAvatar extends StatelessWidget {
  const TokenPairAvatar({
    super.key,
    required this.firstIconUrl,
    required this.secondIconUrl,
    required this.firstSeed,
    required this.secondSeed,
    this.avatarSize = 26,
    this.overlapOffset = 20,
    this.resolveFallbackIcon = true,
    this.imageFit = BoxFit.cover,
    this.imagePadding = EdgeInsets.zero,
    this.avatarBackgroundColor,
  });

  final String? firstIconUrl;
  final String? secondIconUrl;
  final String firstSeed;
  final String secondSeed;
  final double avatarSize;
  final double overlapOffset;
  final bool resolveFallbackIcon;
  final BoxFit imageFit;
  final EdgeInsetsGeometry imagePadding;
  final Color? avatarBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final width = overlapOffset + avatarSize;

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: TokenAvatar(
              size: avatarSize,
              iconUrl: firstIconUrl,
              fallbackSeed: firstSeed,
              resolveFallbackIcon: resolveFallbackIcon,
              imageFit: imageFit,
              imagePadding: imagePadding,
              avatarBackgroundColor: avatarBackgroundColor,
            ),
          ),
          Positioned(
            left: overlapOffset,
            top: 0,
            child: TokenAvatar(
              size: avatarSize,
              iconUrl: secondIconUrl,
              fallbackSeed: secondSeed,
              resolveFallbackIcon: resolveFallbackIcon,
              imageFit: imageFit,
              imagePadding: imagePadding,
              avatarBackgroundColor: avatarBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }
}
