import 'package:just_audio/just_audio.dart';

/// Where a track's audio lives.
enum TrackSource {
  /// Bundled sample audio (`assets/demo/...`).
  asset,

  /// A file this app copied into its own storage.
  file,

  /// A song already on the phone, played from its MediaStore `content://` URI.
  mediaStore,
}

/// A single song in the library.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.path,
    this.source = TrackSource.file,
    this.album,
    this.albumId,
    this.duration,
    this.filePath,
    this.demo = false,
  });

  /// Stable identity, also used as the notification item id.
  final String id;
  final String title;
  final String artist;

  /// Asset key, absolute file path, or `content://` URI.
  final String path;
  final TrackSource source;
  final String? album;

  /// MediaStore album row, used to fetch cover art. Null outside the phone's
  /// media library.
  final String? albumId;
  final Duration? duration;

  /// Real file path behind a MediaStore song, when the phone exposes one.
  ///
  /// Playing the file directly is more reliable than a `content://` URI on
  /// some phones (and gives the decoder the file extension); [path] stays the
  /// content URI so it can still be used as a fallback.
  final String? filePath;

  /// A bundled sample track: always present, cannot be deleted.
  final bool demo;

  bool get isAsset => source == TrackSource.asset;

  /// True for songs the app found on the phone rather than ones it was given.
  bool get isOnDevice => source == TrackSource.mediaStore;

  /// Builds a track for a file this app copied into its own storage, splitting
  /// "Artist - Title.mp3" when the file name follows that convention.
  factory Track.fromFilePath(String path, {required String id}) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final base = name.replaceAll(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '');
    var artist = 'Unknown artist';
    var title = base;
    final sep = base.indexOf(' - ');
    if (sep > 0) {
      final left = base.substring(0, sep).trim();
      final right = base.substring(sep + 3).trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        artist = left;
        title = right;
      }
    }
    return Track(id: id, title: title, artist: artist, path: path);
  }

  /// Builds a track from one MediaStore row (as sent by the Android side).
  factory Track.fromMediaStore(Map<dynamic, dynamic> row) {
    final rawArtist = row['artist'] as String?;
    final rawAlbum = row['album'] as String?;
    final milliseconds = (row['durationMs'] as num?)?.toInt() ?? 0;
    final title = (row['title'] as String?)?.trim();
    final rawFilePath = (row['filePath'] as String?)?.trim();
    return Track(
      id: 'ms-${row['id']}',
      title: (title == null || title.isEmpty) ? 'Unknown title' : title,
      artist:
          (rawArtist == null || rawArtist.isEmpty || rawArtist == '<unknown>')
          ? 'Unknown artist'
          : rawArtist,
      path: row['uri'] as String,
      source: TrackSource.mediaStore,
      album: (rawAlbum == null || rawAlbum.isEmpty || rawAlbum == '<unknown>')
          ? null
          : rawAlbum,
      albumId: row['albumId']?.toString(),
      duration: milliseconds > 0 ? Duration(milliseconds: milliseconds) : null,
      filePath: (rawFilePath == null || rawFilePath.isEmpty)
          ? null
          : rawFilePath,
    );
  }

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String? ?? 'Unknown artist',
    path: json['path'] as String,
    filePath: json['filePath'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'path': path,
    if (filePath != null) 'filePath': filePath,
  };

  /// [tag] carries the notification metadata on platforms that support
  /// background playback (see `app/media_tags.dart`).
  AudioSource toAudioSource({Object? tag}) => switch (source) {
    TrackSource.asset => AudioSource.asset(path, tag: tag),
    TrackSource.file => AudioSource.uri(Uri.file(path), tag: tag),
    TrackSource.mediaStore => AudioSource.uri(
      filePath == null ? Uri.parse(path) : Uri.file(filePath!),
      tag: tag,
    ),
  };
}

/// Ships with the app so there is something to play on a phone with no music.
const demoTracks = <Track>[
  Track(
    id: 'demo-warm-up',
    title: 'Warm Up',
    artist: 'Built-in demo',
    path: 'assets/demo/warm_up.wav',
    source: TrackSource.asset,
    demo: true,
  ),
  Track(
    id: 'demo-pulse',
    title: 'Pulse',
    artist: 'Built-in demo',
    path: 'assets/demo/pulse.wav',
    source: TrackSource.asset,
    demo: true,
  ),
  Track(
    id: 'demo-drift',
    title: 'Drift',
    artist: 'Built-in demo',
    path: 'assets/demo/drift.wav',
    source: TrackSource.asset,
    demo: true,
  ),
];
