import 'package:music_player/app/music_scanner.dart';
import 'package:music_player/models/track.dart';

/// Stands in for the Android MediaStore channel in tests.
class FakeScanner implements MusicScanner {
  FakeScanner({
    this.supported = true,
    this.permission = true,
    List<Track>? songs,
  }) : songs = songs ?? [];

  /// Whether this "phone" has a readable music library.
  @override
  bool supported;

  /// Whether permission is already granted / will be granted when asked.
  bool permission;

  /// What a scan finds.
  List<Track> songs;

  int permissionRequests = 0;
  int scans = 0;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<List<Track>> scan() async {
    scans++;
    return songs;
  }
}

/// Builds a track the way the Android side reports one.
Track mediaStoreTrack(
  int id, {
  String title = 'Song',
  String artist = 'Artist',
  String? album,
  String? albumId,
  Duration? duration,
}) => Track(
  id: 'ms-$id',
  title: title,
  artist: artist,
  path: 'content://media/external/audio/media/$id',
  source: TrackSource.mediaStore,
  album: album,
  albumId: albumId,
  duration: duration,
);
