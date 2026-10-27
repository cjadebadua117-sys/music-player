import 'package:just_audio_background/just_audio_background.dart';

import '../models/track.dart';

/// Metadata shown in the notification / lock screen for [track].
Object? mediaTagFor(Track track) => MediaItem(
  id: track.id,
  title: track.title,
  artist: track.artist,
  album: track.album ?? 'Spotibai',
  duration: track.duration,
);
