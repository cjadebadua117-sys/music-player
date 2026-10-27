import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/lyrics_service.dart';
import 'package:music_player/models/track.dart';

import 'fake_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('music_player/media');
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => calls.clear());

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('a downloaded file reads the LRC tags inside the file', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '[00:12.50]First line\n[00:16.00]Second line';
    });

    final track = Track(
      id: 'user-you',
      title: 'YOU',
      artist: 'Chase Atlantic',
      path: '/data/user/0/app/songs/YOU.mp3',
    );
    final lyrics = await ChannelLyricsService().load(track);

    expect(calls.single.method, 'fileLyrics');
    expect(calls.single.arguments, {'path': track.path});
    expect(lyrics?.isTimed, isTrue);
    expect(lyrics?.lines.first.time, const Duration(milliseconds: 12500));
    expect(lyrics?.lines.last.text, 'Second line');
  });

  test('a song from the phone library still uses its MediaStore row', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await ChannelLyricsService().load(
      mediaStoreTrack(42, title: 'August', artist: 'Chase Atlantic'),
    );

    expect(calls.single.method, 'lyrics');
    expect(calls.single.arguments, {'trackId': '42'});
  });

  test('bundled demos never ask the phone for lyrics', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    expect(await ChannelLyricsService().load(demoTracks.first), isNull);
    expect(calls, isEmpty);
  });
}
