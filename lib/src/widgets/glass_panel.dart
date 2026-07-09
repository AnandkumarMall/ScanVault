import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final double blurSigma;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.backgroundColor = const Color(0xB3141E1E), // glassDark
    this.borderColor = const Color(0x1400E5FF), // glassBorder
    this.blurSigma = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: child,
        ),
      ),
    );
  }
}
