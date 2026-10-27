import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../format.dart';
import '../models/lyrics.dart';
import '../models/track.dart';
import '../music_controller.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/frosted.dart';
import '../widgets/glass.dart';
import 'queue_screen.dart';

/// Opens the full-screen player, sliding up over the tabs.
Future<void> showPlayerSheet(BuildContext context, MusicController controller) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => PlayerSheet(controller: controller),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class PlayerSheet extends StatefulWidget {
  const PlayerSheet({super.key, required this.controller});

  final MusicController controller;

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  /// The artwork is the default; lyrics replace it in place, Apple Music style.
  bool _showLyrics = false;

  MusicController get controller => widget.controller;

  void _toggleLyrics() => setState(() => _showLyrics = !_showLyrics);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final track = controller.currentTrack;
        if (track == null) {
          return const Scaffold(
            backgroundColor: canvas,
            body: SafeArea(
              child: Center(child: Text('Nothing is queued up yet')),
            ),
          );
        }

        return Scaffold(
          backgroundColor: canvas,
          body: Stack(
            children: [
              CoverBackdrop(track: track),
              SafeArea(
                child: Column(
                  children: [
                    const _Header(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final artSize = math
                              .min(constraints.maxWidth - 48, 360.0)
                              .clamp(190.0, 360.0);
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 34),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0,
                                  constraints.maxHeight - 44,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Stage(
                                    controller: controller,
                                    track: track,
                                    size: artSize,
                                    showingLyrics: _showLyrics,
                                    onToggle: _toggleLyrics,
                                  ),
                                  const SizedBox(height: 26),
                                  Frosted(
                                    radius: 30,
                                    blur: 32,
                                    tint: AppColors.white.withValues(
                                      alpha: 0.07,
                                    ),
                                    border: Border.all(
                                      color: AppColors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                    glow: true,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        16,
                                        18,
                                        10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _TitleRow(
                                            controller: controller,
                                            track: track,
                                          ),
                                          const SizedBox(height: 10),
                                          _SeekBar(controller: controller),
                                          if (_showLyrics &&
                                              (controller.lyrics?.isTimed ??
                                                  false)) ...[
                                            const SizedBox(height: 10),
                                            _LyricSyncBar(
                                              controller: controller,
                                            ),
                                          ],
                                          const SizedBox(height: 2),
                                          _Transport(controller: controller),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _BottomBar(
                      controller: controller,
                      showingLyrics: _showLyrics,
                      onToggleLyrics: _toggleLyrics,
                    ),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Close',
            size: 40,
            iconSize: 26,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: GlassPill(
                label: 'Now Playing',
                icon: Icons.graphic_eq_rounded,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// The fixed action row at the bottom of the player: the lyrics switch, the
/// one extra view this player has.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.showingLyrics,
    required this.onToggleLyrics,
  });

  final MusicController controller;
  final bool showingLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          _GlassAction(
            icon: Icons.format_quote_rounded,
            label: showingLyrics ? 'Hide lyrics' : 'Lyrics',
            selected: showingLyrics,
            onTap: onToggleLyrics,
          ),
          _GlassAction(
            icon: Icons.queue_music_rounded,
            label: 'Queue',
            onTap: () => showQueueSheet(context, controller),
          ),
        ],
      ),
    );
  }
}

/// A frosted capsule button used under the player controls.
class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Frosted(
        radius: 999,
        blur: 22,
        tint: selected
            ? accent.withValues(alpha: 0.20)
            : AppColors.white.withValues(alpha: 0.065),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.42)
              : AppColors.white.withValues(alpha: 0.14),
        ),
        glow: selected,
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: selected ? accent : AppColors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: selected ? accent : AppColors.white,
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

/// The big accent play button: a green glass orb with a halo.
class _PlayOrb extends StatelessWidget {
  const _PlayOrb({required this.playing, required this.onTap});

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
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF66F29B), AppColors.accent],
            ),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.50),
                blurRadius: 34,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 36,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}

/// Slides the Up Next queue up over the player, Spotify style.
void showQueueSheet(BuildContext context, MusicController controller) {
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
        heightFactor: 0.72,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => QueueScreen(controller: controller),
        ),
      ),
    ),
  );
}

/// The large square at the centre of the player: artwork, or the lyrics that
/// take its place when the quote button is on.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.controller,
    required this.track,
    required this.size,
    required this.showingLyrics,
    required this.onToggle,
  });

  final MusicController controller;
  final Track track;
  final double size;
  final bool showingLyrics;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final lyrics = controller.lyrics;
    final canShowLyrics = lyrics != null || controller.lyricsLoading;

    return SizedBox(
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: showingLyrics
            ? _LyricsStage(
                key: const ValueKey('lyrics'),
                controller: controller,
                height: size,
                onClose: onToggle,
              )
            : GestureDetector(
                key: const ValueKey('cover'),
                onTap: canShowLyrics ? onToggle : null,
                child: AnimatedScale(
                  scale: controller.playing ? 1.0 : 0.94,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  child: _Cover(track: track, size: size),
                ),
              ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.16),
            AppColors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.55),
            blurRadius: 46,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.20),
            blurRadius: 70,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: auroraViolet.withValues(alpha: 0.22),
            blurRadius: 90,
            spreadRadius: -20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CoverArt(track: track, size: size - 10, radius: 24),
      ),
    );
  }
}

class _LyricsStage extends StatelessWidget {
  const _LyricsStage({
    super.key,
    required this.controller,
    required this.height,
    required this.onClose,
  });

  final MusicController controller;
  final double height;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final lyrics = controller.lyrics;

    Widget content;
    if (lyrics == null) {
      content = controller.lyricsLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Looking for lyrics…',
                  style: TextStyle(fontSize: 14, color: mutedText),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No lyrics found for this song.',
                  style: TextStyle(fontSize: 14, color: mutedText),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.reloadLyrics,
                  style: TextButton.styleFrom(foregroundColor: accent),
                  child: const Text('Try again'),
                ),
              ],
            );
    } else if (lyrics.isTimed) {
      content = _SyncedLyrics(
        key: ValueKey(controller.currentTrack?.id),
        controller: controller,
        lyrics: lyrics,
      );
    } else {
      content = SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        child: Text(
          lyrics.text ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: AppColors.white,
          ),
        ),
      );
    }

    return Frosted(
      radius: 26,
      blur: 26,
      tint: AppColors.white.withValues(alpha: 0.055),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
      glow: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                onPressed: onClose,
                tooltip: 'Show cover',
                color: AppColors.muted,
                iconSize: 20,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Apple Music-style lyric view: the active line sits in the middle, the
/// neighbouring lines dim out, and the whole wheel glides to each new line as
/// the song plays.
class _SyncedLyrics extends StatefulWidget {
  const _SyncedLyrics({
    super.key,
    required this.controller,
    required this.lyrics,
  });

  final MusicController controller;
  final Lyrics lyrics;

  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  static const _lineExtent = 82.0;

  late int _index;
  late FixedExtentScrollController _wheel;
  StreamSubscription<Duration>? _position;

  @override
  void initState() {
    super.initState();
    _wheel = FixedExtentScrollController(
      initialItem: math.max(0, _lineAt(widget.controller.position)),
    );
    _index = math.max(0, _lineAt(widget.controller.position));
    _position = widget.controller.positionStream.listen(_jumpTo);
  }

  @override
  void didUpdateWidget(covariant _SyncedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A sync nudge rebuilds the player; re-align immediately instead of waiting
    // for the next position tick.
    _jumpTo(widget.controller.position);
  }

  int _lineAt(Duration position) =>
      widget.lyrics.indexAt(position + widget.controller.lyricOffset);

  void _jumpTo(Duration position) {
    final next = math.max(0, _lineAt(position));
    if (next == _index) return;
    setState(() => _index = next);
    if (_wheel.hasClients) {
      _wheel.animateToItem(
        next,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _position?.cancel();
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _wheel,
      itemExtent: _lineExtent,
      diameterRatio: 2.4,
      perspective: 0.001,
      overAndUnderCenterOpacity: 0.42,
      physics: const NeverScrollableScrollPhysics(),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.lyrics.lines.length,
        builder: (context, index) {
          final current = index == _index;
          return Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.controller.alignLyricsTo(
                widget.lyrics.lines[index].time,
                widget.controller.position,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: current
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.17),
                            accent.withValues(alpha: 0.02),
                          ],
                        )
                      : null,
                  border: current
                      ? Border.all(color: accent.withValues(alpha: 0.24))
                      : null,
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: current ? 24 : 20,
                    height: 1.22,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.4,
                    color: current
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.68),
                  ),
                  child: Text(
                    widget.lyrics.lines[index].text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
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

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.controller, required this.track});

  final MusicController controller;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final favorite = controller.isFavorite(track);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1.14,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                track.album == null ||
                        track.album!.toLowerCase() == 'musicdownload'
                    ? track.artist
                    : '${track.artist} · ${track.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: mutedText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: favorite ? Icons.favorite : Icons.favorite_border,
          tooltip: favorite ? 'Remove from favourites' : 'Add to favourites',
          size: 42,
          iconSize: 22,
          selected: favorite,
          onPressed: () => controller.toggleFavorite(track),
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.controller});

  final MusicController controller;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// Fraction being dragged, null while not dragging.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.controller.durationStream,
      builder: (context, durationSnapshot) {
        return StreamBuilder<Duration>(
          stream: widget.controller.positionStream,
          builder: (context, positionSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;
            final total = duration.inMilliseconds;
            final progress = total <= 0
                ? 0.0
                : (position.inMilliseconds / total).clamp(0.0, 1.0);
            final shown = _drag ?? progress;
            final shownTime = Duration(
              milliseconds: (total * shown).round().clamp(0, total),
            );

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: _drag == null ? 0 : 5,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: shown.clamp(0.0, 1.0),
                    onChanged: total <= 0
                        ? null
                        : (value) => setState(() => _drag = value),
                    onChangeEnd: total <= 0
                        ? null
                        : (value) {
                            widget.controller.seek(
                              Duration(milliseconds: (total * value).round()),
                            );
                            setState(() => _drag = null);
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Text(
                        formatClock(shownTime),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: mutedText,
                          letterSpacing: 0.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatDuration(duration),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: mutedText,
                          letterSpacing: 0.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A small glass strip for nudging the lyrics into perfect sync. LRCLIB is
/// usually close, but a downloaded edit can start a second or two off; the
/// chosen nudge is remembered per song.
class _LyricSyncBar extends StatelessWidget {
  const _LyricSyncBar({required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    final ms = controller.lyricOffsetMs;
    final label = ms == 0
        ? 'In sync'
        : '${ms > 0 ? '+' : '−'}${(ms.abs() / 1000).toStringAsFixed(2)}s';
    return Frosted(
      radius: 18,
      blur: 24,
      tint: AppColors.white.withValues(alpha: 0.055),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync_rounded,
                  size: 17,
                  color: ms == 0 ? mutedText : accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lyrics sync',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                _SyncStep(
                  icon: Icons.remove_rounded,
                  onTap: () => controller.nudgeLyricOffset(-100),
                ),
                SizedBox(
                  width: 66,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: ms == 0 ? mutedText : accent,
                    ),
                  ),
                ),
                _SyncStep(
                  icon: Icons.add_rounded,
                  onTap: () => controller.nudgeLyricOffset(100),
                ),
                IconButton(
                  onPressed: ms == 0 ? null : controller.resetLyricOffset,
                  tooltip: 'Reset lyrics sync',
                  iconSize: 17,
                  color: mutedText,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 25, right: 6, top: 1),
              child: Text(
                'Tap the line being sung to lock the lyrics to this song. '
                'The nudge is saved.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: AppColors.white.withValues(alpha: 0.48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStep extends StatelessWidget {
  const _SyncStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.white),
        ),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GlassIconButton(
            icon: Icons.shuffle_rounded,
            tooltip: 'Shuffle',
            size: 40,
            iconSize: 19,
            selected: controller.shuffleEnabled,
            onPressed: controller.toggleShuffle,
          ),
          IconButton(
            onPressed: controller.previous,
            tooltip: 'Previous',
            iconSize: 38,
            color: AppColors.white.withValues(alpha: 0.92),
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          _PlayOrb(
            playing: controller.playing,
            onTap: controller.togglePlayPause,
          ),
          IconButton(
            onPressed: controller.next,
            tooltip: 'Next',
            iconSize: 38,
            color: AppColors.white.withValues(alpha: 0.92),
            icon: const Icon(Icons.skip_next_rounded),
          ),
          GlassIconButton(
            icon: controller.loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            tooltip: 'Repeat',
            size: 40,
            iconSize: 19,
            selected: controller.loopMode != LoopMode.off,
            onPressed: controller.cycleLoopMode,
          ),
        ],
      ),
    );
  }
}
