import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:music_player/audio/engine.dart';

/// In-memory stand-in for the real player: no platform channels, so the whole
/// player can run inside `flutter test`.
class FakeEngine implements PlaybackEngine {
  final List<AudioSource> sources = [];

  int? _index;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  bool disposed = false;

  final _indexController = StreamController<int?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _loopController = StreamController<LoopMode>.broadcast();

  /// Simulates the audio backend reporting progress.
  void emitPosition(Duration position) {
    _position = position;
    _positionController.add(position);
  }

  /// Simulates a song that cannot be loaded or decoded.
  void emitError(Object error) => _errorController.add(error);

  // just_audio's streams are behaviour subjects: whoever subscribes gets the
  // current value straight away. These getters do the same so widgets that
  // subscribe after playback started still see the right state.
  @override
  Stream<int?> get currentIndexStream async* {
    yield _index;
    yield* _indexController.stream;
  }

  @override
  Stream<bool> get playingStream async* {
    yield _playing;
    yield* _playingController.stream;
  }

  @override
  Stream<Object> get errorStream => _errorController.stream;

  @override
  Stream<Duration> get positionStream async* {
    yield _position;
    yield* _positionController.stream;
  }

  @override
  Stream<Duration?> get durationStream async* {
    yield _duration;
    yield* _durationController.stream;
  }

  @override
  Stream<bool> get shuffleModeStream async* {
    yield _shuffle;
    yield* _shuffleController.stream;
  }

  @override
  Stream<LoopMode> get loopModeStream async* {
    yield _loopMode;
    yield* _loopController.stream;
  }

  @override
  int? get currentIndex => _index;

  @override
  bool get playing => _playing;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  bool get shuffleEnabled => _shuffle;

  @override
  LoopMode get loopMode => _loopMode;

  @override
  bool get hasNext => _index != null && _index! + 1 < sources.length;

  @override
  bool get hasPrevious => _index != null && _index! > 0;

  @override
  Future<void> setQueue(
    List<AudioSource> newSources, {
    int initialIndex = 0,
    Duration? initialPosition,
  }) async {
    sources
      ..clear()
      ..addAll(newSources);
    _index = sources.isEmpty ? null : initialIndex;
    _position = initialPosition ?? Duration.zero;
    _duration = const Duration(seconds: 30);
    _indexController.add(_index);
    _positionController.add(_position);
    _durationController.add(_duration);
  }

  @override
  Future<void> insertSources(int index, List<AudioSource> newSources) async {
    sources.insertAll(index, newSources);
    if (_index != null && index <= _index!) {
      _index = _index! + newSources.length;
      _indexController.add(_index);
    }
  }

  @override
  Future<void> removeAt(int index) async {
    sources.removeAt(index);
    if (_index != null && index < _index!) {
      _index = _index! - 1;
      _indexController.add(_index);
    }
  }

  @override
  Future<void> play() async {
    _playing = true;
    _playingController.add(true);
    if (_duration != null) _durationController.add(_duration);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    if (index != null) {
      _index = index;
      _indexController.add(index);
    }
    _position = position;
    _positionController.add(position);
  }

  @override
  Future<void> seekToNext() async {
    if (hasNext) {
      _index = _index! + 1;
    } else if (_loopMode == LoopMode.all && sources.isNotEmpty) {
      _index = 0;
    } else {
      return;
    }
    _indexController.add(_index);
    _position = Duration.zero;
    _positionController.add(_position);
  }

  @override
  Future<void> seekToPrevious() async {
    if (!hasPrevious) return;
    _index = _index! - 1;
    _indexController.add(_index);
    _position = Duration.zero;
    _positionController.add(_position);
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    _shuffle = enabled;
    _shuffleController.add(enabled);
  }

  @override
  Future<void> setLoop(LoopMode loopMode) async {
    _loopMode = loopMode;
    _loopController.add(loopMode);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _indexController.close();
    await _playingController.close();
    await _errorController.close();
    await _positionController.close();
    await _durationController.close();
    await _shuffleController.close();
    await _loopController.close();
  }
}
