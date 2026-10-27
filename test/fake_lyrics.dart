import 'package:music_player/app/lyrics_lookup.dart';
import 'package:music_player/app/lyrics_service.dart';
import 'package:music_player/models/lyrics.dart';
import 'package:music_player/models/track.dart';

/// Stands in for the Android tag reader.
class FakeLyrics implements LyricsService {
  FakeLyrics({this.supported = true, this.lyrics});

  @override
  bool supported;

  Lyrics? lyrics;
  int loads = 0;

  @override
  Future<Lyrics?> load(Track track) async {
    loads++;
    return lyrics;
  }
}

/// Stands in for LRCLIB. The default returns nothing, which keeps every other
/// test deterministic and offline.
class FakeLyricsLookup implements LyricsLookup {
  FakeLyricsLookup({this.lyrics, this.failures = 0});

  Lyrics? lyrics;
  int failures;

  int calls = 0;
  final List<Track> queried = [];

  @override
  Future<Lyrics?> find(Track track) async {
    calls++;
    queried.add(track);
    if (calls <= failures) return null;
    return lyrics;
  }

  /// Tests stay offline; no background prefetch should start.
  @override
  bool get reachable => false;

  @override
  void close() {}
}
