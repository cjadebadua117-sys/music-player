import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/lyrics.dart';

void main() {
  test('parses timestamped LRC into timed lines', () {
    final lyrics = Lyrics.parse('''
[ar:Someone]
[ti:A song]
[00:01.50]First line
[00:05.20]Second line
[00:09.05]Third line
''');

    expect(lyrics, isNotNull);
    expect(lyrics!.isTimed, isTrue);
    expect(lyrics.lines, hasLength(3));
    expect(
      lyrics.lines.first.time,
      const Duration(seconds: 1, milliseconds: 500),
    );
    expect(lyrics.lines[1].text, 'Second line');
    expect(lyrics.indexAt(Duration.zero), -1);
    expect(lyrics.indexAt(const Duration(seconds: 2)), 0);
    expect(lyrics.indexAt(const Duration(seconds: 6)), 1);
    expect(lyrics.indexAt(const Duration(minutes: 2)), 2);
  });

  test('expands repeated timestamps on one line', () {
    final lyrics = Lyrics.parse('[00:01.00][00:10.00]Chorus');
    expect(lyrics!.lines, hasLength(2));
    expect(lyrics.lines.map((l) => l.text), ['Chorus', 'Chorus']);
  });

  test('applies the LRC offset tag', () {
    final lyrics = Lyrics.parse('[offset:500]\n[00:01.00]Late line');
    expect(lyrics!.lines.single.time, const Duration(milliseconds: 1500));
  });

  test('untimed text is kept as plain lyrics', () {
    final lyrics = Lyrics.parse('Just a line\nand another');
    expect(lyrics!.isTimed, isFalse);
    expect(lyrics.text, 'Just a line\nand another');
    expect(lyrics.indexAt(const Duration(seconds: 3)), -1);
  });

  test('empty tag content means no lyrics', () {
    expect(Lyrics.parse('   '), isNull);
    expect(Lyrics.parse('[ar:Only metadata]'), isNull);
  });
}
