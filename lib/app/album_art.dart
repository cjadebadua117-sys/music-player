import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import 'cover_lookup.dart';

/// Loads album artwork for every song the app can see.
///
/// For songs from the phone's media library, Android first tries the album
/// thumbnail in MediaStore (fast), then the picture embedded in the audio file
/// itself. Files added with the file picker read the picture embedded in the
/// file, or a frame of the video when the download is a music video. Results
/// are cached so scrolling never re-fetches the same cover. Bundled demos keep
/// the gradient tile.
class AlbumArtStore {
  AlbumArtStore._();

  static final AlbumArtStore instance = AlbumArtStore._();

  static const _channel = MethodChannel('music_player/media');
  final Map<String, Future<Uint8List?>> _cache = {};

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Uint8List?> load(Track? track) {
    if (track == null || !supported || track.demo) return Future.value(null);

    if (track.isOnDevice) {
      final mediaId = track.id.startsWith('ms-') ? track.id.substring(3) : null;
      if (track.albumId == null && mediaId == null) return Future.value(null);
      // All untagged downloads share one MediaStore album row, so the cache has
      // to be per song; keying by album alone gave every song the first song's
      // (usually absent) picture.
      final key = 'ms:${track.id}:${track.albumId}';
      return _cache.putIfAbsent(key, () async {
        final embedded = await _fetch(albumId: track.albumId, mediaId: mediaId);
        if (embedded != null && embedded.isNotEmpty) return embedded;
        return lookupCoverArt(track);
      });
    }

    // A file added from Downloads: read the picture the downloader embedded
    // in the file (or the first video frame, for music videos). When the file
    // carries none, look the artwork up once and cache it.
    if (track.path.isEmpty) return Future.value(null);
    return _cache.putIfAbsent('file:${track.path}', () async {
      final embedded = await _fetchFile(track.path);
      if (embedded != null && embedded.isNotEmpty) return embedded;
      return lookupCoverArt(track);
    });
  }

  Future<Uint8List?> _fetch({
    required String? albumId,
    required String? mediaId,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>('albumArt', {
        'albumId': albumId,
        'trackId': mediaId,
      });
    } on PlatformException catch (error) {
      debugPrint('No album art: ${error.message}');
      return null;
    } on MissingPluginException {
      return null; // tests and other platforms: use the gradient tile
    }
  }

  Future<Uint8List?> _fetchFile(String path) async {
    try {
      return await _channel.invokeMethod<Uint8List>('fileArtwork', {
        'path': path,
      });
    } on PlatformException catch (error) {
      debugPrint('No embedded artwork: ${error.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
