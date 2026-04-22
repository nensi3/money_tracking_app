import 'package:flutter/material.dart';

class AppInputDecorations {
  static InputDecoration auth({
    required String label,
    required IconData prefix,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(prefix),
      suffixIcon: suffixIcon,
    );
  }

  static InputDecoration filled({String? hintText, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
