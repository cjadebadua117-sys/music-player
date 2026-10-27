import 'package:flutter/material.dart';

import '../format.dart';
import '../music_controller.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/glass.dart';

/// Spotify-style "Up Next" queue. Embedded as a tab, so it returns content
/// rather than a Scaffold. Everything comes from the local library — offline.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    final tracks = controller.library;
    final current = controller.currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: Text('Up Next', style: pageTitleStyle)),
              GlassPill(
                label:
                    '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
                icon: Icons.queue_music_rounded,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(
            'Playing from your library',
            style: TextStyle(fontSize: 13, color: mutedText),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Nothing queued yet. Add songs and they will line up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: mutedText,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isCurrent = current == index;
                    final isPlaying = isCurrent && controller.playing;

                    return Container(
                      margin: const EdgeInsets.fromLTRB(14, 3, 14, 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isCurrent
                              ? [
                                  accent.withValues(alpha: 0.17),
                                  accent.withValues(alpha: 0.035),
                                ]
                              : [
                                  AppColors.white.withValues(alpha: 0.065),
                                  AppColors.white.withValues(alpha: 0.018),
                                ],
                        ),
                        border: Border.all(
                          color: isCurrent
                              ? accent.withValues(alpha: 0.38)
                              : AppColors.white.withValues(alpha: 0.085),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isCurrent
                                ? accent.withValues(alpha: 0.18)
                                : AppColors.black.withValues(alpha: 0.22),
                            blurRadius: isCurrent ? 24 : 16,
                            spreadRadius: -8,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: AppColors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => controller.playTrackAt(index),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                            child: Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CoverArt(
                                      track: track,
                                      size: 50,
                                      radius: 12,
                                    ),
                                    if (isCurrent)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isPlaying
                                              ? Icons.graphic_eq_rounded
                                              : Icons.pause_rounded,
                                          size: 18,
                                          color: accent,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                          color: isCurrent
                                              ? accent
                                              : AppColors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isCurrent
                                              ? accent.withValues(alpha: 0.72)
                                              : mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (track.duration != null)
                                  Text(
                                    formatDuration(track.duration),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: mutedText,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  isCurrent
                                      ? Icons.equalizer_rounded
                                      : Icons.drag_handle_rounded,
                                  size: 20,
                                  color: isCurrent ? accent : mutedText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
