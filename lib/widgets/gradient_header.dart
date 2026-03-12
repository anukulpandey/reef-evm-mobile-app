import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GradientHeader extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;

  const GradientHeader({super.key, this.leading, this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 15,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leading ?? const SizedBox(width: 40),
          if (title != null) Expanded(child: Center(child: title!)),
          if (actions != null)
            Row(children: actions!)
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
