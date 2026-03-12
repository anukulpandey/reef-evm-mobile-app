import 'dart:math' as math;

import 'package:flutter/material.dart';

class AddressPatternAvatar extends StatelessWidget {
  const AddressPatternAvatar({
    super.key,
    required this.seed,
    this.size = 76,
    this.innerSize = 60,
    this.dotSize = 10,
    this.dotCount = 25,
  });

  final String seed;
  final double size;
  final double innerSize;
  final double dotSize;
  final int dotCount;

  static const List<Color> _palette = <Color>[
    Color(0xFF2D8CFF),
    Color(0xFF6CCB2F),
    Color(0xFFD873C0),
    Color(0xFF8D7BFF),
    Color(0xFF6EC6DE),
    Color(0xFFE58DA0),
  ];

  @override
  Widget build(BuildContext context) {
    final normalizedSeed = seed.isEmpty ? '0x0' : seed;
    final bytes = normalizedSeed.codeUnits;
    final safeInnerSize = math.max(0.0, math.min(innerSize, size - 8));
    const spacing = 2.0;
    const columns = 5;
    final rows = (dotCount / columns).ceil();

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Container(
          color: const Color(0xFFEFF0F2),
          alignment: Alignment.center,
          child: SizedBox(
            width: safeInnerSize,
            height: safeInnerSize,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxDotByWidth =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;
                final maxDotByHeight =
                    (constraints.maxHeight - ((rows - 1) * spacing)) / rows;
                final resolvedDotSize = math
                    .max(
                      4,
                      math.min(
                        dotSize,
                        math.min(maxDotByWidth, maxDotByHeight),
                      ),
                    )
                    .toDouble();

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: List.generate(dotCount, (index) {
                    final value = bytes[(index * 7) % bytes.length];
                    return Container(
                      width: resolvedDotSize,
                      height: resolvedDotSize,
                      decoration: BoxDecoration(
                        color: _palette[value % _palette.length],
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
