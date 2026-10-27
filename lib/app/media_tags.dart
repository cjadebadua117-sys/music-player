/// On mobile/desktop builds each audio source carries a `MediaItem` tag so
/// just_audio_background can fill in the notification and lock screen. The web
/// build has no background service, so tags stay null there.
library;

export 'media_tags_stub.dart' if (dart.library.io) 'media_tags_io.dart';
