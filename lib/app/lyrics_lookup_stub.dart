import 'lyrics_lookup_base.dart';

/// The web build has no lyrics downloader; it keeps embedded/cached lyrics.
LyricsLookup createLyricsLookup() => const NoLyricsLookup();
