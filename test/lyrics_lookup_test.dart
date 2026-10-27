import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/lyrics_lookup.dart';
import 'package:music_player/app/lyrics_lookup_io.dart' show parseGeniusLyrics;
import 'package:music_player/models/lyrics.dart';
import 'package:music_player/models/track.dart';

Track song(
  String title, {
  String artist = 'Chase Atlantic',
  Duration? duration,
}) => Track(
  id: 'ms-1',
  title: title,
  artist: artist,
  path: 'content://media/external/audio/media/1',
  duration: duration,
);

Map<String, Object?> record({
  required String title,
  String artist = 'Chase Atlantic',
  double duration = 220,
  String? synced,
  String? plain,
  bool instrumental = false,
}) => {
  'trackName': title,
  'artistName': artist,
  'duration': duration,
  'instrumental': instrumental,
  'syncedLyrics': synced,
  'plainLyrics': plain,
};

void main() {
  group('LyricsQuery', () {
    test('cleans download suffixes and banner brackets', () {
      final query = LyricsQuery.from(
        song('Chase Atlantic - Church (Official Video) Lyrics_1792127370967'),
      );

      expect(query.artist, 'Chase Atlantic');
      expect(query.title, 'Church');
    });

    test('keeps a real artist and strips a trailing Lyrics', () {
      final query = LyricsQuery.from(song('August (lyrics)'));

      expect(query.artist, 'Chase Atlantic');
      expect(query.title, 'August');
    });

    test('an unknown artist does not become a search term', () {
      final query = LyricsQuery.from(song('Museo', artist: 'Unknown artist'));

      expect(query.artist, isNull);
      expect(query.title, 'Museo');
    });

    test('splits a tight artist-title dash when the artist is unknown', () {
      final query = LyricsQuery.from(
        song(
          'CHASE ATLANTIC-ROXANNE (LYRICS)_1792127392231',
          artist: 'Unknown artist',
        ),
      );

      expect(query.artist, 'CHASE ATLANTIC');
      expect(query.title, 'ROXANNE');
    });

    test('simplified drops featured artists and decorations', () {
      final query = LyricsQuery.from(
        song('Into It (feat. Someone) - Remastered 2011'),
      ).simplified;

      expect(query.title, 'Into It');
    });

    test('brackets that are part of the title are kept', () {
      final query = LyricsQuery.from(song('About You (Live at Wembley)'));

      expect(query.title, 'About You (Live at Wembley)');
    });
  });

  group('parseGeniusLyrics', () {
    test('keeps sung lines and drops section labels and ads', () {
      const page = '''
        <div data-lyrics-container="true">
          Line one<br>Line two<br>
          <div data-exclude-from-selection="true">You might also like</div>
          [Chorus]<br>Line three
        </div>
      ''';

      final text = parseGeniusLyrics(page)!;
      expect(text, isNot(contains('You might also like')));
      expect(text, isNot(contains('[Chorus]')));
      expect(text, contains('Line one\nLine two'));
      expect(text, contains('Line three'));
    });

    test('a page without a lyric container has no lyrics', () {
      expect(parseGeniusLyrics('<html><body>Nope</body></html>'), isNull);
    });
  });

  group('parseLrclib', () {
    final query = LyricsQuery.from(
      song('Church', duration: const Duration(minutes: 3, seconds: 41)),
    );

    test('picks the candidate whose duration matches', () {
      final body = jsonEncode([
        record(
          title: 'Church',
          duration: 267,
          synced: '[00:01.00]Wrong version',
        ),
        record(
          title: 'Church',
          duration: 221,
          synced: '[00:01.00]Right version\n[00:04.00]Second line',
        ),
      ]);

      final lyrics = parseLrclib(body, query);

      expect(lyrics, isNotNull);
      expect(lyrics!.isTimed, isTrue);
      expect(lyrics.lines.first.text, 'Right version');
    });

    test('falls back to plain lyrics when there is no timestamp', () {
      final body = jsonEncode([
        record(title: 'Church', duration: 221, plain: 'Line one\nLine two'),
      ]);

      final lyrics = parseLrclib(body, query);

      expect(lyrics!.isTimed, isFalse);
      expect(lyrics.text, 'Line one\nLine two');
    });

    test('instrumental records and empty results are no lyrics', () {
      expect(
        parseLrclib(
          jsonEncode([record(title: 'Church', instrumental: true)]),
          query,
        ),
        isNull,
      );
      expect(parseLrclib('[]', query), isNull);
      expect(parseLrclib('not json', query), isNull);
    });

    test('a completely different song is rejected', () {
      final body = jsonEncode([
        record(
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          duration: 200,
          synced: '[00:01.00]Nope',
        ),
      ]);

      expect(parseLrclib(body, query), isNull);
    });
  });

  group('Lyrics.toLrc', () {
    test('timed lyrics survive a cache round trip', () {
      final original = Lyrics.parse('[00:01.50]First\n[00:05.20]Second')!;
      final restored = Lyrics.parse(original.toLrc())!;

      expect(restored.isTimed, isTrue);
      expect(restored.lines, hasLength(2));
      expect(
        restored.lines.first.time,
        const Duration(seconds: 1, milliseconds: 500),
      );
      expect(restored.lines.last.text, 'Second');
    });

    test('plain lyrics stay plain', () {
      final restored = Lyrics.parse(Lyrics.literal('Just words').toLrc())!;
      expect(restored.isTimed, isFalse);
      expect(restored.text, 'Just words');
    });
  });
}
