import 'package:flutter/material.dart';

import '../models/track.dart';
import '../music_controller.dart';
import '../theme.dart';
import '../widgets/frosted.dart';
import '../widgets/glass.dart';
import '../widgets/song_tile.dart';

/// Search over the whole library, plus a browse-all grid of the moods when the
/// field is empty — the same pair of states the reference app has.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onRemove,
  });

  final MusicController controller;
  final VoidCallback onClose;
  final ValueChanged<Track> onRemove;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _field = TextEditingController();
  String _query = '';
  String? _browse;

  MusicController get _controller => widget.controller;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  List<Track> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final track in _controller.library)
        if (track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query) ||
            (track.album ?? '').toLowerCase().contains(query))
          track,
    ];
  }

  void _clear() {
    _field.clear();
    setState(() {
      _query = '';
      _browse = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final results = _results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
          child: Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Close search',
                size: 40,
                iconSize: 21,
                onPressed: widget.onClose,
              ),
              const SizedBox(width: 12),
              const Text('Search', style: pageTitleStyle),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
          child: Frosted(
            radius: 14,
            blur: 20,
            tint: AppColors.white.withValues(alpha: 0.94),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.55)),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: AppColors.black,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _field,
                      onChanged: (value) => setState(() {
                        _query = value;
                        _browse = null;
                      }),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                      cursorColor: accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Songs, artists, albums',
                        hintStyle: TextStyle(
                          color: AppColors.black.withValues(alpha: 0.55),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      onPressed: _clear,
                      tooltip: 'Clear search',
                      iconSize: 20,
                      color: AppColors.black.withValues(alpha: 0.6),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: searching
              ? _Results(
                  query: _query,
                  results: results,
                  controller: _controller,
                  onRemove: widget.onRemove,
                )
              : _browse == null
              ? _Browse(
                  controller: _controller,
                  onOpen: (mood) => setState(() => _browse = mood),
                )
              : _MoodSongs(
                  mood: _browse!,
                  controller: _controller,
                  onRemove: widget.onRemove,
                  onClear: () => setState(() => _browse = null),
                ),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.results,
    required this.controller,
    required this.onRemove,
  });

  final String query;
  final List<Track> results;
  final MusicController controller;
  final ValueChanged<Track> onRemove;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Text(
          'No songs match "${query.trim()}"',
          style: const TextStyle(fontSize: 13.5, color: mutedText, height: 1.5),
        ),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 6),
          child: Text(
            '${results.length} ${results.length == 1 ? 'result' : 'results'}',
            style: const TextStyle(fontSize: 13, color: mutedText),
          ),
        ),
        for (final track in results)
          SongTile(
            track: track,
            controller: controller,
            onRemove: () => onRemove(track),
          ),
      ],
    );
  }
}

class _Browse extends StatelessWidget {
  const _Browse({required this.controller, required this.onOpen});

  final MusicController controller;
  final ValueChanged<String> onOpen;

  static const _cards = [
    (
      'All songs',
      Icons.graphic_eq_rounded,
      [AppColors.auroraViolet, AppColors.auroraCyan],
    ),
    (
      'Focus',
      Icons.center_focus_strong_rounded,
      [AppColors.accent, AppColors.auroraCyan],
    ),
    (
      'Chill',
      Icons.nightlight_round,
      [AppColors.auroraIndigo, AppColors.auroraViolet],
    ),
    (
      'Gym',
      Icons.fitness_center_rounded,
      [AppColors.auroraPink, AppColors.auroraViolet],
    ),
  ];

  int _count(String name) => name == 'All songs'
      ? controller.library.length
      : controller.tracksInMood(name).length;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      children: [
        const Text('Browse all', style: sectionTitleStyle),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.55,
          children: [
            for (final card in _cards)
              _BrowseCard(
                label: card.$1,
                icon: card.$2,
                colors: card.$3,
                count: _count(card.$1),
                onTap: () => onOpen(card.$1 == 'All songs' ? 'All' : card.$1),
              ),
          ],
        ),
      ],
    );
  }
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard({
    required this.label,
    required this.icon,
    required this.colors,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.26),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.first.withValues(alpha: 0.92),
                colors.last.withValues(alpha: 0.55),
              ],
            ),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.17)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.center,
                        colors: [
                          AppColors.white.withValues(alpha: 0.22),
                          AppColors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -10,
                  bottom: -12,
                  child: Transform.rotate(
                    angle: -0.28,
                    child: Icon(
                      icon,
                      size: 80,
                      color: AppColors.black.withValues(alpha: 0.20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.13),
                          ),
                        ),
                        child: Text(
                          '$count ${count == 1 ? 'song' : 'songs'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: 0.90),
                          ),
                        ),
                      ),
                    ],
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

class _MoodSongs extends StatelessWidget {
  const _MoodSongs({
    required this.mood,
    required this.controller,
    required this.onRemove,
    required this.onClear,
  });

  final String mood;
  final MusicController controller;
  final ValueChanged<Track> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final songs = mood == 'All'
        ? controller.library
        : controller.tracksInMood(mood);
    final title = mood == 'All' ? 'All songs' : mood;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 14, 6),
          child: Row(
            children: [
              Expanded(child: Text(title, style: sectionTitleStyle)),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
        ),
        if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'No songs in $title yet.',
              style: const TextStyle(fontSize: 13.5, color: mutedText),
            ),
          ),
        for (final track in songs)
          SongTile(
            track: track,
            controller: controller,
            onRemove: () => onRemove(track),
          ),
      ],
    );
  }
}
