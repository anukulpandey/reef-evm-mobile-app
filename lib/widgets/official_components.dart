import 'package:flutter/material.dart';
import 'styles.dart';

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
      height: imageUrl != '' ? 200 : null,
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
