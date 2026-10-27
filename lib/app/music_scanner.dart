import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import 'lyrics_lookup_base.dart';

/// Reads the songs that are already on the phone.
///
/// Kept behind an interface so the controller can be tested with a fake and so
/// the app still builds on platforms without a music library.
abstract class MusicScanner {
  /// Whether this platform can read a music library at all.
  bool get supported;

  /// Whether the app is already allowed to read the library.
  Future<bool> hasPermission();

  /// Asks for permission, returning whether it was granted.
  Future<bool> requestPermission();

  /// Every song on the device, in a stable order.
  Future<List<Track>> scan();
}

/// Android implementation: a small platform channel into MediaStore.
class ChannelMusicScanner implements MusicScanner {
  static const _channel = MethodChannel('music_player/media');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasPermission() async {
    if (!supported) return false;
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  @override
  Future<List<Track>> scan() async {
    if (!supported) return const [];
    final rows =
        await _channel.invokeListMethod<dynamic>('scanSongs') ?? const [];
    return [
      for (final row in rows)
        if (row is Map) _clean(Track.fromMediaStore(row)),
    ];
  }

  /// Downloads arrive with titles like "August (lyrics)_1792127346539" and,
  /// when the file has no artist tag, the artist sits inside the file name.
  /// Clean the display name the same way the lyrics/cover search cleans it, so
  /// the library reads like a music app instead of a file manager.
  Track _clean(Track track) {
    final query = LyricsQuery.from(track);
    final title = query.title.trim();
    final artist = query.artist?.trim();
    return Track(
      id: track.id,
      title: title.isEmpty ? track.title : title,
      artist: artist == null || artist.isEmpty ? track.artist : artist,
      path: track.path,
      source: track.source,
      album: track.album,
      albumId: track.albumId,
      duration: track.duration,
      filePath: track.filePath,
    );
  }
}
