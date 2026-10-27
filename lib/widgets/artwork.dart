import 'package:flutter/material.dart';

import '../theme.dart';

/// The gradient tile that stands in for cover art (imported songs carry no
/// embedded artwork in this version).
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.size,
    this.icon = Icons.music_note,
    this.radius,
  });

  final double size;
  final IconData icon;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: artworkGradient,
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.35),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: AppColors.white.withValues(alpha: 0.92),
      ),
    );
  }
}
