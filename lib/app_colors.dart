import 'package:flutter/material.dart';

/// Application-wide colors for the Music Player app.
/// All screens and widgets should import this file and use these constants
/// instead of inline Color() literals or Colors.* references.
class AppColors {
  /// Main accent color — Spotify green, used for interactive elements.
  static const accent = Color(0xFF1DB954);

  /// Deep accent for gradients and secondary highlights.
  static const accentDeep = Color(0xFF7C3AED);

  /// Soft accent for subtle backgrounds.
  static const accentSoft = Color(0xFFE9D8FD);

  /// Pure black background.
  static const black = Color(0xFF000000);

  /// Near-black base for dark mode surfaces. Slightly blue so the glass
  /// highlights above it read as cold, real glass instead of flat charcoal.
  static const nearBlack = Color(0xFF05060A);

  /// Card background — dark gray lifted off the black backdrop.
  static const card = Color(0xFF181818);

  /// Card elevated state (e.g. selected chip, popover).
  static const cardHigh = Color(0xFF1E1B2F);

  /// On-card text (readable on card backgrounds).
  static const onCard = Color(0xFFE8E6ED);

  /// Muted secondary text (captions, disabled states).
  static const muted = Color(0xFF9BA1B6);

  /// On-muted text (readable on muted backgrounds).
  static const onMuted = Color(0xFFC9C8D7);

  /// Pure white text.
  static const white = Color(0xFFFFFFFF);

  /// Transparent (for Material/InkWell backgrounds).
  static const transparent = Colors.transparent;

  /// Subtle divider color.
  static const divider = Color(0x14FFFFFF);

  /// Offline badge color.
  static const offline = Color(0xFFC084FC);

  // ---------------------------------------------------------------------
  // Ultra-glass palette. Aurora blooms live behind every screen; glass
  // surfaces are white film (not flat gray) with a bright 1px rim.
  // ---------------------------------------------------------------------

  /// Violet aurora bloom, the secondary light source of the app.
  static const auroraViolet = Color(0xFF7C3AED);

  /// Deep indigo used in the darkest corner of the aurora.
  static const auroraIndigo = Color(0xFF4C1D95);

  /// Cyan bloom for the lower-left corner.
  static const auroraCyan = Color(0xFF0891B2);

  /// Magenta bloom for highlights behind the player cover.
  static const auroraPink = Color(0xFFBE185D);

  /// Default frosted fill: 8% white film.
  static const glass = Color(0x14FFFFFF);

  /// Stronger frosted fill for the surface directly in front of the user.
  static const glassStrong = Color(0x24FFFFFF);

  /// Hairline rim that catches the light around a glass pane.
  static const glassBorder = Color(0x26FFFFFF);

  /// Bright specular edge for the top of controls (progress, active pills).
  static const glassHighlight = Color(0x4DFFFFFF);

  /// Placeholder gradient start for cover art.
  static const artworkGradientStart = Color(0xFF22C55E);

  /// Placeholder gradient end for cover art.
  static const artworkGradientEnd = Color(0xFF7C3AED);
}
