import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'lyrics_lookup_base.dart';

/// Finds and caches cover art for songs that carry no embedded picture.
///
/// Lookup order: Deezer album search (fast, good catalog), then the iTunes
/// catalogue, then the thumbnail of the matching YouTube video. That last step
/// matters for downloads: a YouTube rip such as "Chase Atlantic - YOU
/// (Official Lyric Video)" has no tags and no cover, but its video still is
/// exactly the image the user saw when they downloaded the song.
///
/// Every hit is written to the app's support directory, so covers keep working
/// after the phone goes offline and are never downloaded twice.
Future<Uint8List?> lookupCoverArt(Track track) =>
    _CoverFinder.instance.find(track);

class _CoverFinder {
  _CoverFinder._();

  static final _CoverFinder instance = _CoverFinder._();

  // YouTube serves an empty consent page to a mobile UA; a desktop UA gets the
  // normal results page with `ytInitialData`.
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const _timeout = Duration(seconds: 7);
  static const _readTimeout = Duration(seconds: 9);
  static const _maxImageBytes = 6 * 1024 * 1024;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..userAgent = _userAgent;

  final Map<String, Future<Uint8List?>> _pending = {};
  Directory? _cacheDir;

  /// A failed connection puts the network on hold, so an offline phone does not
  /// wait on 30 separate timeouts while the user scrolls the library.
  DateTime? _backOffUntil;

  int _active = 0;
  final List<Completer<void>> _waiting = [];

  Future<Uint8List?> find(Track track) {
    if (track.demo || track.path.isEmpty) return Future.value(null);
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future.value(null); // tests must never touch the network
    }

    final query = LyricsQuery.from(track);
    final title = query.title.trim();
    if (title.isEmpty || title.toLowerCase() == 'unknown title') {
      return Future.value(null);
    }

    final key = _cacheKey(track);
    final inFlight = _pending[key];
    if (inFlight != null) return inFlight;

    final future = _find(track, query, key);
    _pending[key] = future;
    return future.whenComplete(() => _pending.remove(key));
  }

  Future<Uint8List?> _find(Track track, LyricsQuery query, String key) async {
    final cached = await _readCache(key);
    if (cached != null) return cached;

    final now = DateTime.now();
    final backOff = _backOffUntil;
    if (backOff != null && now.isBefore(backOff)) return null;

    return _withSlot(() async {
      final bytes = await _download(query);
      if (bytes == null) return null;
      await _writeCache(key, bytes);
      return bytes;
    });
  }

  Future<T> _withSlot<T>(Future<T> Function() work) async {
    if (_active >= 2) {
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      return await work();
    } finally {
      _active--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }

  Future<Uint8List?> _download(LyricsQuery query) async {
    final candidates = <_Candidate>[];
    candidates.addAll(await _deezer(query));
    candidates.addAll(await _itunes(query));

    final scored = <_Scored>[];
    for (final candidate in candidates) {
      final score = _score(query, candidate);
      if (score >= 60) scored.add(_Scored(candidate, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    for (final hit in scored) {
      final bytes = await _image(hit.candidate.image);
      if (bytes != null) return bytes;
    }

    // Last resort: the thumbnail of the matching YouTube video. This is what
    // makes the cover look like the video the song was downloaded from.
    final youtube = await _youtube(query);
    for (final candidate in youtube) {
      final score = _score(query, candidate);
      if (score < 60) continue;
      final bytes = await _image(candidate.image);
      if (bytes == null) continue;
      return bytes;
    }
    return null;
  }

  Future<List<_Candidate>> _deezer(LyricsQuery query) async {
    final term = [query.artist, query.title].whereType<String>().join(' ');
    final uri = Uri.https('api.deezer.com', '/search', {
      'q': term,
      'limit': '10',
    });
    final body = await _text(uri);
    if (body == null) return const [];
    try {
      final data = jsonDecode(body);
      if (data is! Map) return const [];
      final rows = data['data'];
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map)
            _Candidate(
              title: '${row['title'] ?? ''}',
              artist: '${(row['artist'] as Map?)?['name'] ?? ''}',
              image: '${(row['album'] as Map?)?['cover_big'] ?? ''}',
              durationMs: switch (row['duration']) {
                final num seconds => (seconds * 1000).round(),
                _ => null,
              },
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<List<_Candidate>> _itunes(LyricsQuery query) async {
    final term = [query.artist, query.title].whereType<String>().join(' ');
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'entity': 'song',
      'limit': '10',
    });
    final body = await _text(uri);
    if (body == null) return const [];
    try {
      final data = jsonDecode(body);
      if (data is! Map) return const [];
      final rows = data['results'];
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          if (row is Map)
            _Candidate(
              title: '${row['trackName'] ?? ''}',
              artist: '${row['artistName'] ?? ''}',
              // iTunes serves 100x100 by default; ask the same CDN for 600.
              image: '${row['artworkUrl100'] ?? ''}'.replaceAllMapped(
                RegExp(r'\d+x\d+bb\.(jpg|png)$'),
                (match) => '600x600bb.${match.group(1)}',
              ),
              durationMs: switch (row['trackTimeMillis']) {
                final num ms => ms.round(),
                _ => null,
              },
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<List<_Candidate>> _youtube(LyricsQuery query) async {
    final term = [
      query.artist,
      query.title,
      'official',
    ].whereType<String>().join(' ');
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': term,
    });
    final html = await _text(uri, maxBytes: 3 * 1024 * 1024);
    if (html == null) return const [];

    // A search page is ~500 KB; decoding and walking that JSON on the UI
    // isolate would drop a frame right as the user scrolls past the song.
    final videos = await Isolate.run(() => _parseYoutubeVideos(html));
    return [
      for (final video in videos)
        if (video.length == 2)
          _Candidate(
            title: video[0],
            artist: query.artist ?? '',
            image: 'https://i.ytimg.com/vi/${video[1]}/maxresdefault.jpg',
          ),
    ];
  }

  int _score(LyricsQuery query, _Candidate candidate) {
    final wanted = _normalize(query.title);
    final found = _normalize(candidate.title);
    if (wanted.isEmpty || found.isEmpty) return -1;

    var score = 0;
    if (found == wanted) {
      score += 100;
    } else if (found.startsWith(wanted) || found.contains(wanted)) {
      score += 60;
    } else if (wanted.contains(found)) {
      score += 40;
    } else {
      return -1;
    }

    final artist = query.artist == null ? '' : _normalize(query.artist!);
    if (artist.isNotEmpty) {
      final foundArtist = _normalize(candidate.artist);
      if (foundArtist == artist) {
        score += 80;
      } else if (foundArtist.contains(artist) || artist.contains(foundArtist)) {
        score += 50;
      } else {
        return -1; // a different artist's song would be the wrong picture
      }
    }

    // Album titles often carry decoration; penalise live/cover/sped-up edits
    // when the user's file does not.
    final lower = candidate.title.toLowerCase();
    if (!query.title.toLowerCase().contains('live') &&
        RegExp(r'\blive\b').hasMatch(lower)) {
      score -= 25;
    }
    if (!query.title.toLowerCase().contains('cover') &&
        RegExp(r'\bcover\b').hasMatch(lower)) {
      score -= 20;
    }

    final duration = query.duration;
    if (duration != null && candidate.durationMs != null) {
      final diff = (duration.inMilliseconds - candidate.durationMs!).abs();
      if (diff <= 3000) {
        score += 25;
      } else if (diff <= 10000) {
        score += 10;
      }
    }
    return score;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(
        RegExp(r'\b(official|lyrics?|video|audio|visualizer|mv)\b'),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<Uint8List?> _image(String url) async {
    if (url.isEmpty) return null;
    var bytes = await _bytes(Uri.tryParse(url), maxBytes: _maxImageBytes);
    if (bytes == null && url.contains('maxresdefault')) {
      bytes = await _bytes(
        Uri.parse(url.replaceFirst('maxresdefault', 'hqdefault')),
        maxBytes: _maxImageBytes,
      );
    }
    return bytes;
  }

  Future<String?> _text(Uri uri, {int maxBytes = 1024 * 1024}) async {
    final bytes = await _bytes(uri, maxBytes: maxBytes);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<Uint8List?> _bytes(Uri? uri, {required int maxBytes}) async {
    if (uri == null) return null;
    try {
      final request = await _client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_readTimeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          await response.drain<void>();
          return null;
        }
      }
      if (builder.length < 100) return null;
      return builder.takeBytes();
    } on Exception {
      _backOffUntil = DateTime.now().add(const Duration(minutes: 2));
      return null;
    }
  }

  String _cacheKey(Track track) =>
      track.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Directory?> _coversDirectory() async {
    final cached = _cacheDir;
    if (cached != null) return cached;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'covers'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return _cacheDir = dir;
    } on Exception {
      return null;
    }
  }

  Future<Uint8List?> _readCache(String key) async {
    try {
      final dir = await _coversDirectory();
      if (dir == null) return null;
      final file = File(p.join(dir.path, '$key.jpg'));
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.length < 100 ? null : bytes;
    } on Exception {
      return null;
    }
  }

  Future<void> _writeCache(String key, Uint8List bytes) async {
    try {
      final dir = await _coversDirectory();
      if (dir == null) return;
      await File(p.join(dir.path, '$key.jpg')).writeAsBytes(bytes, flush: true);
    } on Exception {
      // A read-only cache only costs a re-download next launch.
    }
  }
}

/// Runs in a background isolate: extracts the first video renderers and their
/// titles from a YouTube results page.
List<List<String>> _parseYoutubeVideos(String html) {
  final match = RegExp(
    r'var ytInitialData = (\{.*?\});</script>',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) return const [];

  Object? data;
  try {
    data = jsonDecode(match.group(1)!);
  } on FormatException {
    return const [];
  }

  final videos = <Map>[];
  _collectVideos(data, videos);
  return [
    for (final video in videos.take(8))
      if (video['videoId'] is String)
        [_videoTitle(video) ?? '', video['videoId'] as String],
  ];
}

void _collectVideos(Object? node, List<Map> out) {
  if (out.length > 40) return;
  if (node is List) {
    for (final item in node) {
      _collectVideos(item, out);
    }
    return;
  }
  if (node is! Map) return;
  final renderer = node['videoRenderer'];
  if (renderer is Map) {
    out.add(renderer);
    return;
  }
  for (final value in node.values) {
    _collectVideos(value, out);
  }
}

String? _videoTitle(Map renderer) {
  final title = renderer['title'];
  if (title is Map) {
    final runs = title['runs'];
    if (runs is List && runs.isNotEmpty) {
      final first = runs.first;
      if (first is Map && first['text'] is String) return first['text'];
    }
    if (title['simpleText'] is String) return title['simpleText'];
  }
  return null;
}

class _Candidate {
  const _Candidate({
    required this.title,
    required this.artist,
    required this.image,
    this.durationMs,
  });

  final String title;
  final String artist;
  final String image;
  final int? durationMs;
}

class _Scored {
  const _Scored(this.candidate, this.score);

  final _Candidate candidate;
  final int score;
}
