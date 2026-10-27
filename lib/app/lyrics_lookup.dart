/// Online lyrics lookup with an on-device fallback. The lyrics client is only
/// wired in where `dart:io` exists; the web build stays offline.
library;

import 'lyrics_lookup_base.dart';
import 'lyrics_lookup_stub.dart'
    if (dart.library.io) 'lyrics_lookup_io.dart'
    as platform;

export 'lyrics_lookup_base.dart';

LyricsLookup createLyricsLookup() => platform.createLyricsLookup();
