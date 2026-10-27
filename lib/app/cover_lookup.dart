/// Downloads a song's cover art when the audio file itself carries none.
///
/// Downloaded songs (especially YouTube rips) often have no embedded picture,
/// so the app looks the artwork up online once and keeps it on the phone. The
/// web build has no file system to cache into, so it stays on the gradient
/// tile.
library;

import 'dart:typed_data';

import '../models/track.dart';
import 'cover_lookup_stub.dart'
    if (dart.library.io) 'cover_lookup_io.dart'
    as platform;

/// Returns JPEG/PNG bytes for [track]'s cover, or null when none was found or
/// the phone is offline.
Future<Uint8List?> lookupCoverArt(Track track) => platform.lookupCoverArt(track);
