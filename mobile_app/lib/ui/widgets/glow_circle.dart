import 'package:flutter/material.dart';

/// Soft radial-style blob used to add a touch of brand color to otherwise
/// flat backgrounds, without competing with foreground content. Typically
/// placed via [Positioned] just off-screen at a corner.
class GlowCircle extends StatelessWidget {
  const GlowCircle({super.key, required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
