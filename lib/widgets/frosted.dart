import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A translucent, blurred pane — the building block of the ultra-glass look.
///
/// The fill is a white-film gradient rather than one flat colour, so the pane
/// catches light at the top-left and fades toward the bottom-right. A bright
/// hairline rim and a deep drop shadow lift it off the aurora behind it.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    this.radius = 0,
    this.blur = 28,
    this.tint,
    this.border,
    this.glow = false,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color? tint;
  final Border? border;

  /// Adds a soft accent bloom around the pane (now playing, primary cards).
  final bool glow;

  /// Outer drop shadow. Disable for full-bleed bars that already sit on an edge.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final rounded = BorderRadius.circular(radius);
    // Past ~20 the extra blur is barely visible but costs real GPU time on a
    // 90 Hz phone; the panels are small, so cap the sigma and keep the frames.
    final sigma = blur > 20 ? 20.0 : blur;
    final base = tint ?? AppColors.white.withValues(alpha: 0.075);
    // The far corner is a little more transparent so the pane reads as glass
    // with a light source, not as a solid gray rectangle.
    final far = base.withValues(alpha: base.a * 0.45);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rounded,
        boxShadow: [
          if (shadow)
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.48),
              blurRadius: 32,
              spreadRadius: -10,
              offset: const Offset(0, 18),
            ),
          if (glow)
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 52,
              spreadRadius: -12,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: rounded,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: rounded,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, far],
              ),
              border:
                  border ??
                  Border.all(color: AppColors.white.withValues(alpha: 0.17)),
            ),
            child: Stack(
              children: [
                child,
                // Specular line along the top edge: the cue that reads as a
                // pane of glass catching the light rather than a gray box.
                Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  height: 1.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.white.withValues(alpha: 0),
                          AppColors.white.withValues(alpha: 0.48),
                          AppColors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
