import 'package:flutter/material.dart';

import '../music_controller.dart';
import '../screens/player_sheet.dart';
import '../theme.dart';
import 'cover_art.dart';
import 'frosted.dart';

/// Compact playback bar that floats just above the tab bar: tap it for the
/// full player, or use the play / next buttons without leaving the current tab.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Frosted(
        radius: 22,
        blur: 30,
        tint: AppColors.white.withValues(alpha: 0.085),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.15)),
        glow: true,
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => showPlayerSheet(context, controller),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 5, 8),
                  child: Row(
                    children: [
                      CoverArt(track: track, size: 48, radius: 13),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _RoundPlayButton(
                        playing: controller.playing,
                        onTap: controller.togglePlayPause,
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        onPressed: controller.next,
                        tooltip: 'Next',
                        iconSize: 26,
                        color: AppColors.white.withValues(alpha: 0.86),
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                  child: _ProgressLine(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundPlayButton extends StatelessWidget {
  const _RoundPlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF74F2A4), AppColors.accent],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.40),
                blurRadius: 22,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 25,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: controller.durationStream,
      builder: (context, durationSnapshot) {
        return StreamBuilder<Duration>(
          stream: controller.positionStream,
          builder: (context, positionSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;
            final total = duration.inMilliseconds;
            final value = total <= 0
                ? 0.0
                : (position.inMilliseconds / total).clamp(0.0, 1.0);
            return DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: AppColors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4BE58A)),
              ),
            );
          },
        );
      },
    );
  }
}
