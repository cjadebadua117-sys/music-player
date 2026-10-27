import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'audio/engine.dart';
import 'music_controller.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
import 'widgets/frosted.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Nothing is awaited before runApp: the first frame must be drawn no matter
  // how slow (or unavailable) the audio service turns out to be. Starting the
  // audio backend before runApp is what made the app ANR on Android.
  runApp(const MusicApp());
}

class MusicApp extends StatefulWidget {
  const MusicApp({super.key, this.controller});

  /// Pre-built controller (used by tests). The app builds its own when null.
  final MusicController? controller;

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  late final Future<MusicController> _controller;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    _controller = injected != null ? Future.value(injected) : _start();
  }

  Future<MusicController> _start() async {
    await _setUpBackgroundAudio();
    final controller = MusicController(JustAudioEngine());
    await controller.init();
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotibai',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: FutureBuilder<MusicController>(
        future: _controller,
        builder: (context, snapshot) {
          final controller = snapshot.data;
          if (controller != null) return HomeScreen(controller: controller);
          if (snapshot.hasError) return _StartupError(error: snapshot.error!);
          return const _Starting();
        },
      ),
    );
  }
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        children: [
          const Backdrop(intensity: 1.2),
          Center(
            child: Frosted(
              radius: 30,
              blur: 30,
              tint: AppColors.white.withValues(alpha: 0.07),
              glow: true,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(32, 28, 32, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: accent),
                    SizedBox(height: 18),
                    Text(
                      'Starting playback…',
                      style: TextStyle(
                        color: AppColors.onMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        children: [
          const Backdrop(intensity: 1.2),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Frosted(
                radius: 30,
                blur: 30,
                tint: AppColors.white.withValues(alpha: 0.07),
                glow: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 42,
                        color: accent,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Playback could not start',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.onMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Registers the background audio service (Android/iOS) so playback keeps going
/// when the app is backgrounded, and configures the audio session so music
/// ducks properly when something else needs the speaker.
///
/// Deliberately best-effort: if the service is slow or refuses to start, the
/// app is still usable with foreground playback instead of getting stuck.
Future<void> _setUpBackgroundAudio() async {
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!mobile) return;

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.freebuff.music_player.channel.audio',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Shows the song that is playing',
      androidNotificationIcon: 'drawable/ic_stat_music',
      androidNotificationOngoing: true,
      // Keep the media service in the foreground between pause and resume.
      // Otherwise resuming from the lock screen/notification on Android 12+
      // can be refused as a background foreground-service start.
      androidStopForegroundOnPause: false,
    ).timeout(const Duration(seconds: 10));

    final session = await AudioSession.instance;
    await session
        .configure(AudioSessionConfiguration.music())
        .timeout(const Duration(seconds: 5));
  } catch (error) {
    debugPrint(
      'Background audio unavailable, continuing with foreground playback: '
      '$error',
    );
  }
}
