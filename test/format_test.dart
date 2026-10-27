import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/format.dart';

void main() {
  test('durations show --:-- when the length is unknown', () {
    expect(formatDuration(null), '--:--');
    expect(formatDuration(Duration.zero), '--:--');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 44)),
      '1:02:44',
    );
  });

  test('the playback clock starts at 0:00', () {
    expect(formatClock(Duration.zero), '0:00');
    expect(formatClock(const Duration(seconds: 23)), '0:23');
    expect(formatClock(const Duration(minutes: 2, seconds: 34)), '2:34');
    expect(formatClock(const Duration(hours: 1, seconds: 5)), '1:00:05');
  });

  test('library totals read like the hero card', () {
    expect(formatTotalDuration(Duration.zero), '0m');
    expect(formatTotalDuration(const Duration(minutes: 42)), '42m');
    expect(
      formatTotalDuration(const Duration(hours: 3, minutes: 34)),
      '03h 34m',
    );
  });
}
