import 'package:flutter/material.dart';

class SquareCheckbox extends StatelessWidget {
  const SquareCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
    this.borderColor = const Color(0xFF9AA2BC),
    this.checkColor = const Color(0xFFB9359A),
    this.fillColor = Colors.white,
    this.borderRadius = 4,
    this.borderWidth = 2,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;
  final Color borderColor;
  final Color checkColor;
  final Color fillColor;
  final double borderRadius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Checkbox(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        fillColor: WidgetStateProperty.resolveWith<Color>((_) => fillColor),
        checkColor: checkColor,
        side: BorderSide(color: borderColor, width: borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
