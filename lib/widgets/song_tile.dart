import 'package:flutter/material.dart';

import '../format.dart';
import '../models/track.dart';
import '../music_controller.dart';
import '../theme.dart';
import 'cover_art.dart';

/// One song in a list, laid out the way the reference does it: cover, title
/// over artist, length, then the ⋮ menu. Used by Home, Library and Search so
/// every list behaves the same.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.track,
    required this.controller,
    required this.onRemove,
    this.showAlbum = false,
  });

  final Track track;
  final MusicController controller;
  final VoidCallback onRemove;

  /// Show the album instead of the artist as the second line (used by search).
  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    final index = controller.indexOf(track);
    final isCurrent = index >= 0 && controller.isCurrent(index);
    final isPlaying = index >= 0 && controller.isPlayingIndex(index);
    final album = track.album;
    final subtitle =
        showAlbum && album != null && album.toLowerCase() != 'musicdownload'
        ? album
        : track.artist;
    final isOnDevice = track.isOnDevice;

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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
        // Only the playing row gets a bloom. A blurred shadow on every row
        // means dozens of extra raster passes per scroll frame on a 60/90 Hz
        // phone; the flat rows still read as glass thanks to the rim light.
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: index < 0 ? null : () => controller.playTrackAt(index),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 7, 3, 7),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CoverArt(track: track, size: 50, radius: 12),
                    if (isCurrent)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.pause_rounded,
                          size: 18,
                          color: accent,
                        ),
                      ),
                    if (!isOnDevice)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.offline,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cloud_done_rounded,
                            color: AppColors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: isCurrent ? accent : AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                const SizedBox(width: 6),
                Text(
                  formatDuration(track.duration),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: mutedText,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (!isOnDevice)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6),
                    child: Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.offline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _SongMenu(
                  track: track,
                  controller: controller,
                  onRemove: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (track.demo) return row;

    return Dismissible(
      key: ValueKey(track.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.offline.withValues(alpha: 0.04),
              AppColors.offline.withValues(alpha: 0.24),
            ],
          ),
          border: Border.all(color: AppColors.offline.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: accent),
      ),
      child: row,
    );
  }
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({
    required this.track,
    required this.controller,
    required this.onRemove,
  });

  final Track track;
  final MusicController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final favorite = controller.isFavorite(track);
    return PopupMenuButton<String>(
      tooltip: 'Song options',
      color: panelHigh,
      iconSize: 20,
      icon: const Icon(Icons.more_vert_rounded, color: mutedText),
      onSelected: (value) async {
        if (value == 'play') {
          final index = controller.indexOf(track);
          if (index >= 0) await controller.playTrackAt(index);
        } else if (value == 'favorite') {
          await controller.toggleFavorite(track);
        } else if (value.startsWith('mood:')) {
          await controller.toggleMood(track, value.substring(5));
        } else if (value == 'remove') {
          onRemove();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'play',
          child: _MenuLabel(icon: Icons.play_arrow_rounded, text: 'Play'),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: _MenuLabel(
            icon: favorite ? Icons.favorite : Icons.favorite_border,
            text: favorite ? 'Remove from favourites' : 'Add to favourites',
            color: favorite ? accent : null,
          ),
        ),
        for (final mood in MusicController.moodNames)
          PopupMenuItem(
            value: 'mood:$mood',
            child: _MenuLabel(
              icon: controller.isInMood(track, mood)
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              text: 'Add to $mood',
              color: controller.isInMood(track, mood) ? accent : null,
            ),
          ),
        if (!track.demo)
          PopupMenuItem(
            value: 'remove',
            child: _MenuLabel(
              icon: Icons.visibility_off_outlined,
              text: track.isOnDevice ? 'Hide from library' : 'Remove',
            ),
          ),
      ],
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? mutedText),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: color),
          ),
        ),
      ],
    );
  }
}
