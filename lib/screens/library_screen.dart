import 'package:flutter/material.dart';

import '../models/track.dart';
import '../music_controller.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/filter_chips.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';

/// Everything saved in the app: every song, the hearted ones, and the mood
/// tags, behind a shrinking pill row.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onImport,
    required this.onRescan,
    required this.onRemove,
  });

  final MusicController controller;
  final VoidCallback onImport;
  final VoidCallback onRescan;
  final ValueChanged<Track> onRemove;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = 'All';
  String _sort = 'Recents';
  bool _grid = false;

  MusicController get _controller => widget.controller;

  List<Track> get _songs => switch (_filter) {
    'All' => _controller.library,
    'Liked' => [
      for (final track in _controller.library)
        if (_controller.isFavorite(track)) track,
    ],
    final mood => _controller.tracksInMood(mood),
  };

  /// Spotify's sort menu: recent first (the default), title, or artist.
  List<Track> _sorted(List<Track> songs) {
    final copy = [...songs];
    switch (_sort) {
      case 'A–Z':
        copy.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case 'Artist':
        copy.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
      default:
        break;
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final songs = _sorted(_songs);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
          child: Row(
            children: [
              const ProfileAvatar(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your Library',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pageTitleStyle.copyWith(fontSize: 28),
                ),
              ),
              GlassIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add files',
                size: 38,
                iconSize: 21,
                onPressed: widget.onImport,
              ),
              const SizedBox(width: 7),
              if (_controller.scanning)
                const Padding(
                  padding: EdgeInsets.all(11),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                GlassIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh library',
                  size: 38,
                  iconSize: 19,
                  onPressed: widget.onRescan,
                ),
            ],
          ),
        ),
        FilterChipBar(
          chips: [
            MusicChip(
              label: 'All',
              selected: _filter == 'All',
              onTap: () => setState(() => _filter = 'All'),
            ),
            MusicChip(
              label: 'Liked',
              count: _controller.library.where(_controller.isFavorite).length,
              selected: _filter == 'Liked',
              onTap: () => setState(() => _filter = 'Liked'),
            ),
            for (final mood in MusicController.moodNames)
              MusicChip(
                label: mood,
                count: _controller.tracksInMood(mood).length,
                selected: _filter == mood,
                onTap: () => setState(() => _filter = mood),
              ),
          ],
        ),
        if (_filter == 'All')
          _LikedCard(
            count: _controller.library.where(_controller.isFavorite).length,
            onTap: () => setState(() => _filter = 'Liked'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
          child: Row(
            children: [
              GlassPill(
                label:
                    '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                color: panelHigh,
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Recents', child: Text('Recents')),
                  PopupMenuItem(value: 'A–Z', child: Text('A–Z')),
                  PopupMenuItem(value: 'Artist', child: Text('Artist')),
                ],
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.white.withValues(alpha: 0.10),
                        AppColors.white.withValues(alpha: 0.03),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sort,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 19,
                        color: mutedText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                tooltip: _grid ? 'List view' : 'Grid view',
                size: 36,
                iconSize: 19,
                onPressed: () => setState(() => _grid = !_grid),
              ),
            ],
          ),
        ),
        if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              switch (_filter) {
                'All' =>
                  'Your library is empty. Add files or refresh to find '
                      'the music on this phone.',
                'Liked' =>
                  'Songs you heart show up here. Open a song\'s ⋮ '
                      'menu to add one.',
                _ =>
                  'Nothing is tagged for $_filter yet. Use a song\'s ⋮ menu '
                      'to add it.',
              },
              style: const TextStyle(
                fontSize: 13,
                color: mutedText,
                height: 1.5,
              ),
            ),
          ),
        if (_grid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) => _GridTile(
              track: songs[index],
              controller: _controller,
              onTap: () =>
                  _controller.playTrackAt(_controller.indexOf(songs[index])),
            ),
          )
        else
          for (final track in songs)
            SongTile(
              track: track,
              controller: _controller,
              onRemove: () => widget.onRemove(track),
            ),
      ],
    );
  }
}

/// Spotify's pinned Liked Songs shelf: a violet gradient card at the top of
/// the library that opens the hearted songs.
class _LikedCard extends StatelessWidget {
  const _LikedCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4C1D95),
                  Color(0xFF7C3AED),
                  Color(0xFF0891B2),
                ],
              ),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: auroraViolet.withValues(alpha: 0.24),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.16),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Liked Songs',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count ${count == 1 ? 'song' : 'songs'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spotify's library grid tile: square cover with title and artist underneath.
class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.track,
    required this.controller,
    required this.onTap,
  });

  final Track track;
  final MusicController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = controller.currentTrack?.id == track.id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: current
                ? [
                    accent.withValues(alpha: 0.16),
                    accent.withValues(alpha: 0.03),
                  ]
                : [
                    AppColors.white.withValues(alpha: 0.075),
                    AppColors.white.withValues(alpha: 0.02),
                  ],
          ),
          border: Border.all(
            color: current
                ? accent.withValues(alpha: 0.34)
                : AppColors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.32),
              blurRadius: 20,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(
                      track: track,
                      size: constraints.maxWidth,
                      radius: 14,
                    ),
                    if (current)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          controller.playing
                              ? Icons.graphic_eq_rounded
                              : Icons.pause_rounded,
                          color: accent,
                          size: 30,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: current ? accent : AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
