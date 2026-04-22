import 'package:flutter/material.dart';

class AuthFormCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double opacity;

  const AuthFormCard({
    super.key,
    required this.child,
    this.maxWidth = 420,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.opacity = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
