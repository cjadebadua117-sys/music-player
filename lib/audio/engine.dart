import 'package:just_audio/just_audio.dart';

/// The slice of playback the app uses.
///
/// Keeping this behind an interface lets tests run the whole player with a
/// fake engine, and keeps the UI free of just_audio plumbing.
abstract class PlaybackEngine {
  Stream<int?> get currentIndexStream;
  Stream<bool> get playingStream;

  /// Errors reported by the platform player (unreadable file, unsupported
  /// codec, missing permission). Playing must not stop silently on these.
  Stream<Object> get errorStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get shuffleModeStream;
  Stream<LoopMode> get loopModeStream;

  int? get currentIndex;
  bool get playing;
  Duration get position;
  Duration? get duration;
  bool get shuffleEnabled;
  LoopMode get loopMode;
  bool get hasNext;
  bool get hasPrevious;

  Future<void> setQueue(
    List<AudioSource> sources, {
    int initialIndex = 0,
    Duration? initialPosition,
  });
  Future<void> insertSources(int index, List<AudioSource> sources);
  Future<void> removeAt(int index);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position, {int? index});
  Future<void> seekToNext();
  Future<void> seekToPrevious();
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setLoop(LoopMode loopMode);
  Future<void> dispose();
}

/// Real engine, backed by just_audio.
///
/// On Android/iOS [AudioPlayer] is wrapped by just_audio_background (configured
/// in `main`), which gives us lock-screen controls and background playback
/// without any code here.
class JustAudioEngine implements PlaybackEngine {
  JustAudioEngine([AudioPlayer? player])
    : _player =
          player ??
          AudioPlayer(
            // Android/iOS audio focus: pause for calls, resume afterwards.
            handleInterruptions: true,
            androidApplyAudioAttributes: true,
            // A tag created from a file name can fail to decode (wrong
            // extension, moved file, unsupported codec). Skip up to three of
            // those instead of turning one bad song into a dead player.
            maxSkipsOnError: 3,
          );

  final AudioPlayer _player;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Object> get errorStream => _player.errorStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get shuffleModeStream => _player.shuffleModeEnabledStream;

  @override
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;

  @override
  int? get currentIndex => _player.currentIndex;

  @override
  bool get playing => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  bool get shuffleEnabled => _player.shuffleModeEnabled;

  @override
  LoopMode get loopMode => _player.loopMode;

  @override
  bool get hasNext => _player.hasNext;

  @override
  bool get hasPrevious => _player.hasPrevious;

  @override
  Future<void> setQueue(
    List<AudioSource> sources, {
    int initialIndex = 0,
    Duration? initialPosition,
  }) => _player.setAudioSources(
    sources,
    initialIndex: initialIndex,
    initialPosition: initialPosition,
  );

  @override
  Future<void> insertSources(int index, List<AudioSource> sources) =>
      _player.insertAudioSources(index, sources);

  @override
  Future<void> removeAt(int index) => _player.removeAudioSourceAt(index);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);

  @override
  Future<void> seekToNext() => _player.seekToNext();

  @override
  Future<void> seekToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setShuffleEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);

  @override
  Future<void> setLoop(LoopMode loopMode) => _player.setLoopMode(loopMode);

  @override
  Future<void> dispose() => _player.dispose();
}
