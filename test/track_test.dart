import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/models/track.dart';

Map<String, Object?> _row({String? filePath}) {
  final row = <String, Object?>{
    'id': '7',
    'uri': 'content://media/external/audio/media/7',
    'title': 'Museo',
    'artist': 'Eliza',
    'album': 'Album',
    'albumId': '3',
    'durationMs': 204000,
  };
  if (filePath != null) row['filePath'] = filePath;
  return row;
}

void main() {
  group('MediaStore tracks', () {
    test('play the real file when the phone exposes a readable path', () {
      final track = Track.fromMediaStore(
        _row(filePath: '/storage/emulated/0/Music/Museo.mp3'),
      );

      expect(track.filePath, '/storage/emulated/0/Music/Museo.mp3');
      // The content URI stays available as a fallback.
      expect(track.path, 'content://media/external/audio/media/7');

      final source = track.toAudioSource() as UriAudioSource;
      expect(source.uri.scheme, 'file');
      expect(source.uri.path, '/storage/emulated/0/Music/Museo.mp3');
    });

    test('fall back to the content URI when there is no file path', () {
      final track = Track.fromMediaStore(_row());

      expect(track.filePath, isNull);
      final source = track.toAudioSource() as UriAudioSource;
      expect(source.uri.toString(), 'content://media/external/audio/media/7');
    });

    test('treat a blank file path as missing', () {
      final track = Track.fromMediaStore(_row(filePath: '   '));
      expect(track.filePath, isNull);
    });
  });
}
