import 'package:flutter/material.dart';

import '../models/track.dart';
import '../music_controller.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/filter_chips.dart';
import '../widgets/frosted.dart';
import '../widgets/glass.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'library_screen.dart';
import 'search_screen.dart';

/// The app shell: three tabs over a violet wash, with the mini player and the
/// tab bar pinned to the bottom, the way the reference app does it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final MusicController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _mood;
  int _tab = 0;

  /// Last playback error already shown, so a rebuild does not repeat it.
  String? _shownError;

  MusicController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_showPlaybackError);
  }

  @override
  void dispose() {
    _controller.removeListener(_showPlaybackError);
    super.dispose();
  }

  void _showPlaybackError() {
    final error = _controller.playbackError;
    if (error == null) {
      _shownError = null;
      return;
    }
    if (error == _shownError) return;
    _shownError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    });
  }

  void _goTo(int tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    // The last nav item is a Spotify-style Create button: it opens the local
    // file picker instead of switching tabs.
    if (tab == 3) {
      _import();
      return;
    }
    setState(() => _tab = tab);
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final count = await _controller.importTracks();
    final message = switch (count) {
      < 0 => 'Adding files works in the installed app',
      0 => 'No songs added',
      1 => 'Added 1 song',
      _ => 'Added $count songs',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rescan() async {
    final messenger = ScaffoldMessenger.of(context);
    await _controller.syncDeviceLibrary();
    final error = _controller.scanError;
    final message = error != null
        ? 'Could not read the music library'
        : _controller.permissionDenied
        ? 'Allow access to your music first'
        : 'Found ${_controller.deviceTracks.length} '
              '${_controller.deviceTracks.length == 1 ? 'song' : 'songs'}';
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _remove(Track track) async {
    final messenger = ScaffoldMessenger.of(context);
    await _controller.removeTrack(track);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          track.isOnDevice
              ? 'Hid "${track.title}" (the file itself is untouched)'
              : 'Removed "${track.title}"',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.ready) {
          return const Scaffold(
            backgroundColor: canvas,
            body: Stack(
              children: [
                Backdrop(),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        }

        final tab = switch (_tab) {
          1 => SearchScreen(
            controller: _controller,
            onClose: () => _goTo(0),
            onRemove: _remove,
          ),
          2 => LibraryScreen(
            controller: _controller,
            onImport: _import,
            onRescan: _rescan,
            onRemove: _remove,
          ),
          _ => _HomeTab(
            controller: _controller,
            mood: _mood,
            onMood: (value) => setState(() => _mood = value),
            onImport: _import,
            onRescan: _rescan,
            onRemove: _remove,
          ),
        };

        return Scaffold(
          backgroundColor: canvas,
          body: Stack(
            children: [
              const Backdrop(),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(child: tab),
                    if (_controller.currentTrack != null)
                      MiniPlayer(controller: _controller),
                    _NavBar(index: _tab, onTap: _goTo),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.controller,
    required this.mood,
    required this.onMood,
    required this.onImport,
    required this.onRescan,
    required this.onRemove,
  });

  final MusicController controller;
  final String? mood;
  final ValueChanged<String?> onMood;
  final VoidCallback onImport;
  final VoidCallback onRescan;
  final ValueChanged<Track> onRemove;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  MusicController get _controller => widget.controller;
  String? get mood => widget.mood;
  ValueChanged<Track> get onRemove => widget.onRemove;
  VoidCallback get onImport => widget.onImport;
  VoidCallback get onRescan => widget.onRescan;
  ValueChanged<String?> get onMood => widget.onMood;

  /// Spotify's clock icon: a playable recently-played list.
  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Frosted(
        radius: 28,
        blur: 34,
        tint: canvas.withValues(alpha: 0.80),
        glow: true,
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final tracks = _controller.recentTracks;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  _SectionHeader(
                    'Recently played',
                    trailing: '${tracks.length}',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        for (final track in tracks)
                          SongTile(
                            track: track,
                            controller: _controller,
                            onRemove: () => onRemove(track),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Spotify's gear icon: the few local options this player has.
  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Frosted(
        radius: 28,
        blur: 34,
        tint: canvas.withValues(alpha: 0.80),
        glow: true,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 6),
                child: Row(
                  children: [Text('Settings', style: sectionTitleStyle)],
                ),
              ),
              ListTile(
                leading: const _SheetIcon(Icons.refresh_rounded),
                title: const Text('Refresh library'),
                textColor: AppColors.white,
                iconColor: AppColors.white,
                onTap: () {
                  Navigator.of(context).pop();
                  onRescan();
                },
              ),
              ListTile(
                leading: const _SheetIcon(Icons.add_rounded),
                title: const Text('Add files'),
                textColor: AppColors.white,
                iconColor: AppColors.white,
                onTap: () {
                  Navigator.of(context).pop();
                  onImport();
                },
              ),
              ListTile(
                leading: const _SheetIcon(
                  Icons.offline_bolt_rounded,
                  color: accent,
                ),
                title: const Text('Everything plays offline'),
                subtitle: const Text('No account, no streaming, no ads.'),
                textColor: AppColors.white,
                subtitleTextStyle: const TextStyle(
                  fontSize: 12.5,
                  color: mutedText,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentlyPlayed = _controller.recentTracks;
    final favoriteTracks = _controller.library
        .where(_controller.isFavorite)
        .toList();
    final mixes = _mixes(recentlyPlayed);
    final nothingYet =
        _controller.deviceTracks.isEmpty && _controller.importedTracks.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _HomeHeader(
          controller: _controller,
          onHistory: _showHistory,
          onSettings: _showSettings,
        ),
        FilterChipBar(
          chips: [
            MusicChip(
              label: 'All',
              selected: mood == null,
              onTap: () => onMood(null),
            ),
            for (final name in MusicController.moodNames)
              MusicChip(
                label: name,
                count: _controller.tracksInMood(name).length,
                selected: mood == name,
                onTap: () => onMood(mood == name ? null : name),
              ),
          ],
        ),
        if (_controller.permissionDenied)
          _PermissionCard(onAllow: _controller.syncDeviceLibrary),
        if (mood != null) ...[
          _SectionHeader(
            '$mood songs',
            trailing: '${_controller.tracksInMood(mood!).length}',
          ),
          if (_controller.tracksInMood(mood!).isEmpty)
            _Message(
              icon: Icons.auto_awesome_rounded,
              text:
                  'Nothing tagged for $mood yet. Open a song\'s ⋮ menu and add '
                  'it to this mood.',
            ),
          for (final track in _controller.tracksInMood(mood!))
            SongTile(
              track: track,
              controller: _controller,
              onRemove: () => onRemove(track),
            ),
        ] else ...[
          _SectionHeader(
            'Recently played',
            trailing: '${recentlyPlayed.length}',
          ),
          if (recentlyPlayed.isNotEmpty)
            _RecentShortcuts(
              tracks: recentlyPlayed.take(6).toList(),
              controller: _controller,
            ),
          if (mixes.isNotEmpty) _SectionHeader('Made for you'),
          if (mixes.isNotEmpty)
            _MixShelf(mixes: mixes, controller: _controller),
          if (favoriteTracks.isNotEmpty) ...[
            _SectionHeader('Liked songs', trailing: '${favoriteTracks.length}'),
            _MixShelf(
              mixes: [
                _Mix(
                  title: 'Liked Songs',
                  tracks: favoriteTracks,
                  cover: favoriteTracks.first,
                ),
              ],
              controller: _controller,
            ),
          ],
        ],
        if (recentlyPlayed.isEmpty &&
            favoriteTracks.isEmpty &&
            mixes.isEmpty &&
            nothingYet &&
            (mood == null))
          const _Message(
            icon: Icons.headphones_rounded,
            text:
                'No music found on this phone yet. Add files below, or play '
                'one of the built-in demos.',
          ),
        _FooterActions(scanning: _controller.scanning, onImport: onImport),
      ],
    );
  }

  List<_Mix> _mixes(List<Track> tracks) {
    final groups = <String, List<Track>>{};
    for (final track in tracks) {
      var album = track.album;
      // Every YouTube download lands in one MediaStore album called
      // "MusicDownload"; that reads like a folder, not a playlist.
      if (album == null ||
          album.isEmpty ||
          album.toLowerCase() == 'musicdownload') {
        album = 'Your downloads';
      }
      groups.putIfAbsent(album, () => []).add(track);
    }
    final mixes = [
      for (final entry in groups.entries)
        _Mix(title: entry.key, tracks: entry.value, cover: entry.value.first),
    ]..sort((a, b) => b.tracks.length.compareTo(a.tracks.length));
    return mixes;
  }
}

/// Spotify's home shortcuts: two columns of small square-ish cards that jump
/// straight back into a recent song, instead of a long list.
class _RecentShortcuts extends StatelessWidget {
  const _RecentShortcuts({required this.tracks, required this.controller});

  final List<Track> tracks;
  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tracks.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.85,
        ),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final at = controller.indexOf(track);
          final current = at >= 0 && controller.isCurrent(at);
          return Material(
            color: AppColors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: at < 0 ? null : () => controller.playTrackAt(at),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: current
                        ? [
                            accent.withValues(alpha: 0.24),
                            accent.withValues(alpha: 0.05),
                          ]
                        : [
                            AppColors.white.withValues(alpha: 0.11),
                            AppColors.white.withValues(alpha: 0.03),
                          ],
                  ),
                  border: Border.all(
                    color: current
                        ? accent.withValues(alpha: 0.38)
                        : AppColors.white.withValues(alpha: 0.11),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      CoverArt(track: track, size: 48, radius: 10),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: current ? accent : AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.controller,
    required this.onHistory,
    required this.onSettings,
  });

  final MusicController controller;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  static String _greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final artists = {
      for (final track in controller.library) track.artist,
    }.length;
    final songs = controller.library.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(onTap: onSettings, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _greeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pageTitleStyle.copyWith(
                    fontSize: 28,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              if (controller.scanning)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              GlassIconButton(
                icon: Icons.history_rounded,
                tooltip: 'Recently played',
                size: 38,
                iconSize: 20,
                onPressed: onHistory,
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.settings_rounded,
                tooltip: 'Settings',
                size: 38,
                iconSize: 19,
                onPressed: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GlassPill(
                label:
                    '$songs ${songs == 1 ? 'song' : 'songs'} · '
                    '$artists ${artists == 1 ? 'artist' : 'artists'}',
                icon: Icons.graphic_eq_rounded,
                accented: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  const _SheetIcon(this.icon, {this.color = mutedText});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.12),
            AppColors.white.withValues(alpha: 0.035),
          ],
        ),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.13)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _Mix {
  const _Mix({required this.title, required this.tracks, required this.cover});

  final String title;
  final List<Track> tracks;
  final Track cover;
}

class _MixShelf extends StatelessWidget {
  const _MixShelf({required this.mixes, required this.controller});

  final List<_Mix> mixes;
  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 2, 24, 10),
        itemCount: mixes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final mix = mixes[index];
          return _MixCard(
            mix: mix,
            onPlay: () {
              final at = controller.indexOf(mix.tracks.first);
              if (at >= 0) controller.playTrackAt(at);
            },
          );
        },
      ),
    );
  }
}

class _MixCard extends StatelessWidget {
  const _MixCard({required this.mix, required this.onPlay});

  final _Mix mix;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPlay,
      child: SizedBox(
        width: 156,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.42),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: SizedBox(
                width: 156,
                height: 156,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CoverArt(track: mix.cover, size: 156, radius: 14),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(11, 16, 11, 9),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.black.withValues(alpha: 0),
                              AppColors.black.withValues(alpha: 0.82),
                            ],
                          ),
                        ),
                        child: Text(
                          mix.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '${mix.tracks.length} '
                '${mix.tracks.length == 1 ? 'song' : 'songs'}',
                style: const TextStyle(fontSize: 12.5, color: mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 9),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 17,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, auroraViolet],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: sectionTitleStyle)),
          if (trailing != null) GlassPill(label: trailing!),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({required this.scanning, required this.onImport});

  final bool scanning;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Row(
        children: [
          Frosted(
            radius: 999,
            blur: 22,
            tint: accent.withValues(alpha: 0.20),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
            glow: true,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onImport,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: accent),
                      SizedBox(width: 7),
                      Text(
                        'Add files',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (scanning)
            const Text(
              'Scanning…',
              style: TextStyle(fontSize: 12, color: mutedText),
            ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.library_music_rounded, color: accent, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Let the app see your music',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Allow access to the songs on this phone and they will show up here '
            'automatically — nothing is copied or changed.',
            style: TextStyle(fontSize: 13, color: mutedText, height: 1.45),
          ),
          const SizedBox(height: 14),
          Material(
            color: accent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onAllow,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text(
                  'Allow access',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 20),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: mutedText,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Home', Icons.home_rounded, Icons.home_outlined),
      ('Search', Icons.search_rounded, Icons.search_rounded),
      (
        'Your Library',
        Icons.library_music_rounded,
        Icons.library_music_outlined,
      ),
      ('Create', Icons.add_rounded, Icons.add_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Frosted(
        radius: 26,
        blur: 30,
        tint: AppColors.white.withValues(alpha: 0.085),
        glow: true,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        label: items[i].$1,
                        icon: index == i ? items[i].$2 : items[i].$3,
                        selected: index == i,
                        onTap: () => onTap(i),
                      ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0.24),
                        accent.withValues(alpha: 0.05),
                      ],
                    )
                  : null,
              border: selected
                  ? Border.all(color: accent.withValues(alpha: 0.22))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: selected
                      ? accent
                      : AppColors.white.withValues(alpha: 0.60),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                    color: selected
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.62),
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
