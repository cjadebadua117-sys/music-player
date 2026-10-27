import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/app/album_art.dart';
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

  test('asks Android for the album thumbnail, then the track itself', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return Uint8List.fromList([1, 2, 3]);
    });

    final bytes = await AlbumArtStore.instance.load(
      mediaStoreTrack(7, albumId: '42'),
    );

    expect(bytes, [1, 2, 3]);
    expect(calls.single.method, 'albumArt');
    expect(calls.single.arguments, {'albumId': '42', 'trackId': '7'});
  });

  test('caches per song, not per album', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return Uint8List.fromList([9]);
    });

    final first = await AlbumArtStore.instance.load(
      mediaStoreTrack(11, albumId: '77'),
    );
    final repeated = await AlbumArtStore.instance.load(
      mediaStoreTrack(11, albumId: '77'),
    );
    final neighbour = await AlbumArtStore.instance.load(
      mediaStoreTrack(12, albumId: '77'),
    );

    expect(first, isNotNull);
    expect(repeated, same(first));
    // Untagged downloads all share one MediaStore album; sharing a cache entry
    // made every song show the first song's (usually missing) picture.
    expect(neighbour, isNotNull);
    expect(calls, hasLength(2));
  });

  test('bundled demos never touch the channel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    expect(await AlbumArtStore.instance.load(demoTracks.first), isNull);
    expect(calls, isEmpty);
  });

  test('an imported file asks for the artwork inside it', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return Uint8List.fromList([4, 5, 6]);
    });

    final track = Track(
      id: 'user-you',
      title: 'YOU',
      artist: 'Chase Atlantic',
      path: '/data/user/0/app/songs/YOU.mp3',
    );
    final bytes = await AlbumArtStore.instance.load(track);

    expect(bytes, [4, 5, 6]);
    expect(calls.single.method, 'fileArtwork');
    expect(calls.single.arguments, {'path': track.path});
  });

  test(
    'a platform failure degrades to no artwork instead of throwing',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom', message: 'no cover');
      });

      expect(
        await AlbumArtStore.instance.load(mediaStoreTrack(21, albumId: '5')),
        isNull,
      );
    },
  );
}
