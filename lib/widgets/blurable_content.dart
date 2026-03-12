import 'dart:ui';

import 'package:flutter/widgets.dart';

class BlurableContent extends StatelessWidget {
  final Widget child;
  final bool showContent;

  const BlurableContent({
    super.key,
    required this.child,
    required this.showContent,
  });

  @override
  Widget build(BuildContext context) {
    if (!showContent) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 23.0, sigmaY: 23.0),
        child: child,
      );
    }
    return child;
  }
}
