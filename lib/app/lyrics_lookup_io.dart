import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/lyrics.dart';
import '../models/track.dart';
import 'lyrics_lookup_base.dart';

/// The real online lookup. Only called from Dart IO platforms (Android, iOS,
/// desktop); the web build uses a stub.
LyricsLookup createLyricsLookup() => LrclibLookup();

/// Free, key-less lyrics database: <https://lrclib.net>.
///
/// The lookup is deliberately best-effort: when the phone is offline, the
/// server is busy, or nothing matches, it returns null and the player keeps
/// whatever embedded lyrics or cached text it already has.
/// One song result from Genius' search API.
class _GeniusHit {
  const _GeniusHit({
    required this.title,
    required this.artist,
    required this.url,
  });

  final String title;
  final String artist;
  final String url;
}

/// Extracts the lyrics text from a Genius song page. Kept top-level and public
/// so it can be tested without a network call.
String? parseGeniusLyrics(String page) {
  final document = html_parser.parse(page);
  final containers = document.querySelectorAll(
    'div[data-lyrics-container="true"]',
  );
  if (containers.isEmpty) return null;

  final buffer = StringBuffer();
  for (final container in containers) {
    // Genius embeds "You might also like" and ad blocks inside the lyric
    // container; drop anything marked as non-lyric first.
    for (final excluded in container.querySelectorAll(
      '[data-exclude-from-selection="true"]',
    )) {
      excluded.remove();
    }
    for (final br in container.querySelectorAll('br')) {
      br.replaceWith(dom.Text('\n'));
    }
    buffer.writeln(container.text);
  }

  final lines = <String>[];
  for (final raw in buffer.toString().split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
      continue;
    }
    // Section labels like [Chorus] are navigation, not sung words.
    if (RegExp(r'^\[.*\]$').hasMatch(line)) continue;
    if (line == 'Embed') continue;
    lines.add(line);
  }
  final text = lines.join('\n').trim();
  return text.isEmpty ? null : text;
}

class LrclibLookup implements LyricsLookup {
  LrclibLookup({HttpClient? client})
    : _client =
          client ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 6));

  static const _host = 'lrclib.net';
  static const _clientId = 'MusicPlayer/1.5.0 (offline-first music player)';
  static const _timeout = Duration(seconds: 8);

  final HttpClient _client;
  int _networkFailures = 0;

  @override
  bool get reachable =>
      !Platform.environment.containsKey('FLUTTER_TEST') && _networkFailures < 3;

  @override
  Future<Lyrics?> find(Track track) async {
    if (track.demo) return null;
    final query = LyricsQuery.from(track);
    if (query.title.isEmpty) return null;

    final simplified = query.simplified;
    // Attempts go from most to least precise: the appended parentheticals are
    // often the very reason the exact query has no match.
    final attempts = <(String, Map<String, String>, LyricsQuery)>[
      for (final variant in [query, simplified])
        if (variant.artist != null)
          (
            '/api/get',
            {
              'track_name': variant.title,
              'artist_name': variant.artist!,
              if (variant.album != null) 'album_name': variant.album!,
              if (variant.duration != null)
                'duration': '${variant.duration!.inSeconds}',
            },
            variant,
          ),
      // LRCLIB is case-insensitive but not punctuation-insensitive: "YOU
      // TOO._1792127373736" is stored as "YOU TOO.".
      for (final variant in [query, simplified])
        if (variant.artist != null)
          (
            '/api/search',
            {'track_name': variant.title, 'artist_name': variant.artist!},
            variant,
          ),
      for (final variant in [query, simplified])
        if (variant.artist != null)
          ('/api/search', {'q': '${variant.title} ${variant.artist}'}, variant),
      for (final variant in [query, simplified])
        ('/api/search', {'q': variant.title}, variant),
    ];

    for (final (path, params, variant) in attempts) {
      final body = await _get(Uri.https(_host, path, params));
      if (body == null) continue;
      final lyrics = parseLrclib(body, variant);
      if (lyrics != null) return lyrics;
    }

    // LRCLIB is community-run and misses some songs entirely (August by Chase
    // Atlantic, for example). Genius has the widest catalogue, then lyrics.ovh
    // catches the rest. Both are plain text, but every song gets words instead
    // of "No lyrics found".
    final genius = await _genius(query);
    if (genius != null) return genius;
    return _plain(query, simplified);
  }

  /// Genius' public search + lyric page. The search endpoint needs no key and
  /// the page embeds lyrics in `data-lyrics-container` blocks.
  Future<Lyrics?> _genius(LyricsQuery query) async {
    final term = [query.artist, query.title].whereType<String>().join(' ');
    final body = await _httpText(
      Uri.https('genius.com', '/api/search/multi', {'q': term}),
    );
    if (body == null) return null;

    final hits = <_GeniusHit>[];
    try {
      final data = jsonDecode(body);
      final response = data is Map ? data['response'] : null;
      final sections = response is Map ? response['sections'] : null;
      if (sections is List) {
        for (final section in sections) {
          if (section is! Map) continue;
          final rows = section['hits'];
          if (rows is! List) continue;
          for (final row in rows) {
            if (row is! Map || row['type'] != 'song') continue;
            final result = row['result'];
            if (result is! Map) continue;
            final url = result['url'];
            if (url is! String || url.isEmpty) continue;
            hits.add(
              _GeniusHit(
                title: '${result['title'] ?? ''}',
                artist: '${result['artist_names'] ?? ''}',
                url: url,
              ),
            );
          }
        }
      }
    } on FormatException {
      return null;
    }

    final ranked = <(int, _GeniusHit)>[
      for (final hit in hits) (_geniusScore(query, hit), hit),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    for (final (score, hit) in ranked.take(3)) {
      if (score < 60) continue;
      final page = await _httpText(
        Uri.parse(hit.url),
        accept: 'text/html,application/xhtml+xml',
      );
      if (page == null) continue;
      final text = parseGeniusLyrics(page);
      if (text != null) return Lyrics.literal(text);
    }
    return null;
  }

  int _geniusScore(LyricsQuery query, _GeniusHit hit) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

    final wanted = normalize(query.title);
    final found = normalize(hit.title);
    if (wanted.isEmpty || found.isEmpty) return -1;
    var score = 0;
    if (found == wanted) {
      score += 100;
    } else if (found.contains(wanted) || wanted.contains(found)) {
      score += 60;
    } else {
      return -1;
    }

    final artist = query.artist == null ? '' : normalize(query.artist!);
    if (artist.isNotEmpty) {
      final foundArtist = normalize(hit.artist);
      if (foundArtist == artist) {
        score += 80;
      } else if (foundArtist.contains(artist) || artist.contains(foundArtist)) {
        score += 50;
      } else {
        return -1; // another artist's lyrics would be worse than none
      }
    }
    return score;
  }

  /// Fetches text with a browser user agent. Genius and lyrics.ovh reject the
  /// app's own user agent often enough to matter.
  Future<String?> _httpText(
    Uri uri, {
    String accept = 'application/json',
  }) async {
    try {
      final request = await _client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, accept)
        ..set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        )
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      final response = await request.close().timeout(_timeout);
      final body = await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        _networkFailures = 0;
        return body;
      }
      if (response.statusCode == 404) _networkFailures = 0;
      return null;
    } on Exception {
      _networkFailures++;
      return null;
    }
  }

  Future<Lyrics?> _plain(LyricsQuery query, LyricsQuery simplified) async {
    for (final variant in [query, simplified]) {
      final artist = variant.artist;
      if (artist == null || artist.trim().isEmpty) continue;
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/'
        '${Uri.encodeComponent(artist)}/'
        '${Uri.encodeComponent(variant.title)}',
      );
      final body = await _get(uri);
      if (body == null) continue;
      try {
        final data = jsonDecode(body);
        if (data is! Map) continue;
        final text = (data['lyrics'] as String?)?.trim();
        if (text == null || text.isEmpty) continue;
        final lyrics = Lyrics.literal(text.replaceAll(RegExp(r'\r\n?'), '\n'));
        return lyrics;
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  Future<String?> _get(Uri uri, {bool retry = true}) async {
    try {
      final request = await _client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, _clientId)
        ..set('Lrclib-Client', _clientId);
      final response = await request.close().timeout(_timeout);
      final body = await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _networkFailures = 0;
        return body;
      }
      if (response.statusCode == 404) _networkFailures = 0;

      // LRCLIB returns 503 while it is overloaded or rate limited.
      if (retry && (response.statusCode == 429 || response.statusCode >= 500)) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return _get(uri, retry: false);
      }
      return null;
    } on Exception {
      _networkFailures++;
      if (retry) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return _get(uri, retry: false);
      }
      return null;
    }
  }

  @override
  void close() => _client.close(force: true);
}
