import 'package:flutter/material.dart';

import 'package:money_tracking_app/view/utils/app_colors.dart';

class AppGradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const AppGradientBackground({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColors =
        colors ??
        (isDark
            ? const [Color(0xFF0F1220), Color(0xFF161B2D), Color(0xFF1D233A)]
            : AppColors.mainGradient);

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: resolvedColors,
          ),
        ),
        child: child,
      ),
    );
  }
}
