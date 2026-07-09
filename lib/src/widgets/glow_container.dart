import 'package:flutter/material.dart';

class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final double spreadRadius;
  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = const Color(0x3300E5FF),
    this.blurRadius = 20,
    this.spreadRadius = 2,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
            offset: Offset.zero,
          ),
        ],
      ),
      child: child,
    );
  }
}
