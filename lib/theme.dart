import 'package:flutter/material.dart';
import 'app_colors.dart';
export 'app_colors.dart';

/// Legacy palette names, kept so every screen and widget can keep using the
/// short constant names (`accent`, `canvas`, `mutedText`, ...).
const accent = AppColors.accent;
const accentDeep = AppColors.accentDeep;
const accentSoft = AppColors.accentSoft;
const canvas = AppColors.nearBlack;
const nearBlack = AppColors.nearBlack;
const panel = AppColors.card;
const panelHigh = AppColors.cardHigh;
const mutedText = AppColors.muted;
const auroraViolet = AppColors.auroraViolet;
const auroraCyan = AppColors.auroraCyan;
const auroraPink = AppColors.auroraPink;
const glass = AppColors.glass;
const glassStrong = AppColors.glassStrong;
const glassBorder = AppColors.glassBorder;
const glassHighlight = AppColors.glassHighlight;
const bodyFont = 'DMSans';
const displayFont = bodyFont;
const pageTitleStyle = TextStyle(
  fontSize: 34,
  fontWeight: FontWeight.w700,
  letterSpacing: -1.3,
  height: 1.05,
);
const sectionTitleStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.7,
  height: 1.15,
);

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accentDeep,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        secondary: accent,
        surface: nearBlack,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        surfaceContainerHigh: panel,
        surfaceContainerHighest: panelHigh,
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'DMSans',
  );
  final text = base.textTheme.apply(fontFamily: 'DMSans');

  return base.copyWith(
    scaffoldBackgroundColor: nearBlack,
    textTheme: text.copyWith(
      displayLarge: pageTitleStyle.copyWith(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        letterSpacing: -1.3,
        height: 1.05,
      ),
      displayMedium: pageTitleStyle.copyWith(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.15,
      ),
      displaySmall: pageTitleStyle.copyWith(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.10,
      ),
      headlineMedium: pageTitleStyle.copyWith(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      headlineSmall: pageTitleStyle.copyWith(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.15,
      ),
      titleLarge: pageTitleStyle.copyWith(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.white,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: panelHigh,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14,
        color: AppColors.white,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: panelHigh,
      contentTextStyle: const TextStyle(color: AppColors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 4,
      activeTrackColor: accent,
      inactiveTrackColor: AppColors.white.withValues(alpha: 0.24),
      thumbColor: AppColors.white,
      overlayColor: AppColors.white.withValues(alpha: 0.08),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
  );
}

/// Gradient used for placeholder artwork (tracks with no embedded cover):
/// a living green-to-violet wash instead of a flat tile.
const artworkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.artworkGradientStart, AppColors.artworkGradientEnd],
);

/// Ultra-glass background: near-black lacquer with slow aurora blooms in
/// green, violet and cyan, a soft top sheen and a bottom vignette. Purely
/// static (no ticking animation), so it stays cheap while scrolling.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, this.intensity = 1});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: canvas),
              Positioned(
                top: -170,
                left: -120,
                width: 600,
                height: 600,
                child: _Aura(color: accent.withValues(alpha: 0.36 * intensity)),
              ),
              Positioned(
                top: -230,
                right: -170,
                width: 700,
                height: 700,
                child: _Aura(
                  color: auroraViolet.withValues(alpha: 0.56 * intensity),
                ),
              ),
              Positioned(
                top: 210,
                left: -250,
                width: 720,
                height: 720,
                child: _Aura(
                  color: AppColors.auroraIndigo.withValues(
                    alpha: 0.32 * intensity,
                  ),
                ),
              ),
              Positioned(
                bottom: -220,
                left: -120,
                width: 600,
                height: 600,
                child: _Aura(
                  color: auroraCyan.withValues(alpha: 0.26 * intensity),
                ),
              ),
              Positioned(
                bottom: -200,
                right: -150,
                width: 560,
                height: 560,
                child: _Aura(
                  color: AppColors.auroraPink.withValues(
                    alpha: 0.16 * intensity,
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 300,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x40000000), canvas],
                    stops: [0.58, 0.88, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One blurred-looking light bloom. A radial gradient is visually identical to
/// a blurred circle here and costs nothing to repaint.
class _Aura extends StatelessWidget {
  const _Aura({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ),
      ),
    );
  }
}

/// Frosted card fill used by panels that are not blurred (row cards, stat
/// tiles). Keeps every surface in the same glass family.
BoxDecoration cardDecoration({double radius = 18}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.white.withValues(alpha: 0.075),
      AppColors.white.withValues(alpha: 0.022),
    ],
  ),
  border: Border.all(color: AppColors.white.withValues(alpha: 0.10)),
  boxShadow: [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.35),
      blurRadius: 22,
      offset: const Offset(0, 10),
      spreadRadius: -8,
    ),
  ],
);
