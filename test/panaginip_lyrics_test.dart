import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/local_lyrics.dart';

void main() {
  test('bundled local lyrics cover Panaginip — Nicole', () {
    final lyrics = LocalLyrics.panaginipNicole();
    expect(lyrics, isNotNull);

    final text = lyrics.text ?? lyrics.lines.map((l) => l.text).join('\n');
    expect(text, isNotEmpty);
    expect(text, contains('Bawat pikit ng aking mata'));
    expect(text, contains('Parang panaginip'));
    expect(text, contains('Paulit-ulit kang tumatakbo sa isip'));

    // The bundled LRC is synced, so playback should light up the right line.
    if (lyrics.isTimed) {
      expect(lyrics.lines.first.time.inMilliseconds, isPositive);
      expect(
        lyrics.lines.any((line) =>
            line.text.contains('nahuhumaling sa') &&
            line.time.inMilliseconds > 60000),
        isTrue,
      );
    } else {
      // Plain-text fallback: the words are still here.
      expect(text.toLowerCase().contains('nahuhumaling'), isTrue);
    }
  });

  test('the bundled song is complete enough to play through the ending', () {
    final lyrics = LocalLyrics.panaginipNicole();
    final text = lyrics.text ?? lyrics.lines.map((l) => l.text).join('\n');
    expect(text.length, greaterThan(350));
    // It must be syncable, or the player would print the timestamps.
    expect(lyrics.isTimed, isTrue);
  });
}
