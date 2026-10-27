/// A line of lyrics and the moment it should light up.
class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

/// Lyrics for one track, either timed (LRC) or plain text.
class Lyrics {
  const Lyrics.timed(this.lines) : isTimed = true, text = null;
  const Lyrics.literal(String this.text) : lines = const [], isTimed = false;

  final List<LyricLine> lines;
  final bool isTimed;
  final String? text;

  static final _timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  static final _metadata = RegExp(r'^\[(ar|ti|al|by|re|ve|length):');
  static final _offset = RegExp(r'^\[offset:\s*([+-]?\d+)\]');

  /// Parses the text stored in a tag. Timestamped lines become timed lyrics;
  /// anything else is shown as plain text.
  static Lyrics? parse(String raw) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.trim().isEmpty) return null;

    var offset = Duration.zero;
    for (final line in text.split('\n')) {
      final match = _offset.firstMatch(line.trim().toLowerCase());
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '');
        if (value != null) offset = Duration(milliseconds: value);
      }
    }

    final entries = <LyricLine>[];
    final plainLines = <String>[];
    var sawTimestamp = false;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (!sawTimestamp) plainLines.add('');
        continue;
      }
      if (_metadata.hasMatch(trimmed) ||
          _offset.hasMatch(trimmed.toLowerCase())) {
        continue;
      }

      final stamps = _timestamp.allMatches(trimmed).toList();
      if (stamps.isEmpty) {
        if (!sawTimestamp) plainLines.add(trimmed);
        continue;
      }

      sawTimestamp = true;
      final body = trimmed.substring(stamps.last.end).trim();
      if (body.isEmpty) continue;
      for (final stamp in stamps) {
        final minutes = int.parse(stamp.group(1)!);
        final seconds = int.parse(stamp.group(2)!);
        final fractionText = stamp.group(3);
        var millis = 0;
        if (fractionText != null) {
          millis = switch (fractionText.length) {
            1 => int.parse(fractionText) * 100,
            2 => int.parse(fractionText) * 10,
            _ => int.parse(fractionText.substring(0, 3)),
          };
        }
        final time =
            Duration(minutes: minutes, seconds: seconds, milliseconds: millis) +
            offset;
        entries.add(
          LyricLine(time: time.isNegative ? Duration.zero : time, text: body),
        );
      }
    }

    if (entries.isNotEmpty) {
      entries.sort((a, b) => a.time.compareTo(b.time));
      return Lyrics.timed(entries);
    }

    final plain = plainLines.join('\n').trim();
    if (plain.isEmpty) return null;
    return Lyrics.literal(plain);
  }

  /// Serialises the lyrics back to LRC so downloaded lyrics can be cached on
  /// the phone and parsed again on the next launch.
  String toLrc() {
    if (!isTimed) return text ?? '';
    final buffer = StringBuffer();
    for (final line in lines) {
      final minutes = line.time.inMinutes.toString().padLeft(2, '0');
      final seconds = (line.time.inSeconds % 60).toString().padLeft(2, '0');
      final centis = ((line.time.inMilliseconds % 1000) ~/ 10)
          .toString()
          .padLeft(2, '0');
      buffer.writeln('[$minutes:$seconds.$centis]${line.text}');
    }
    return buffer.toString().trimRight();
  }

  /// Index of the line that should be highlighted at [position], or -1 when
  /// playback is before the first line.
  int indexAt(Duration position) {
    if (!isTimed || lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }
}
