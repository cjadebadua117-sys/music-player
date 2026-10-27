import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/lyrics.dart';
import '../models/track.dart';

/// Fetches lyrics for a track. Offline by design: the Android side only reads
/// tags that are already inside the audio file.
abstract class LyricsService {
  bool get supported;

  Future<Lyrics?> load(Track track);
}

class ChannelLyricsService implements LyricsService {
  static const _channel = MethodChannel('music_player/media');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<Lyrics?> load(Track track) async {
    if (!supported || track.demo) return null;

    final String method;
    final Map<String, Object?> arguments;
    if (track.isOnDevice) {
      final mediaId = track.id.startsWith('ms-') ? track.id.substring(3) : null;
      if (mediaId == null) return null;
      method = 'lyrics';
      arguments = {'trackId': mediaId};
    } else if (track.path.isNotEmpty) {
      // A file added from Downloads can carry its own LRC tags. Reading those
      // is exact, unlike an online match for a different edit of the song.
      method = 'fileLyrics';
      arguments = {'path': track.path};
    } else {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<String>(method, arguments);
      if (raw == null || raw.trim().isEmpty) return null;
      return Lyrics.parse(raw);
    } on PlatformException catch (error) {
      debugPrint('No lyrics: ${error.message}');
      return null;
    } on MissingPluginException {
      return null; // tests and other platforms
    }
  }
}
