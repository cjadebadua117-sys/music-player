/// `3:07` or `1:02:44`; `--:--` while a track's length is still unknown.
String formatDuration(Duration? duration) {
  if (duration == null || duration <= Duration.zero) return '--:--';
  final total = duration.inSeconds;
  final seconds = (total % 60).toString().padLeft(2, '0');
  final minutes = total ~/ 60;
  if (minutes < 60) return '$minutes:$seconds';
  final hours = minutes ~/ 60;
  return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:$seconds';
}

/// The playback clock. Unlike [formatDuration], the very start of a track is
/// `0:00` rather than `--:--`, which stays reserved for an unknown length.
String formatClock(Duration position) {
  final total = position.inSeconds.clamp(0, 359999);
  final seconds = (total % 60).toString().padLeft(2, '0');
  final minutes = total ~/ 60;
  if (minutes < 60) return '$minutes:$seconds';
  final hours = minutes ~/ 60;
  return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:$seconds';
}

/// A library/album total, like `03h 34m` or `42m` (matches the reference card).
String formatTotalDuration(Duration total) {
  final minutes = total.inMinutes;
  if (minutes <= 0) return '0m';
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  return '${hours.toString().padLeft(2, '0')}h '
      '${(minutes % 60).toString().padLeft(2, '0')}m';
}
