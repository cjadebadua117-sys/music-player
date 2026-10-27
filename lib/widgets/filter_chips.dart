import 'package:flutter/material.dart';

import '../theme.dart';

/// A pill filter, like the "Music / Podcasts" row in the reference. Selected
/// pills glow with the accent; the rest are frosted glass capsules.
class MusicChip extends StatelessWidget {
  const MusicChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.68),
                      ]
                    : [
                        AppColors.white.withValues(alpha: 0.10),
                        AppColors.white.withValues(alpha: 0.03),
                      ],
              ),
              border: Border.all(
                color: selected
                    ? AppColors.white.withValues(alpha: 0.35)
                    : AppColors.white.withValues(alpha: 0.14),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              count == null || count == 0 ? label : '$label · $count',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? AppColors.black
                    : AppColors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal, scrolling row of [MusicChip]s.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({super.key, required this.chips, this.padding});

  final List<MusicChip> chips;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
        children: [...chips, const SizedBox(width: 8)],
      ),
    );
  }
}
