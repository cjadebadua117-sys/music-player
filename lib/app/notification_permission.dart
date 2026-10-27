import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks Android 13+ for permission to show the playback notification.
///
/// The notification is what carries the lock-screen controls and keeps the
/// audio foreground service visible while music plays. Deliberately
/// best-effort: a denied permission must never stop playback.
Future<void> requestPlaybackNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'music_player/media',
    ).invokeMethod<bool>('requestNotificationPermission');
  } catch (error) {
    debugPrint('Could not ask for notification permission: $error');
  }
}
