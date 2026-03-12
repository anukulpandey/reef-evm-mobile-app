import 'package:flutter/material.dart';
import '../core/theme/styles.dart';

class ViewBoxContainer extends StatelessWidget {
  final Color color;
  final Widget child;
  final String imageUrl;

  const ViewBoxContainer({
    Key? key,
    required this.child,
    this.color = Styles.boxBackgroundColor,
    this.imageUrl = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        image: imageUrl != ''
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
        color: color,
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 3),
            blurRadius: 30,
          )
        ],
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    Key? key,
    required this.gradient,
    this.textAlign = TextAlign.left,
    this.style,
    this.overflow,
  }) : super(key: key);

  final String text;
  final TextAlign textAlign;
  final TextStyle? style;
  final Gradient gradient;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
      ),
    );
  }
}

LinearGradient textGradient() {
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Styles.purpleColor,
      Styles.primaryAccentColor,
    ],
  );
}
