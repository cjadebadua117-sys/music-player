import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

/// Importing songs from the device is available on Android/iOS/desktop.
bool get importSupported => true;

/// Whether a saved track's file is still on disk.
bool trackFileExists(String path) => File(path).existsSync();

/// Opens the system file picker for audio, copies whatever was chosen into the
/// app's documents folder (so it survives cache cleanup and permission loss)
/// and returns the resulting tracks.
Future<List<Track>> pickAndCopyTracks() async {
  // Audio *and* video: downloads from YouTube-style sites are often music
  // videos (.mp4/.webm). Playback only needs the audio track, and the video's
  // first frame gives the song its cover art.
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const [
      'mp3',
      'm4a',
      'aac',
      'flac',
      'wav',
      'ogg',
      'opus',
      'mp4',
      'm4v',
      'mov',
      'mkv',
      'webm',
      '3gp',
    ],
  );
  if (files.isEmpty) return const [];

  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'songs'));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final picked = <Track>[];
  for (final file in files) {
    final source = file.path;
    if (source == null) continue;
    var target = File(p.join(dir.path, p.basename(source)));
    var counter = 1;
    while (target.existsSync() && !p.equals(target.path, source)) {
      final stem = p.basenameWithoutExtension(source);
      target = File(p.join(dir.path, '${stem}_$counter${p.extension(source)}'));
      counter++;
    }
    try {
      if (!p.equals(target.path, source)) {
        await File(source).copy(target.path);
      }
      await _copySidecarCover(source, target.path);
    } on FileSystemException {
      continue; // unreadable file - skip it rather than failing the import
    }
    picked.add(
      Track.fromFilePath(
        target.path,
        id: 'user-${DateTime.now().microsecondsSinceEpoch}-${picked.length}',
      ),
    );
  }
  return picked;
}

/// Downloaders frequently save the thumbnail beside the song (`YOU.webp`) or
/// under a `-cover` / `_cover` name. Keep it next to the copied audio so the
/// artwork still loads on the next launch.
Future<void> _copySidecarCover(String source, String target) async {
  final sourceFile = File(source);
  final folder = sourceFile.parent;
  final base = p.basenameWithoutExtension(source);
  const extensions = ['jpg', 'jpeg', 'png', 'webp'];
  for (final extension in extensions) {
    for (final name in [
      '$base.$extension',
      '$base-cover.$extension',
      '${base}_cover.$extension',
      '$base cover.$extension',
    ]) {
      final candidate = File(p.join(folder.path, name));
      if (!candidate.existsSync()) continue;
      final art = File(
        p.join(
          p.dirname(target),
          '${p.basenameWithoutExtension(target)}.$extension',
        ),
      );
      if (!art.existsSync()) await candidate.copy(art.path);
      return;
    }
  }
}
