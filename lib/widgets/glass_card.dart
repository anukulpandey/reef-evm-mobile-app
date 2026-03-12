import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    // Determine the layout behavior: if inside a ListView with infinite height,
    // we must provide a fixed height or use wrap_content (which GlassmorphicContainer doesn't support well).
    // GlassmorphicContainer requires a fixed height.
    
    return GlassmorphicContainer(
      width: width ?? MediaQuery.of(context).size.width - 40,
      height: height ?? 150, // Default to 150 if not specified to avoid infinite height errors
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.glassBackground,
          AppColors.glassBackground.withOpacity(0.1),
        ],
        stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.glassBorder,
          AppColors.glassBorder.withOpacity(0.1),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
