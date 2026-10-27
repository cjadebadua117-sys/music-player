import 'dart:convert';

import '../models/lyrics.dart';
import '../models/track.dart';

/// Looks lyrics up online. Implementations must never throw: a failed lookup is
/// simply "no lyrics" so a song can always fall back to its embedded tags or
/// the on-device cache.
abstract class LyricsLookup {
  Future<Lyrics?> find(Track track);

  /// False after repeated network failures, so a background prefetch does not
  /// sit through a timeout for every song on an offline phone.
  bool get reachable => true;

  void close() {}
}

/// Used on platforms without a network implementation (the web build).
class NoLyricsLookup implements LyricsLookup {
  const NoLyricsLookup();

  @override
  Future<Lyrics?> find(Track track) async => null;

  @override
  bool get reachable => false;

  @override
  void close() {}
}

/// The search terms derived from a track, cleaned of the noise that YouTube
/// downloads carry ("Artist - Song (Official Video)_1792127345410").
class LyricsQuery {
  const LyricsQuery({
    required this.title,
    this.artist,
    this.album,
    this.duration,
  });

  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;

  /// The same search with a tidier title: featured artists, "(Remaster)" and
  /// other decoration removed. Used as the second, broader attempt.
  LyricsQuery get simplified => LyricsQuery(
    title: cleanText(
      title
          .replaceAll(
            RegExp(
              r'[\(\[]\s*(feat\.?|ft\.?|featuring)\b[^\)\]]*[\)\]]',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(r'\s+(feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(
              r'\s*[\-–—]\s*(remaster(ed)?|live|acoustic).*$',
              caseSensitive: false,
            ),
            '',
          ),
    ),
    artist: artist,
    album: null,
    duration: duration,
  );

  factory LyricsQuery.from(Track track) {
    // Clean first, then split: downloaded names look like
    // "Chase Atlantic - Church (Official Video) Lyrics_1792127370967" and the
    // noise sits on both halves of the dash.
    var title = cleanText(track.title.trim());
    var artist = cleanArtist(track.artist.trim());

    // A dash with no spaces ("CHASE ATLANTIC-ROXANNE") is a separator too, but
    // only when the known artist is unknown; real titles can contain dashes.
    final dashSplit = _isUnknownArtist(artist)
        ? _splitTitle(title) ?? _splitTightTitle(title)
        : null;
    if (dashSplit != null) {
      artist = dashSplit.$1;
      title = dashSplit.$2;
    }

    title = cleanText(title);
    artist = cleanArtist(artist);

    // "Chase Atlantic - Church" with the artist already known: drop the echo.
    if (!_isUnknownArtist(artist)) {
      final echo = RegExp(
        r'^' + RegExp.escape(artist) + r'\s*[-–—]\s*',
        caseSensitive: false,
      );
      if (echo.hasMatch(title)) title = title.replaceFirst(echo, '').trim();
    }
    final album = cleanText(track.album ?? '');

    return LyricsQuery(
      title: title,
      artist: _isUnknownArtist(artist) || artist.isEmpty ? null : artist,
      album: album.isEmpty ? null : album,
      duration: track.duration,
    );
  }

  static final _downloadSuffix = RegExp(r'[_\-\s]*\d{10,}\s*$');
  static final _bracket = RegExp(r'[\(\[\{]([^\)\]\}]*)[\)\]\}]');
  static final _noise = RegExp(
    r'\b(lyrics?|official|audio|video|visuali[sz]er|music\s+video|mv|hd|hq|remaster(ed)?|lyric\s+video|topic)\b',
    caseSensitive: false,
  );
  static final _trailingLyrics = RegExp(
    r'[\s\-–—]+lyrics?\s*$',
    caseSensitive: false,
  );
  static final _split = RegExp(r'\s+[-–—]\s+');

  /// "Daft Punk - Aerodynamic" -> ("Daft Punk", "Aerodynamic").
  static (String, String)? _splitTitle(String text) {
    final match = _split.firstMatch(text);
    if (match == null) return _splitTightTitle(text);
    final left = text.substring(0, match.start).trim();
    final right = text.substring(match.end).trim();
    if (left.isEmpty || right.isEmpty) return null;
    return (left, right);
  }

  /// "CHASE ATLANTIC-ROXANNE" -> ("CHASE ATLANTIC", "ROXANNE"). Only splits on a
  /// dash that follows a letter-heavy artist half, so "Jay-Z - Song" stays put.
  static (String, String)? _splitTightTitle(String text) {
    final dash = text.indexOf(RegExp(r'[-–—]'));
    if (dash <= 1 || dash >= text.length - 2) return null;
    final left = text.substring(0, dash).trim();
    final right = text.substring(dash + 1).trim();
    if (left.isEmpty || right.isEmpty) return null;
    final leftWords = left.split(RegExp(r'\s+')).length;
    if (leftWords < 1 || leftWords > 4) return null;
    // "Jay-Z - Song" splits on the spaced dash, not the hyphen inside a name.
    if (RegExp(r'[A-Za-z]-[A-Z][a-z]').hasMatch(left)) return null;
    return (left, right);
  }

  static bool _isUnknownArtist(String artist) {
    final lower = artist.toLowerCase().trim();
    return lower.isEmpty ||
        lower == 'unknown artist' ||
        lower == 'unknown' ||
        lower == '<unknown>';
  }

  /// Removes download suffixes, banner brackets and a trailing "Lyrics".
  static String cleanText(String raw) {
    var text = raw.replaceAll(_downloadSuffix, '').trim();
    text = text.replaceAllMapped(_bracket, (match) {
      final inside = match.group(1) ?? '';
      return _noise.hasMatch(inside) ? ' ' : match.group(0)!;
    });
    text = text.replaceAll(_trailingLyrics, '');
    return text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  static String cleanArtist(String raw) {
    final text = raw.replaceAll(
      RegExp(r'\s*-\s*topic\s*$', caseSensitive: false),
      '',
    );
    return text.replaceAll(_downloadSuffix, '').trim();
  }
}

/// Parses an LRCLIB response (one record or a list of candidates) and picks the
/// best match for [query]. Timestamped lyrics are preferred over plain text.
Lyrics? parseLrclib(String body, LyricsQuery query) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }

  final records = switch (decoded) {
    List<dynamic> list => list.whereType<Map>(),
    Map<dynamic, dynamic> map => [map],
    _ => const <Map>[],
  };
  if (records.isEmpty) return null;

  Map<dynamic, dynamic>? best;
  var bestScore = -1000;
  for (final record in records) {
    final score = _score(record, query);
    if (score > bestScore) {
      best = record;
      bestScore = score;
    }
  }
  if (best == null || bestScore < 0) return null;
  return _lyricsOf(best);
}

Lyrics? _lyricsOf(Map<dynamic, dynamic> record) {
  if (record['instrumental'] == true) return null;
  final synced = (record['syncedLyrics'] as String?)?.trim();
  final raw = (synced != null && synced.isNotEmpty)
      ? synced
      : (record['plainLyrics'] as String?)?.trim();
  if (raw == null || raw.isEmpty) return null;
  return Lyrics.parse(raw);
}

int _score(Map<dynamic, dynamic> record, LyricsQuery query) {
  final title = _normalize(
    _text(record['trackName']) ?? _text(record['name']) ?? '',
  );
  final artist = _normalize(_text(record['artistName']) ?? '');
  final wantedTitle = _normalize(query.title);
  final wantedArtist = _normalize(query.artist ?? '');
  if (title.isEmpty || wantedTitle.isEmpty) return -1000;

  var score = 0;
  if (title == wantedTitle) {
    score += 8;
  } else if (title.contains(wantedTitle) || wantedTitle.contains(title)) {
    score += 3;
  } else {
    score -= 6;
  }

  if (wantedArtist.isNotEmpty) {
    if (artist == wantedArtist) {
      score += 5;
    } else if (artist.contains(wantedArtist) || wantedArtist.contains(artist)) {
      score += 2;
    } else {
      score -= 12; // a different artist is almost always the wrong song
    }
  }

  final duration = record['duration'];
  if (query.duration != null && duration is num) {
    final diff = (duration - query.duration!.inSeconds).abs();
    if (diff <= 3) {
      score += 5;
    } else if (diff <= 8) {
      score += 3;
    } else if (diff <= 20) {
      score += 1;
    } else {
      score -= 4;
    }
  }

  final synced = (_text(record['syncedLyrics']) ?? '').trim();
  final plain = (_text(record['plainLyrics']) ?? '').trim();
  if (synced.isNotEmpty) score += 2;
  if (synced.isEmpty && plain.isEmpty) score -= 10;
  if (record['instrumental'] == true) score -= 8;
  return score;
}

String? _text(Object? value) => value is String ? value : null;

String _normalize(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
