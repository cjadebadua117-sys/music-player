import 'package:flutter/material.dart';

import '../app/album_art.dart';
import '../models/track.dart';
import '../theme.dart';

/// A song's cover: its real album artwork when the phone has it, otherwise a
/// generated gradient tile so the layout keeps its rhythm.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.track,
    required this.size,
    this.radius,
    this.circle = false,
  });

  final Track? track;
  final double size;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final corner = BorderRadius.circular(
      circle ? size / 2 : (radius ?? size * 0.08),
    );
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: corner,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CoverImage(track: track, size: size),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: corner,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.white.withValues(alpha: 0.10),
                      AppColors.transparent,
                      AppColors.black.withValues(alpha: 0.10),
                    ],
                    stops: const [0, 0.42, 1],
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

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.track, required this.size});

  final Track? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (track == null || track!.demo) {
      return _FallbackArt(size: size);
    }

    return FutureBuilder(
      future: AlbumArtStore.instance.load(track),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        // Decode once at the physical pixel size the tile will be drawn at, so
        // scrolling does not repeatedly sample a needlessly huge bitmap. The
        // old fixed 3x multiplier decoded 3x images even on 2x screens.
        final target = (size * MediaQuery.devicePixelRatioOf(context)).clamp(
          96.0,
          512.0,
        );
        // Fade the decoded cover in over the gradient. Covers arrive while the
        // user is already scrolling, so a 200 ms fade hides the pop-in without
        // the flicker a full cross-fade would show on track changes.
        return Stack(
          fit: StackFit.expand,
          children: [
            _FallbackArt(size: size),
            if (bytes != null)
              TweenAnimationBuilder<double>(
                key: ValueKey(bytes),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (_, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  cacheWidth: target.round(),
                  errorBuilder: (_, _, _) => _FallbackArt(size: size),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: artworkGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.7),
                radius: 1.1,
                colors: [
                  AppColors.white.withValues(alpha: 0.34),
                  AppColors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: size * 0.48,
              height: size * 0.48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: size * 0.26,
                color: AppColors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The same cover, blurred and dimmed, as a full-screen background.
class CoverBackdrop extends StatelessWidget {
  const CoverBackdrop({super.key, required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Backdrop(intensity: 1.6),
          if (track != null)
            FutureBuilder(
              future: AlbumArtStore.instance.load(track),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) return const SizedBox.shrink();
                // A 48px copy stretched over the screen reads as a soft blur.
                // The old sigma-100 ImageFiltered pass re-blurred the whole
                // screen every frame while the lyrics wheel animated, which is
                // exactly the kind of work that drops frames at 90 Hz.
                return Opacity(
                  opacity: 0.6,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    cacheWidth: 48,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                );
              },
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xA60B0712),
                  Color(0x40140B22),
                  Color(0xCC05060A),
                  AppColors.nearBlack,
                ],
                stops: [0, 0.30, 0.72, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
