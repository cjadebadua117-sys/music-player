import 'package:flutter/material.dart';

import '../theme.dart';

/// A round glass button: translucent film, bright rim and a soft shadow.
/// The selected state glows green and tints its icon with the accent.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 21,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      accent.withValues(alpha: 0.34),
                      accent.withValues(alpha: 0.10),
                    ]
                  : [
                      AppColors.white.withValues(alpha: 0.17),
                      AppColors.white.withValues(alpha: 0.04),
                    ],
            ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.50)
                  : AppColors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? accent.withValues(alpha: 0.28)
                    : AppColors.black.withValues(alpha: 0.32),
                blurRadius: selected ? 26 : 16,
                spreadRadius: selected ? -4 : -6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: selected ? accent : (color ?? AppColors.white),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The little Spotify-style profile disc at the top of the home and library.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.onTap, this.size = 42});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Settings',
      child: Material(
        color: AppColors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF66F29B), AppColors.auroraViolet],
              ),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(
              Icons.person_rounded,
              size: size * 0.52,
              color: AppColors.black.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small translucent capsule for counts and status labels.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.icon,
    this.accented = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
  });

  final String label;
  final IconData? icon;
  final bool accented;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: accented
              ? [accent.withValues(alpha: 0.26), accent.withValues(alpha: 0.08)]
              : [
                  AppColors.white.withValues(alpha: 0.10),
                  AppColors.white.withValues(alpha: 0.03),
                ],
        ),
        border: Border.all(
          color: accented
              ? accent.withValues(alpha: 0.34)
              : AppColors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: accented ? accent : mutedText),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: accented
                  ? accent
                  : AppColors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
