import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/app/lyrics_lookup.dart';
import 'package:music_player/app/lyrics_service.dart';
import 'package:music_player/models/lyrics.dart';
import 'package:music_player/models/track.dart';
import 'package:music_player/music_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_engine.dart';
import 'fake_lyrics.dart';
import 'fake_scanner.dart';

const _libraryKey = 'library.v1';

Future<MusicController> _readyController(
  FakeEngine engine, {
  FakeScanner? scanner,
  LyricsService? lyrics,
  LyricsLookup? lyricsLookup,
}) async {
  final controller = MusicController(
    engine,
    scanner: scanner ?? FakeScanner(),
    lyrics: lyrics ?? FakeLyrics(),
    lyricsLookup: lyricsLookup ?? FakeLyricsLookup(),
  );
  await controller.init();
  await controller.queueReady; // initial queue load runs in the background
  await controller.deviceSync; // and so does the device library scan
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('device library', () {
    test('songs on the phone appear automatically', () async {
      final engine = FakeEngine();
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(
            1,
            title: 'Museo',
            artist: 'Eliza',
            duration: const Duration(minutes: 3, seconds: 24),
          ),
          mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
        ],
      );

      final controller = await _readyController(engine, scanner: scanner);

      expect(controller.deviceTracks.map((t) => t.title), ['Museo', 'August']);
      expect(
        controller.deviceTracks.first.duration,
        const Duration(minutes: 3, seconds: 24),
      );
      // The demos step aside once the phone has real music.
      expect(controller.bundledTracks, isEmpty);
      expect(engine.sources, hasLength(2));
      // permission was already granted: nothing to ask
      expect(scanner.permissionRequests, 0);
    });

    test('asks for permission once, then remembers the answer', () async {
      final scanner = FakeScanner(permission: false);
      final first = await _readyController(FakeEngine(), scanner: scanner);

      expect(scanner.permissionRequests, 1);
      expect(first.permissionDenied, isTrue);
      expect(first.deviceTracks, isEmpty);
      expect(
        first.library,
        hasLength(demoTracks.length),
      ); // demos to fall back on

      // A later launch reuses the stored answer instead of prompting again.
      final second = await _readyController(FakeEngine(), scanner: scanner);
      expect(
        scanner.permissionRequests,
        1,
        reason: 'must not nag on every start',
      );
      expect(second.permissionDenied, isTrue);
    });

    test('the allow button re-requests and fills the library', () async {
      final scanner = FakeScanner(permission: false);
      final controller = await _readyController(FakeEngine(), scanner: scanner);
      expect(controller.permissionDenied, isTrue);

      scanner.permission = true;
      scanner.songs = [mediaStoreTrack(7, title: 'Museo', artist: 'Eliza')];
      await controller.syncDeviceLibrary();

      expect(controller.permissionDenied, isFalse);
      expect(controller.deviceTracks.map((t) => t.title), ['Museo']);
      expect(controller.bundledTracks, isEmpty);
    });

    test('a rescan keeps your place and picks up new songs', () async {
      final engine = FakeEngine();
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(1, title: 'First'),
          mediaStoreTrack(2, title: 'Second'),
          mediaStoreTrack(3, title: 'Third'),
        ],
      );
      final controller = await _readyController(engine, scanner: scanner);

      // Play the middle song: a rescan must not jump back to song one.
      await controller.playTrackAt(1);
      await controller.seek(const Duration(seconds: 12));

      scanner.songs = [
        mediaStoreTrack(1, title: 'First'),
        mediaStoreTrack(2, title: 'Second'),
        mediaStoreTrack(3, title: 'Third'),
        mediaStoreTrack(4, title: 'Fourth'),
      ];
      await controller.syncDeviceLibrary();

      expect(controller.deviceTracks, hasLength(4));
      expect(controller.currentTrack?.title, 'Second');
      expect(engine.playing, isTrue);
      expect(engine.position, const Duration(seconds: 12));
    });

    test(
      'hiding a song from the phone keeps it hidden after a rescan',
      () async {
        final scanner = FakeScanner(
          songs: [
            mediaStoreTrack(1, title: 'Keep'),
            mediaStoreTrack(2, title: 'Hide me'),
          ],
        );
        final controller = await _readyController(
          FakeEngine(),
          scanner: scanner,
        );

        await controller.removeTrack(controller.deviceTracks.last);
        expect(controller.deviceTracks.map((t) => t.title), ['Keep']);

        await controller.syncDeviceLibrary();
        expect(controller.deviceTracks.map((t) => t.title), ['Keep']);
      },
    );

    test('a phone with no music still shows the demos', () async {
      final controller = await _readyController(FakeEngine());

      expect(controller.deviceTracks, isEmpty);
      expect(controller.bundledTracks, hasLength(demoTracks.length));
    });

    test('a song that was imported by hand is not listed twice', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('songs').path}/Chase Atlantic - August.mp3',
      )..writeAsBytesSync(const [0, 1, 2]);
      SharedPreferences.setMockInitialValues({
        _libraryKey: jsonEncode([
          {
            'id': 'user-1',
            'title': 'August',
            'artist': 'Chase Atlantic',
            'path': file.path,
          },
        ]),
      });
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(9, title: 'August', artist: 'Chase Atlantic'),
          mediaStoreTrack(10, title: 'Museo', artist: 'Eliza'),
        ],
      );

      final controller = await _readyController(FakeEngine(), scanner: scanner);

      expect(controller.deviceTracks, hasLength(2));
      expect(controller.importedTracks, isEmpty); // the phone copy wins
      expect(controller.library.map((t) => t.title), ['August', 'Museo']);
    });
  });

  group('playback', () {
    test('tapping a song plays it and keeps the queue in step', () async {
      final engine = FakeEngine();
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(1, title: 'First'),
          mediaStoreTrack(2, title: 'Second'),
        ],
      );
      final controller = await _readyController(engine, scanner: scanner);

      await controller.playTrackAt(1);

      expect(controller.currentIndex, 1);
      expect(controller.currentTrack?.title, 'Second');
      expect(engine.playing, isTrue);
      expect(controller.isPlayingIndex(1), isTrue);
    });

    test('play/pause toggles without losing position', () async {
      final engine = FakeEngine();
      final controller = await _readyController(engine);

      await controller.playTrackAt(0);
      engine.emitPosition(const Duration(seconds: 7));
      await controller.togglePlayPause();
      expect(controller.playing, isFalse);

      await controller.togglePlayPause();
      expect(controller.playing, isTrue);
      expect(engine.position, const Duration(seconds: 7));
    });

    test(
      'next stops at the end of the queue unless repeat-all is on',
      () async {
        final engine = FakeEngine();
        final controller = await _readyController(engine);

        await controller.playTrackAt(demoTracks.length - 1);
        await controller.next();
        expect(controller.currentIndex, demoTracks.length - 1);

        await controller.cycleLoopMode(); // off -> all
        expect(controller.loopMode, LoopMode.all);
        await controller.next();
        expect(controller.currentIndex, 0);
      },
    );

    test('previous restarts the song once past three seconds', () async {
      final engine = FakeEngine();
      final controller = await _readyController(engine);

      await controller.playTrackAt(1);
      engine.emitPosition(const Duration(seconds: 12));
      await controller.previous();
      expect(controller.currentIndex, 1);
      expect(engine.position, Duration.zero);

      await controller.previous();
      expect(controller.currentIndex, 0);
    });

    test(
      'loop mode cycles off -> all -> one -> off and shuffle flips',
      () async {
        final controller = await _readyController(FakeEngine());

        await controller.cycleLoopMode();
        expect(controller.loopMode, LoopMode.all);
        await controller.cycleLoopMode();
        expect(controller.loopMode, LoopMode.one);
        await controller.cycleLoopMode();
        expect(controller.loopMode, LoopMode.off);

        await controller.toggleShuffle();
        expect(controller.shuffleEnabled, isTrue);
        await controller.toggleShuffle();
        expect(controller.shuffleEnabled, isFalse);
      },
    );

    test('a broken song reports an error instead of dying silently', () async {
      final engine = FakeEngine();
      final controller = await _readyController(
        engine,
        scanner: FakeScanner(songs: [mediaStoreTrack(1, title: 'Bad song')]),
      );

      await controller.playTrackAt(0);
      engine.emitError(PlayerException(1, 'Unsupported format', 0));
      await Future<void>.delayed(Duration.zero);

      expect(controller.playbackError, contains('Bad song'));
      expect(controller.playbackError, contains('Unsupported format'));

      controller.clearPlaybackError();
      expect(controller.playbackError, isNull);
    });
  });

  group('imported songs', () {
    test('a demo cannot be removed', () async {
      final engine = FakeEngine();
      final controller = await _readyController(engine);

      await controller.removeTrack(demoTracks.first);
      expect(controller.library, hasLength(demoTracks.length));
      expect(engine.sources, hasLength(demoTracks.length));
    });

    test('removing an import leaves the file alone', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('songs').path}/Artist - Song.mp3',
      )..writeAsBytesSync(List.filled(8, 0));
      SharedPreferences.setMockInitialValues({
        _libraryKey: jsonEncode([
          {
            'id': 'user-1',
            'title': 'Song',
            'artist': 'Artist',
            'path': file.path,
          },
        ]),
      });

      final engine = FakeEngine();
      final controller = await _readyController(engine);
      expect(controller.importedTracks, hasLength(1));
      expect(controller.currentTrack?.title, 'Song');

      await controller.removeTrack(controller.importedTracks.single);
      expect(controller.importedTracks, isEmpty);
      expect(
        engine.sources,
        hasLength(demoTracks.length),
      ); // demos fill the gap
      expect(File(file.path).existsSync(), isTrue); // the app never deletes it
    });

    test('saved imports survive a restart, deleted ones are dropped', () async {
      final dir = Directory.systemTemp.createTempSync('songs');
      final alive = File('${dir.path}/Keep Me.mp3')
        ..writeAsBytesSync([0, 1, 2]);
      SharedPreferences.setMockInitialValues({
        _libraryKey: jsonEncode([
          {
            'id': 'user-1',
            'title': 'Keep Me',
            'artist': 'Unknown artist',
            'path': alive.path,
          },
          {
            'id': 'user-2',
            'title': 'Gone',
            'artist': 'Unknown artist',
            'path': '${dir.path}/deleted.mp3',
          },
        ]),
      });

      final controller = await _readyController(FakeEngine());

      expect(controller.importedTracks.map((t) => t.title), ['Keep Me']);
      expect(controller.library, hasLength(1));
      expect(controller.library.first.title, 'Keep Me');
    });

    test('a corrupt saved library falls back to the demos', () async {
      SharedPreferences.setMockInitialValues({_libraryKey: '{not json'});
      final controller = await _readyController(FakeEngine());

      expect(controller.importedTracks, isEmpty);
      expect(controller.library, hasLength(demoTracks.length));
    });

    test('track metadata is parsed from the file name', () {
      final track = Track.fromFilePath(
        r'C:\music\Daft Punk - Aerodynamic.mp3',
        id: 'x',
      );
      expect(track.artist, 'Daft Punk');
      expect(track.title, 'Aerodynamic');
      expect(track.isAsset, isFalse);

      final plain = Track.fromFilePath('/music/untitled.wav', id: 'y');
      expect(plain.artist, 'Unknown artist');
      expect(plain.title, 'untitled');
    });
  });

  group('moods and history', () {
    test('a mood tag survives a restart and filters the feed', () async {
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(1, title: 'Museo', artist: 'Eliza'),
          mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
        ],
      );
      final first = await _readyController(FakeEngine(), scanner: scanner);
      expect(first.tracksInMood('Focus'), isEmpty);

      await first.toggleMood(first.library.first, 'Focus');
      expect(first.tracksInMood('Focus').map((t) => t.title), ['Museo']);

      final second = await _readyController(
        FakeEngine(),
        scanner: FakeScanner(
          songs: [
            mediaStoreTrack(1, title: 'Museo', artist: 'Eliza'),
            mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
          ],
        ),
      );
      expect(second.isInMood(second.library.first, 'Focus'), isTrue);

      await second.toggleMood(second.library.first, 'Focus');
      expect(second.tracksInMood('Focus'), isEmpty);
    });

    test('recently played songs move to the front', () async {
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(1, title: 'Museo', artist: 'Eliza'),
          mediaStoreTrack(2, title: 'August', artist: 'Chase Atlantic'),
          mediaStoreTrack(3, title: 'Wolves', artist: 'Selena'),
        ],
      );
      final controller = await _readyController(FakeEngine(), scanner: scanner);

      await controller.playTrackAt(2);
      expect(controller.recentTracks.first.title, 'Wolves');
      expect(controller.recentTracks, hasLength(3));

      await controller.playTrackAt(1);
      expect(controller.recentTracks.take(2).map((t) => t.title), [
        'August',
        'Wolves',
      ]);
    });
  });

  group('lyrics', () {
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'downloads lyrics automatically and keeps them on the phone',
      () async {
        final remote = Lyrics.parse('[00:01.00]Downloaded line')!;
        final scanner = FakeScanner(
          songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
        );
        final lookup = FakeLyricsLookup(lyrics: remote);

        final first = await _readyController(
          FakeEngine(),
          scanner: scanner,
          lyrics: FakeLyrics(lyrics: null),
          lyricsLookup: lookup,
        );
        await settle();

        expect(lookup.calls, 1);
        expect(first.lyrics?.lines.first.text, 'Downloaded line');

        // Next launch: the cached copy is used even with no connection.
        final offline = FakeLyricsLookup();
        final second = await _readyController(
          FakeEngine(),
          scanner: scanner,
          lyrics: FakeLyrics(lyrics: null),
          lyricsLookup: offline,
        );
        await settle();

        expect(second.lyrics?.lines.first.text, 'Downloaded line');
        expect(offline.calls, 0, reason: 'the phone already has these lyrics');
      },
    );

    test('embedded lyrics win over an online match', () async {
      final embedded = Lyrics.parse('[00:01.00]From the file')!;
      final lookup = FakeLyricsLookup(lyrics: Lyrics.parse('Downloaded text')!);
      final scanner = FakeScanner(
        songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
      );

      final controller = await _readyController(
        FakeEngine(),
        scanner: scanner,
        lyrics: FakeLyrics(lyrics: embedded),
        lyricsLookup: lookup,
      );
      await settle();

      expect(controller.lyrics?.lines.first.text, 'From the file');
      expect(lookup.calls, 0);
    });

    test('reloadLyrics retries a failed download', () async {
      final lookup = FakeLyricsLookup(
        lyrics: Lyrics.parse('[00:01.00]Found on retry')!,
        failures: 1,
      );
      final scanner = FakeScanner(
        songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
      );
      final controller = await _readyController(
        FakeEngine(),
        scanner: scanner,
        lyrics: FakeLyrics(lyrics: null),
        lyricsLookup: lookup,
      );
      await settle();

      expect(controller.lyrics, isNull);
      expect(lookup.calls, 1);

      await controller.reloadLyrics();
      await settle();

      expect(controller.lyrics?.lines.first.text, 'Found on retry');
      expect(lookup.calls, 2);
    });

    test('loads automatically per song and caches the result', () async {
      final fake = FakeLyrics(
        lyrics: Lyrics.parse('[00:01.00]Hello\n[00:03.00]World')!,
      );
      final scanner = FakeScanner(
        songs: [
          mediaStoreTrack(1, title: 'First'),
          mediaStoreTrack(2, title: 'Second'),
        ],
      );
      final controller = await _readyController(
        FakeEngine(),
        scanner: scanner,
        lyrics: fake,
      );
      await Future<void>.delayed(Duration.zero);

      expect(fake.loads, 1);
      expect(controller.lyricsLoading, isFalse);
      expect(controller.lyrics?.lines.first.text, 'Hello');

      await controller.playTrackAt(1);
      await Future<void>.delayed(Duration.zero);
      expect(fake.loads, 2);

      // Going back to the first song uses the cache instead of re-reading it.
      await controller.playTrackAt(0);
      await Future<void>.delayed(Duration.zero);
      expect(fake.loads, 2);
    });

    test('tapping a line locks the lyrics to the song', () async {
      final scanner = FakeScanner(
        songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
      );
      final controller = await _readyController(
        FakeEngine(),
        scanner: scanner,
        lyrics: FakeLyrics(
          lyrics: Lyrics.parse('[00:05.00]Line one\n[00:09.00]Line two')!,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // The user hears line one while the player is at 3.25s: the words are
      // 1.75s ahead of the audio, so every line moves 1.75s later.
      await controller.alignLyricsTo(
        const Duration(seconds: 5),
        const Duration(seconds: 3, milliseconds: 250),
      );
      expect(controller.lyricOffsetMs, 1750);

      // The correction is saved for the next launch.
      final second = await _readyController(FakeEngine(), scanner: scanner);
      await second.playTrackAt(0);
      await Future<void>.delayed(Duration.zero);
      expect(second.lyricOffsetMs, 1750);
    });
  });

  group('favourites', () {
    test('a hearted song stays hearted across launches and rescans', () async {
      final scanner = FakeScanner(
        songs: [mediaStoreTrack(1, title: 'Museo', artist: 'Eliza')],
      );
      final first = await _readyController(FakeEngine(), scanner: scanner);
      expect(first.isFavorite(first.library.single), isFalse);

      await first.toggleFavorite(first.library.single);
      expect(first.isFavorite(first.library.single), isTrue);

      // MediaStore renumbering gives the same song a different row id.
      final second = await _readyController(
        FakeEngine(),
        scanner: FakeScanner(
          songs: [mediaStoreTrack(94, title: 'Museo', artist: 'Eliza')],
        ),
      );
      expect(
        second.isFavorite(second.library.single),
        isTrue,
        reason: 'favourites follow title + artist, not the media row id',
      );

      await second.toggleFavorite(second.library.single);
      final third = await _readyController(
        FakeEngine(),
        scanner: FakeScanner(
          songs: [mediaStoreTrack(94, title: 'Museo', artist: 'Eliza')],
        ),
      );
      expect(third.isFavorite(third.library.single), isFalse);
    });
  });
}
