import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/lyrics_service.dart';
import 'package:music_player/main.dart';
import 'package:music_player/models/lyrics.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/music_controller.dart';
import 'package:music_player/screens/player_sheet.dart';
import 'package:music_player/widgets/mini_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_engine.dart';
import 'fake_lyrics.dart';
import 'fake_scanner.dart';

/// Matches song titles inside any scrolling surface (the home recent grid, a
/// library list, or search results), not the mini player or now-playing screen.
Finder inLibrary(String text) =>
    find.descendant(of: find.byType(Scrollable), matching: find.text(text));

Future<MusicController> _pumpApp(
  WidgetTester tester,
  FakeEngine engine, {
  FakeScanner? scanner,
  LyricsService? lyrics,
  Map<String, Object> prefs = const {},
}) async {
  // A phone-shaped surface (360 x 800 logical): the default 800 x 600 test
  // window is shorter than any phone this app targets, so the lists would be
  // clipped before the song rows and finders would miss visible-in-real-life
  // widgets.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(prefs);
  final controller = MusicController(
    engine,
    scanner: scanner ?? FakeScanner(),
    lyrics: lyrics ?? FakeLyrics(),
    lyricsLookup: FakeLyricsLookup(),
  );
  await controller.init();
  await controller.queueReady;
  await controller.deviceSync;
  await tester.pumpWidget(MusicApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('shows songs, mixes and the greeting header', (tester) async {
    final scanner = FakeScanner(
      songs: [
        mediaStoreTrack(
          1,
          title: 'Museo',
          artist: 'Eliza',
          album: 'Shadows',
          duration: const Duration(minutes: 3, seconds: 24),
        ),
        mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
      ],
    );
    await _pumpApp(tester, FakeEngine(), scanner: scanner);

    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Made for you'), findsOneWidget);
    expect(inLibrary('Museo'), findsOneWidget);
    expect(inLibrary('August'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);

    // The duration stamp now lives on the full library tile.
    await tester.tap(find.byTooltip('Your Library'));
    await tester.pumpAndSettle();
    expect(find.text('3:24'), findsOneWidget);
  });

  testWidgets('asks for access when music access was denied, then recovers', (
    tester,
  ) async {
    final scanner = FakeScanner(permission: false);
    final controller = await _pumpApp(tester, FakeEngine(), scanner: scanner);

    expect(controller.permissionDenied, isTrue);
    expect(find.text('Let the app see your music'), findsOneWidget);

    // The user grants access and taps the button.
    scanner.permission = true;
    scanner.songs = [
      mediaStoreTrack(5, title: 'Kung Ika Ikaw', artist: 'Zack'),
    ];
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();

    expect(find.text('Let the app see your music'), findsNothing);
    expect(inLibrary('Kung Ika Ikaw'), findsOneWidget);
  });

  testWidgets('a phone with no music falls back to the demos', (tester) async {
    await _pumpApp(tester, FakeEngine());

    expect(find.text('Recently played'), findsOneWidget);
    expect(inLibrary('Warm Up'), findsOneWidget);
    expect(find.byType(MiniPlayer), findsOneWidget);
  });

  testWidgets('the tab bar opens Your Library and Search', (tester) async {
    final scanner = FakeScanner(
      songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
    );
    await _pumpApp(tester, FakeEngine(), scanner: scanner);

    await tester.tap(find.byTooltip('Your Library'));
    await tester.pumpAndSettle();
    expect(find.text('Liked'), findsOneWidget);
    expect(inLibrary('Museo'), findsOneWidget);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Browse all'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('No songs in Focus yet.'), findsOneWidget);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.text('Recently played'), findsOneWidget);
  });

  testWidgets('tapping a song starts playback and reveals the mini player', (
    tester,
  ) async {
    final engine = FakeEngine();
    await _pumpApp(tester, engine);

    await tester.tap(inLibrary('Pulse'));
    await tester.pumpAndSettle();

    expect(engine.playing, isTrue);
    expect(engine.currentIndex, 1);
    expect(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.text('Pulse'),
      ),
      findsOneWidget,
    );
    final bar = find.byType(MiniPlayer);
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.pause_rounded)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: bar, matching: find.byIcon(Icons.pause_rounded)),
    );
    await tester.pumpAndSettle();
    expect(engine.playing, isFalse);
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.play_arrow_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('mini player progress follows the playback position', (
    tester,
  ) async {
    final engine = FakeEngine();
    await _pumpApp(tester, engine);

    await tester.tap(inLibrary('Warm Up'));
    await tester.pumpAndSettle();

    engine.emitPosition(const Duration(seconds: 15)); // half of the 30s fake
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.01));
  });

  testWidgets('a tap on a mix card plays its songs', (tester) async {
    final scanner = FakeScanner(
      songs: [
        mediaStoreTrack(1, title: 'Museo', artist: 'Eliza', album: 'Shadows'),
        mediaStoreTrack(2, title: 'August', artist: 'Eliza', album: 'Shadows'),
      ],
    );
    final engine = FakeEngine();
    await _pumpApp(tester, engine, scanner: scanner);

    expect(find.text('Shadows'), findsOneWidget);
    expect(find.text('2 songs'), findsOneWidget);

    await tester.tap(find.text('Shadows'));
    await tester.pumpAndSettle();
    expect(engine.playing, isTrue);
    expect(engine.currentIndex, 0);
  });

  testWidgets('now playing shows the track and toggles shuffle/repeat', (
    tester,
  ) async {
    final engine = FakeEngine();
    final controller = await _pumpApp(tester, engine);

    await tester.ensureVisible(inLibrary('Drift'));
    await tester.pumpAndSettle();
    await tester.tap(inLibrary('Drift'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();

    // Scoped to the player: the mini player underneath has its own icons.
    Finder inPlayer(IconData icon) => find.descendant(
      of: find.byType(PlayerSheet),
      matching: find.byIcon(icon),
    );

    expect(find.text('Now Playing'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlayerSheet),
        matching: find.text('Drift'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PlayerSheet),
        matching: find.text('Built-in demo'),
      ),
      findsOneWidget,
    );
    expect(inPlayer(Icons.shuffle_rounded), findsOneWidget);
    expect(inPlayer(Icons.skip_next_rounded), findsOneWidget);

    await tester.ensureVisible(inPlayer(Icons.shuffle_rounded));
    await tester.pumpAndSettle();
    await tester.tap(inPlayer(Icons.shuffle_rounded));
    await tester.pumpAndSettle();
    expect(controller.shuffleEnabled, isTrue);

    // Last song, repeat off: next has nowhere to go.
    await tester.tap(inPlayer(Icons.skip_next_rounded));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);

    await tester.ensureVisible(inPlayer(Icons.repeat_rounded));
    await tester.pumpAndSettle();
    await tester.tap(inPlayer(Icons.repeat_rounded));
    await tester.pumpAndSettle();
    await tester.tap(inPlayer(Icons.skip_next_rounded));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0); // repeat-all wrapped to the first song
  });

  testWidgets('swiping an imported song removes it from the library', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.createTempSync('songs').path}/Artist - Song.mp3',
    )..writeAsBytesSync(const [0, 1, 2, 3]);
    final engine = FakeEngine();
    final controller = await _pumpApp(
      tester,
      engine,
      prefs: {
        'library.v1': jsonEncode([
          {
            'id': 'user-1',
            'title': 'Song',
            'artist': 'Artist',
            'path': file.path,
          },
        ]),
      },
    );

    await tester.tap(find.byTooltip('Your Library'));
    await tester.pumpAndSettle();
    expect(inLibrary('Song'), findsOneWidget);

    await tester.drag(inLibrary('Song'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Song'), findsNothing);
    expect(controller.importedTracks, isEmpty);
    expect(engine.sources, hasLength(demoTracks.length)); // demos are back
  });

  testWidgets('search narrows the list to matching songs', (tester) async {
    final scanner = FakeScanner(
      songs: [
        mediaStoreTrack(1, title: 'Museo', artist: 'Eliza'),
        mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
      ],
    );
    final controller = await _pumpApp(tester, FakeEngine(), scanner: scanner);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'august');
    await tester.pumpAndSettle();

    expect(inLibrary('August'), findsOneWidget);
    expect(inLibrary('Museo'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing here');
    await tester.pumpAndSettle();
    expect(find.textContaining('No songs match'), findsOneWidget);

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(inLibrary('Museo'), findsOneWidget);
    expect(controller.library, hasLength(2));
  });

  testWidgets('lyrics load by themselves and follow playback', (tester) async {
    final lyrics = FakeLyrics(
      lyrics: Lyrics.parse('[00:01.00]First line\n[00:05.00]Second line')!,
    );
    final engine = FakeEngine();
    final scanner = FakeScanner(
      songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
    );
    await _pumpApp(tester, engine, scanner: scanner, lyrics: lyrics);

    await tester.tap(inLibrary('Museo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();

    expect(lyrics.loads, 1); // fetched automatically, no button to press

    // The artwork is shown first; the quote button swaps in the lyrics.
    await tester.tap(find.byTooltip('Lyrics'));
    await tester.pumpAndSettle();
    expect(find.text('First line'), findsOneWidget);

    engine.emitPosition(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    // The size lives on the animated default text style, so check what the
    // paragraph actually paints rather than the Text widget's own style.
    final highlighted = tester.renderObject<RenderParagraph>(
      find.text('Second line'),
    );
    expect(highlighted.text.style?.fontSize, 24);
  });

  testWidgets('a saved favourite shows a filled heart in the player', (
    tester,
  ) async {
    final scanner = FakeScanner(
      songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
    );
    final controller = await _pumpApp(tester, FakeEngine(), scanner: scanner);
    await controller.toggleFavorite(controller.library.single);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();

    expect(controller.isFavorite(controller.library.single), isTrue);
    expect(
      find.descendant(
        of: find.byType(PlayerSheet),
        matching: find.byIcon(Icons.favorite),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the song menu favourites and tags a mood', (tester) async {
    final scanner = FakeScanner(
      songs: [
        mediaStoreTrack(1, title: 'Museo', artist: 'Eliza'),
        mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
      ],
    );
    final controller = await _pumpApp(tester, FakeEngine(), scanner: scanner);

    await tester.tap(find.byTooltip('Your Library'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Song options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Song options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    expect(controller.isFavorite(controller.library.first), isTrue);

    // Tag the first song for Focus, then use the chip to filter the feed.
    await tester.tap(find.byTooltip('Song options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Focus'));
    await tester.pumpAndSettle();
    expect(controller.isInMood(controller.library.first, 'Focus'), isTrue);

    await tester.ensureVisible(find.text('Focus · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus · 1'));
    await tester.pumpAndSettle();
    expect(inLibrary('Museo'), findsOneWidget);
    expect(inLibrary('August'), findsNothing);

    // Reopening the library starts on the full All list again.
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your Library'));
    await tester.pumpAndSettle();
    expect(inLibrary('August'), findsOneWidget);
  });
}
