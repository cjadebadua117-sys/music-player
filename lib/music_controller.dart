import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/importer.dart';
import 'app/lyrics_lookup.dart';
import 'app/local_lyrics.dart';
import 'app/notification_permission.dart';
import 'app/lyrics_service.dart';
import 'app/media_tags.dart';
import 'app/music_scanner.dart';
import 'audio/engine.dart';
import 'models/lyrics.dart';
import 'models/track.dart';

/// Owns the song library and drives playback.
///
/// The library is assembled from three places, in this order: songs found on the
/// phone (MediaStore), songs the user added with the file picker, and — only when
/// there is nothing else — the bundled demos. The queue inside the engine always
/// mirrors [library] one-to-one, which is what lets the UI map a track to its
/// queue position.
class MusicController extends ChangeNotifier {
  MusicController(
    this._engine, {
    MusicScanner? scanner,
    LyricsService? lyrics,
    LyricsLookup? lyricsLookup,
  }) : _scanner = scanner ?? ChannelMusicScanner(),
       _lyricsService = lyrics ?? ChannelLyricsService(),
       _lyricsLookup = lyricsLookup ?? createLyricsLookup();

  static const _libraryKey = 'library.v1';
  static const _lyricsKey = 'lyrics.v1';
  static const _lyricOffsetsKey = 'lyrics.offset.v1';
  static const _hiddenKey = 'hidden.v1';
  static const _askedKey = 'scan.asked';
  static const _favoritesKey = 'favorites.v1';
  static const _moodsKey = 'moods.v1';
  static const _recentKey = 'recent.v1';

  /// The mood chips on the home screen. Songs opt in from their ⋮ menu.
  static const moodNames = ['Focus', 'Chill', 'Gym'];

  final PlaybackEngine _engine;
  final MusicScanner _scanner;
  final LyricsService _lyricsService;
  final LyricsLookup _lyricsLookup;

  /// Songs that ship with a verified local lyrics bundle (songs the public
  /// databases do not cover). Evaluated lazily so the class can stay const-safe
  /// while the bundle itself is a real parsed [Lyrics] object.
  static final _bundledLyrics = <String, Lyrics>{
    _bundledKey('Panaginip', 'nicole'): LocalLyrics.panaginipNicole(),
  };

  /// Matches a song to a verified local lyrics bundle by title + artist (case
  /// insensitive, nulls friendly). Bundles are intentionally keyed the same
  /// way the rest of the class keys cached lyrics, so a user-added copy and the
  /// bundled copy resolve to the same words.
  static String _bundledKey(String title, String? artist) {
    final name = title.toLowerCase().trim();
    final author =
        (artist == null || artist.toLowerCase().trim().isEmpty)
            ? ''
            : artist.toLowerCase().trim();
    return author.isEmpty ? name : '$name|$author';
  }

  Lyrics? _lyrics;
  bool _lyricsLoading = false;
  String? _lyricsTrackId;

  /// Parsed lyrics for this session, keyed by title + artist.
  final Map<String, Lyrics> _memoryLyrics = {};

  /// Lookups already in flight, so the player and the background prefetch do
  /// not request the same song twice.
  final Map<String, Future<Lyrics?>> _lyricsRequests = {};

  /// Songs the sources had nothing for this session. Cleared by Try again.
  final Set<String> _lyricsMisses = {};

  bool _preloadingLyrics = false;

  /// Downloaded lyrics kept on the phone, as LRC/plain text.
  final Map<String, String> _savedLyrics = {};

  /// Per-song timing nudge for synced lyrics, in milliseconds. LRCLIB is
  /// usually close but a download can have a different intro or edit; this is
  /// what lets the user line the words up exactly.
  final Map<String, int> _lyricOffsets = {};

  final List<Track> _library = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Songs the user swiped away; those stay out of the library after a rescan.
  final Set<String> _hidden = {};

  /// Songs the user hearted, matched by title + artist so a rescan (which can
  /// renumber MediaStore rows) keeps them.
  final Set<String> _favorites = {};

  /// Mood name -> keys of the songs tagged with it.
  final Map<String, Set<String>> _moods = {
    for (final mood in moodNames) mood: <String>{},
  };

  /// Recently played songs, newest first (keys, so rescans keep the order).
  final List<String> _recent = [];

  /// Manual imports, restored from storage so they survive a restart.
  List<Track> _saved = const [];

  bool _ready = false;
  bool _scanning = false;
  bool _permissionDenied = false;
  String? _scanError;

  /// Something that went wrong while playing: unreadable file, unsupported
  /// codec, another app holding the audio. Shown in the UI so a bad song does
  /// not look like a frozen player.
  String? _playbackError;

  /// Whether Android has already been asked for the notification permission
  /// this session.
  bool _notificationAsked = false;

  /// Completes once the engine holds the initial queue. Playback commands wait
  /// for it so the library can appear before the first track has loaded.
  Future<void> _queueReady = Future.value();

  /// The device-library sync started by [init], for callers that want to wait
  /// for the phone's songs to be in place (tests, mainly).
  Future<void> _deviceSync = Future.value();

  List<Track> get library => List.unmodifiable(_library);
  bool get ready => _ready;
  Future<void> get queueReady => _queueReady;
  Future<void> get deviceSync => _deviceSync;
  bool get canImport => importSupported;
  bool get canScan => _scanner.supported;
  bool get scanning => _scanning;
  bool get permissionDenied => _permissionDenied;
  String? get scanError => _scanError;
  String? get playbackError => _playbackError;

  /// Lyrics for the current track (null while absent or still loading).
  Lyrics? get lyrics => _lyrics;
  bool get lyricsLoading => _lyricsLoading;

  /// How far the current song's lyrics are nudged, in milliseconds.
  int get lyricOffsetMs {
    final track = currentTrack;
    return track == null ? 0 : (_lyricOffsets[_favoriteKey(track)] ?? 0);
  }

  Duration get lyricOffset => Duration(milliseconds: lyricOffsetMs);

  /// Songs found on the phone.
  List<Track> get deviceTracks => [
    for (final t in _library)
      if (t.isOnDevice) t,
  ];

  /// Songs added by hand through the file picker.
  List<Track> get importedTracks => [
    for (final t in _library)
      if (!t.demo && !t.isOnDevice) t,
  ];

  List<Track> get bundledTracks => [
    for (final t in _library)
      if (t.demo) t,
  ];

  int? get currentIndex => _engine.currentIndex;
  bool get playing => _engine.playing;
  bool get shuffleEnabled => _engine.shuffleEnabled;
  LoopMode get loopMode => _engine.loopMode;
  Duration get position => _engine.position;

  Stream<Duration> get positionStream => _engine.positionStream;
  Stream<Duration?> get durationStream => _engine.durationStream;

  Track? get currentTrack {
    final index = _engine.currentIndex;
    if (index == null || index < 0 || index >= _library.length) return null;
    return _library[index];
  }

  int indexOf(Track track) => _library.indexOf(track);

  bool isFavorite(Track track) => _favorites.contains(_favoriteKey(track));

  bool isInMood(Track track, String mood) =>
      _moods[mood]?.contains(_favoriteKey(track)) ?? false;

  /// Songs in [recentTracks] order (newest first) that carry [mood].
  List<Track> tracksInMood(String mood) => [
    for (final track in recentTracks)
      if (isInMood(track, mood)) track,
  ];

  /// Adds or removes a song from a mood chip.
  Future<void> toggleMood(Track track, String mood) async {
    final set = _moods[mood];
    if (set == null) return;
    final key = _favoriteKey(track);
    if (!set.remove(key)) set.add(key);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _moodsKey,
      jsonEncode({
        for (final entry in _moods.entries) entry.key: entry.value.toList(),
      }),
    );
  }

  /// Newest first, then everything else in library order, so the list is always
  /// complete even on a fresh install.
  List<Track> get recentTracks {
    final byKey = {for (final track in _library) _favoriteKey(track): track};
    final ordered = <Track>[];
    final seen = <String>{};
    for (final key in _recent) {
      final track = byKey[key];
      if (track != null && seen.add(key)) ordered.add(track);
    }
    for (final track in _library) {
      if (seen.add(_favoriteKey(track))) ordered.add(track);
    }
    return ordered;
  }

  /// Loads lyrics for the current track, in this order: embedded tags, then
  /// the on-device cache, then online sources (cached locally on success).
  Future<void> _loadLyrics() async {
    final track = currentTrack;
    if (track == null) {
      _lyrics = null;
      _lyricsLoading = false;
      return;
    }
    if (_lyricsTrackId == track.id) return;
    _lyricsTrackId = track.id;

    final key = _favoriteKey(track);
    final known = _memoryLyrics[key];
    if (known != null) {
      _lyrics = known;
      _lyricsLoading = false;
      notifyListeners();
      return;
    }

    _lyrics = null;
    _lyricsLoading = true;
    notifyListeners();

    final result = await _fetchLyrics(track);
    if (_lyricsTrackId != track.id) return; // the user skipped on
    _lyrics = result;
    _lyricsLoading = false;
    notifyListeners();
  }

  /// Reads lyrics for one song and caches the result. Shared by the player and
  /// the background prefetch, so every song in the library gets lyrics before
  /// the user reaches it whenever a source has them.
  Future<Lyrics?> _fetchLyrics(Track track, {bool rememberMiss = true}) {
    final key = _favoriteKey(track);
    final known = _memoryLyrics[key];
    if (known != null) return Future.value(known);
    if (_lyricsMisses.contains(key)) return Future.value(null);

    final inFlight = _lyricsRequests[key];
    if (inFlight != null) return inFlight;

    final future = _readLyrics(track, key, rememberMiss: rememberMiss);
    _lyricsRequests[key] = future;
    return future.whenComplete(() => _lyricsRequests.remove(key));
  }

  Future<Lyrics?> _readLyrics(
    Track track,
    String key, {
    required bool rememberMiss,
  }) async {
    // 1. Lyrics stored inside the file (works with no connection at all).
    // This includes songs added from Downloads, whose LRC tags are usually
    // timed to that exact edit — the most accurate sync available.
    Lyrics? result;
    if (_lyricsService.supported && !track.demo) {
      result = await _lyricsService.load(track);
    }

    // 2. Lyrics downloaded earlier and kept on the phone.
    if (result == null) {
      final saved = _savedLyrics[key];
      if (saved != null) result = Lyrics.parse(saved);
    }

    // 3. Bundled verified copy first (songs the databases genuinely do not
    // cover), then the online chain: LRCLIB (timed) → Genius → lyrics.ovh
    // (plain). Either way, a hit is cached locally so the app keeps it offline.
    if (result == null && !track.demo) {
      final local = _bundledLyrics[_favoriteKey(track)];
      if (local != null) {
        result = local;
      } else {
        result = await _lyricsLookup.find(track);
      }
      if (result != null) {
        _savedLyrics[key] = result.toLrc();
        _trimLyricsCache();
        unawaited(_persistLyrics());
      }
    }

    if (result != null) {
      _memoryLyrics[key] = result;
    } else if (rememberMiss) {
      _lyricsMisses.add(key);
    }
    return result;
  }

  /// Fetches lyrics for the whole library in the background, one song at a
  /// time so playback and scrolling stay responsive. Runs after a scan or an
  /// import; anything already cached is skipped.
  void _preloadLyrics() {
    if (_preloadingLyrics || !_lyricsLookup.reachable) return;
    _preloadingLyrics = true;
    unawaited(_runLyricsPreload());
  }

  Future<void> _runLyricsPreload() async {
    try {
      final snapshot = List<Track>.of(_library);
      for (final track in snapshot) {
        if (!_lyricsLookup.reachable) break;
        if (!_library.any((song) => song.id == track.id)) continue;
        if (track.demo || track.id == currentTrack?.id) continue;
        final key = _favoriteKey(track);
        if (_memoryLyrics.containsKey(key) ||
            _savedLyrics.containsKey(key) ||
            _lyricsMisses.contains(key)) {
          continue;
        }
        await _fetchLyrics(track, rememberMiss: false);
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      _preloadingLyrics = false;
    }
  }

  /// Drops a failed/outdated result and asks again, for the panel's retry.
  Future<void> reloadLyrics() async {
    final track = currentTrack;
    if (track == null) return;
    final key = _favoriteKey(track);
    _memoryLyrics.remove(key);
    _savedLyrics.remove(key);
    _lyricsMisses.remove(key);
    await _persistLyrics();
    _lyricsTrackId = null;
    await _loadLyrics();
  }

  void _loadSavedLyrics(String? raw) {
    _savedLyrics.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      data.forEach((key, value) {
        if (key is String && value is String && value.trim().isNotEmpty) {
          _savedLyrics[key] = value;
        }
      });
    } on FormatException {
      // Corrupt cache: fetch again rather than failing to show lyrics.
    }
  }

  void _trimLyricsCache() {
    // Keep the store small: lyrics are a few KB each, but a huge library
    // should not grow SharedPreferences without a ceiling.
    while (_savedLyrics.length > 200) {
      _savedLyrics.remove(_savedLyrics.keys.first);
    }
  }

  Future<void> _persistLyrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lyricsKey, jsonEncode(_savedLyrics));
  }

  void _loadLyricOffsets(String? raw) {
    _lyricOffsets.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      data.forEach((key, value) {
        if (key is String && value is num) {
          _lyricOffsets[key] = value.toInt();
        }
      });
    } on FormatException {
      // Corrupt sync store: start aligned at zero rather than failing.
    }
  }

  Future<void> _persistLyricOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lyricOffsetsKey, jsonEncode(_lyricOffsets));
  }

  /// Moves the current song's lyrics [deltaMs] closer to perfect sync.
  /// Positive values make the words light up later.
  Future<void> nudgeLyricOffset(int deltaMs) async {
    final track = currentTrack;
    if (track == null) return;
    final key = _favoriteKey(track);
    final next = ((_lyricOffsets[key] ?? 0) + deltaMs)
        .clamp(-10000, 10000)
        .toInt();
    if (next == 0) {
      _lyricOffsets.remove(key);
    } else {
      _lyricOffsets[key] = next;
    }
    notifyListeners();
    await _persistLyricOffsets();
  }

  Future<void> resetLyricOffset() async {
    final track = currentTrack;
    if (track == null) return;
    _lyricOffsets.remove(_favoriteKey(track));
    notifyListeners();
    await _persistLyricOffsets();
  }

  /// Locks the lyrics to the song: [line] is the line the user tapped because
  /// it was being sung at [position]. The difference becomes this song's saved
  /// offset, so every line after it stays aligned too.
  Future<void> alignLyricsTo(Duration line, Duration position) async {
    final track = currentTrack;
    if (track == null) return;
    final key = _favoriteKey(track);
    final next = (line - position).inMilliseconds.clamp(-10000, 10000).toInt();
    if (next == 0) {
      _lyricOffsets.remove(key);
    } else {
      _lyricOffsets[key] = next;
    }
    notifyListeners();
    await _persistLyricOffsets();
  }

  Future<void> _remember(int? index) async {
    if (index == null || index < 0 || index >= _library.length) return;
    final key = _favoriteKey(_library[index]);
    _recent.remove(key);
    _recent.insert(0, key);
    if (_recent.length > 50) _recent.removeRange(50, _recent.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recent);
  }

  void _loadMoods(String? raw) {
    for (final set in _moods.values) {
      set.clear();
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      data.forEach((mood, keys) {
        final set = _moods['$mood'];
        if (set != null && keys is List) {
          set.addAll(keys.whereType<String>());
        }
      });
    } on FormatException {
      // Corrupt mood store: start clean rather than crashing the library.
    }
  }

  /// Hearts or un-hearts a song; the choice survives restarts and rescans.
  Future<void> toggleFavorite(Track track) async {
    final key = _favoriteKey(track);
    if (!_favorites.remove(key)) _favorites.add(key);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.toList());
  }

  bool isCurrent(int index) => _engine.currentIndex == index;
  bool isPlayingIndex(int index) =>
      _engine.currentIndex == index && _engine.playing;

  /// Shows what is already known (imported songs, or demos), then looks for
  /// music on the device in the background so the UI is never waiting on it.
  Future<void> init() async {
    _subscriptions.addAll([
      _engine.currentIndexStream.listen((index) {
        // Queue changes while playing (auto-advance, notification buttons) are
        // what "recently played" should mean; merely loading a queue is not.
        if (_engine.playing) _remember(index);
        unawaited(_loadLyrics());
        notifyListeners();
      }),
      _engine.playingStream.listen((_) => notifyListeners()),
      _engine.errorStream.listen((error) {
        debugPrint('Playback error: $error');
        _playbackError = _describePlaybackError(error);
        notifyListeners();
      }),
      _engine.shuffleModeStream.listen((_) => notifyListeners()),
      _engine.loopModeStream.listen((_) => notifyListeners()),
    ]);

    final prefs = await SharedPreferences.getInstance();
    _saved = _decodeLibrary(
      prefs.getString(_libraryKey),
    ).map(_cleanTrack).toList();
    _hidden
      ..clear()
      ..addAll(prefs.getStringList(_hiddenKey) ?? const []);
    _favorites
      ..clear()
      ..addAll(prefs.getStringList(_favoritesKey) ?? const []);
    _recent
      ..clear()
      ..addAll(prefs.getStringList(_recentKey) ?? const []);
    _loadMoods(prefs.getString(_moodsKey));
    _loadSavedLyrics(prefs.getString(_lyricsKey));
    _loadLyricOffsets(prefs.getString(_lyricOffsetsKey));

    _rebuildLibrary();
    _queueReady = _loadQueue();
    _ready = true;
    unawaited(_loadLyrics());
    notifyListeners();

    _deviceSync = syncDeviceLibrary(
      requestIfNeeded: !(prefs.getBool(_askedKey) ?? false),
    );
    unawaited(_deviceSync);
  }

  /// Asks for the audio permission (once) and rebuilds the library from
  /// MediaStore. Safe to call again — that is what the refresh button does.
  Future<void> syncDeviceLibrary({bool requestIfNeeded = true}) async {
    if (!_scanner.supported || _scanning) return;
    _scanning = true;
    _scanError = null;
    notifyListeners();

    try {
      var granted = await _scanner.hasPermission();
      if (!granted && requestIfNeeded) {
        granted = await _scanner.requestPermission();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_askedKey, true);
      }
      _permissionDenied = !granted;
      if (granted) {
        final songs = await _scanner.scan();
        await _applyDeviceSongs(songs);
      }
    } catch (error) {
      _scanError = '$error';
    }

    _scanning = false;
    notifyListeners();
    _preloadLyrics();
  }

  /// Replaces the on-device part of the library, keeping playback where it was.
  Future<void> _applyDeviceSongs(List<Track> songs) async {
    // Never race the queue load started by [init].
    await _queueReady;
    final playingTrack = currentTrack;
    final wasPlaying = _engine.playing;

    final found = [
      for (final song in songs)
        if (!_hidden.contains(song.id)) song,
    ];
    final changed =
        found.length != deviceTracks.length || !_sameOrder(found, deviceTracks);
    if (!changed) return;

    // A file the user imported by hand may also be visible to MediaStore; show
    // it once, from the phone, rather than twice. Compare the cleaned titles as
    // well: an older import still carries the YouTube name
    // ("August (lyrics)_1792127346539") while the MediaStore copy is "August".
    final onPhone = {for (final song in found) _titleArtistKey(song)};
    _saved = [
      for (final track in _saved)
        if (!onPhone.contains(_titleArtistKey(track)) &&
            !onPhone.contains(_cleanedKey(track)))
          track,
    ];
    _deviceSongs = found;
    _rebuildLibrary();
    await _reloadQueue(playingTrack, wasPlaying);
  }

  List<Track> _deviceSongs = const [];

  void _rebuildLibrary() {
    // Songs found on the phone (minus the ones swiped away), then anything
    // added by hand. The bundled demos only appear when there is nothing else.
    _library
      ..clear()
      ..addAll(_deviceSongs.where((t) => !_hidden.contains(t.id)))
      ..addAll(_saved);
    if (_library.isEmpty) _library.addAll(demoTracks);
  }

  /// Points the engine at the current library, restoring the song that was
  /// playing (a rescan while listening should not lose your place).
  Future<void> _reloadQueue(Track? keep, bool wasPlaying) async {
    final sources = [
      for (final t in _library) t.toAudioSource(tag: mediaTagFor(t)),
    ];
    if (sources.isEmpty) return;
    // A rescan produces new Track objects for the same MediaStore rows, so
    // compare ids: matching the old object would always fail and restart the
    // queue at song one, stopping whatever was playing.
    final index = keep == null
        ? -1
        : _library.indexWhere((track) => track.id == keep.id);
    final startAt = index < 0 ? 0 : index;
    final resumeAt = index < 0 ? Duration.zero : _engine.position;
    try {
      await _engine.setQueue(
        sources,
        initialIndex: startAt,
        initialPosition: resumeAt,
      );
      if (wasPlaying) unawaited(_startPlayback());
    } catch (error) {
      debugPrint('Could not rebuild the queue: $error');
      _playbackError = 'Could not refresh the queue: $error';
      notifyListeners();
    }
  }

  Future<void> _loadQueue() async {
    final sources = [
      for (final t in _library) t.toAudioSource(tag: mediaTagFor(t)),
    ];
    if (sources.isEmpty) return;
    try {
      await _engine
          .setQueue(sources, initialIndex: 0)
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      // A track that fails to preload should not take the app down with it:
      // tapping a song retries the load through the normal path.
      debugPrint('Could not preload the queue: $error');
    }
  }

  Future<void> playTrackAt(int index) async {
    await _queueReady;
    if (index < 0 || index >= _library.length) return;
    _playbackError = null;
    _askForNotificationPermission();
    if (_engine.currentIndex != index) {
      try {
        await _engine.seek(Duration.zero, index: index);
      } catch (error) {
        _playbackError = 'Could not open "${_library[index].title}": $error';
        notifyListeners();
        return;
      }
    }
    if (!_engine.playing) unawaited(_startPlayback());
    await _remember(index);
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _queueReady;
    if (_engine.playing) {
      await _engine.pause();
      return;
    }
    if (_engine.currentIndex == null) {
      await playTrackAt(0);
      return;
    }
    _askForNotificationPermission();
    unawaited(_startPlayback());
  }

  /// The first play is a natural moment to ask Android 13+ for the playback
  /// notification permission (lock-screen controls). Denying it only hides
  /// the controls; it never blocks playback.
  void _askForNotificationPermission() {
    if (_notificationAsked) return;
    _notificationAsked = true;
    unawaited(requestPlaybackNotificationPermission());
  }

  /// Starts playback without waiting for the song to finish.
  ///
  /// just_audio's `play()` completes only when playback stops (or is paused),
  /// so awaiting it here would keep "recently played" and rescan completion
  /// blocked for the length of the song.
  Future<void> _startPlayback() async {
    try {
      await _engine.play();
    } catch (error) {
      debugPrint('Could not start playback: $error');
      _playbackError = _describePlaybackError(error);
      notifyListeners();
    }
  }

  String _describePlaybackError(Object error) {
    final track = currentTrack;
    final name = track == null ? 'this song' : '"${track.title}"';
    if (error is PlayerException) {
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) return 'Could not play $name: $message';
    }
    return 'Could not play $name. The file may be unreadable or unsupported.';
  }

  /// Dismisses the last playback problem shown in the UI.
  void clearPlaybackError() {
    if (_playbackError == null) return;
    _playbackError = null;
    notifyListeners();
  }

  Future<void> next() async {
    await _queueReady;
    if (!_engine.hasNext && _engine.loopMode != LoopMode.all) return;
    await _engine.seekToNext();
  }

  /// Restarts the current song when part-way through it, like most players.
  Future<void> previous() async {
    await _queueReady;
    if (_engine.position > const Duration(seconds: 3)) {
      await _engine.seek(Duration.zero);
      return;
    }
    if (_engine.hasPrevious) {
      await _engine.seekToPrevious();
      return;
    }
    await _engine.seek(Duration.zero);
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> toggleShuffle() =>
      _engine.setShuffleEnabled(!_engine.shuffleEnabled);

  Future<void> cycleLoopMode() {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    final next = order[(order.indexOf(_engine.loopMode) + 1) % order.length];
    return _engine.setLoop(next);
  }

  /// Lets the user pick songs off the device. Returns how many songs were added,
  /// or -1 when the platform has no file system to import from.
  Future<int> importTracks() async {
    if (!importSupported) return -1;
    await _queueReady;
    final picked = await pickAndCopyTracks();
    if (picked.isEmpty) return 0;

    final existing = {for (final t in _library) t.path};
    final fresh = [
      for (final track in picked)
        if (!existing.contains(track.path)) track,
    ];
    if (fresh.isEmpty) return 0;

    _saved = [..._saved, ...fresh.map(_cleanTrack)];
    _rebuildLibrary();
    await _reloadQueue(currentTrack, _engine.playing);
    await _save();
    notifyListeners();
    _preloadLyrics();
    return fresh.length;
  }

  /// Removes a song from the library. On-device songs are only hidden: the file
  /// belongs to the user, not to this app.
  Future<void> removeTrack(Track track) async {
    if (track.demo) return;
    await _queueReady;
    final index = _library.indexOf(track);
    if (index < 0) return;

    if (track.isOnDevice) {
      _hidden.add(track.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hidden.toList());
    } else {
      _saved = [
        for (final t in _saved)
          if (t.id != track.id) t,
      ];
      await _save();
    }

    final playingTrack = currentTrack;
    final wasPlaying = _engine.playing;
    _rebuildLibrary();
    await _reloadQueue(playingTrack, wasPlaying);
    notifyListeners();
  }

  List<Track> _decodeLibrary(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      final tracks = <Track>[];
      for (final entry in data) {
        if (entry is! Map) continue;
        final track = Track.fromJson(entry.cast<String, dynamic>());
        if (!trackFileExists(track.path)) continue; // deleted outside the app
        tracks.add(track);
      }
      return tracks;
    } on FormatException {
      return const []; // corrupt store: start from what the device has
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _libraryKey,
      jsonEncode([for (final t in _saved) t.toJson()]),
    );
  }

  static String _titleArtistKey(Track track) =>
      '${track.title}|${track.artist}'.toLowerCase();

  static String _favoriteKey(Track track) => _titleArtistKey(track);

  /// Removes the YouTube-style noise ("...(Lyrics)_1792127346539", a missing
  /// artist) from songs the user added by hand, so the player and the library
  /// read like a music app. Identity (id and paths) is untouched.
  static Track _cleanTrack(Track track) {
    if (track.demo) return track;
    final query = LyricsQuery.from(track);
    final title = query.title.trim();
    if (title.isEmpty) return track;
    final artist = query.artist?.trim();
    return Track(
      id: track.id,
      title: title,
      artist: artist == null || artist.isEmpty ? track.artist : artist,
      path: track.path,
      source: track.source,
      album: track.album,
      albumId: track.albumId,
      duration: track.duration,
      filePath: track.filePath,
    );
  }

  /// The title/artist the app would show after stripping download noise. Used
  /// only to recognise that an imported file and a MediaStore row are the same
  /// song, even if one still has its raw file name.
  static String _cleanedKey(Track track) {
    final query = LyricsQuery.from(track);
    final artist = query.artist?.trim();
    return '${query.title.trim()}|'
            '${artist == null || artist.isEmpty ? track.artist : artist}'
        .toLowerCase();
  }

  static bool _sameOrder(List<Track> a, List<Track> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _lyricsLookup.close();
    _engine.dispose();
    super.dispose();
  }
}
