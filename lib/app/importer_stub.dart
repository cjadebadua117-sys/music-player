import '../models/track.dart';

/// The browser build cannot copy songs into app storage.
bool get importSupported => false;

bool trackFileExists(String path) => true;

Future<List<Track>> pickAndCopyTracks() async => const [];
