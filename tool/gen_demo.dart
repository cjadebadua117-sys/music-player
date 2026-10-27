// Generates the small, royalty-free demo tracks that ship inside the app so it
// has something to play on first launch.
//
// Run from the project root with:  dart run tool/gen_demo.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _rate = 22050;

void main(List<String> args) {
  final out = Directory(args.isNotEmpty ? args.first : 'assets/demo');
  out.createSync(recursive: true);

  _render(out, 'warm_up.wav', 8, _warmUp);
  _render(out, 'pulse.wav', 8, _pulse);
  _render(out, 'drift.wav', 10, _drift);

  for (final f in out.listSync().whereType<File>()) {
    final kb = (f.lengthSync() / 1024).toStringAsFixed(0);
    stdout.writeln('${f.path}  $kb KB');
  }
}

/// Semitone offset from A4 (440 Hz) to a frequency.
double _hz(double semitones) => 440 * pow(2, semitones / 12).toDouble();

/// Short attack, long release, so notes never click.
double _pluck(double t, double life) {
  const attack = 0.012;
  if (t < 0 || t > life) return 0;
  final a = t < attack ? t / attack : 1.0;
  final decay = exp(-3.2 * (t / life));
  return a * decay * (1 - t / life);
}

double _clip(double x) => x < -1 ? -1 : (x > 1 ? 1 : x);

double _sine(double hz, double t) => sin(2 * pi * hz * t);

double _fade(double t, double total) {
  const edge = 0.35;
  if (t < edge) return t / edge;
  if (t > total - edge) return (total - t) / edge;
  return 1;
}

// ---------------------------------------------------------------------------
// Track 1 - slow, warm chord pad.
// ---------------------------------------------------------------------------
const _progression = <List<double>>[
  [0, 4, 7], // C
  [-3, 0, 4], // Am
  [-7, -4, 0], // F
  [-5, -1, 2], // G
];

double _warmUp(double t) {
  const total = 8.0;
  final step = (t / 2.0).floor().clamp(0, 3);
  final local = t - step * 2.0;
  final chord = _progression[step];
  var v = 0.0;
  for (final note in chord) {
    final hz = _hz(note - 9); // C4 based
    v += 0.30 * _sine(hz, t);
    v += 0.10 * _sine(hz * 1.005, t); // gentle detune for warmth
    v += 0.06 * _sine(hz * 2, t);
  }
  // Re-attack each chord so the progression is audible.
  final env = _pluck(local, 2.0) * _fade(t, total);
  return _clip(v * env);
}

// ---------------------------------------------------------------------------
// Track 2 - plucky arpeggio with a bass note underneath.
// ---------------------------------------------------------------------------
double _pulse(double t) {
  const total = 8.0;
  const step = 0.25; // 16ths at 120 BPM
  final index = (t / step).floor();
  final local = t - index * step;
  final chord = _progression[(index ~/ 8) % _progression.length];
  final note = chord[index % chord.length];
  final octave = (index % 8) < 4 ? 0.0 : 12.0;
  final hz = _hz(note - 9 + 12 + octave);
  var v = 0.42 * _sine(hz, local) * _pluck(local, step * 1.6);

  final bassIndex = (t / 2.0).floor();
  final bassLocal = t - bassIndex * 2.0;
  final bass = _progression[bassIndex % _progression.length].first;
  v += 0.45 * _sine(_hz(bass - 21), bassLocal) * _pluck(bassLocal, 2.0);
  return _clip(v * _fade(t, total));
}

// ---------------------------------------------------------------------------
// Track 3 - drifting pad that glides between two chords.
// ---------------------------------------------------------------------------
const _driftA = [0, 4, 7, 11];
const _driftB = [-3, 2, 5, 9];

double _drift(double t) {
  const total = 10.0;
  final mix = (1 - cos(2 * pi * t / total)) / 2; // 0 -> 1 -> 0
  var v = 0.0;
  for (var i = 0; i < _driftA.length; i++) {
    final note = _driftA[i] * (1 - mix) + _driftB[i] * mix;
    final hz = _hz(note - 9);
    final lfo = 0.85 + 0.15 * sin(2 * pi * (0.11 + i * 0.03) * t);
    v += 0.24 * _sine(hz, t) * lfo;
    v += 0.08 * _sine(hz * 1.5, t) * lfo;
  }
  return _clip(v * _fade(t, total));
}

// ---------------------------------------------------------------------------
// Rendering + WAV writing.
// ---------------------------------------------------------------------------
void _render(Directory dir, String name, int seconds, double Function(double) fn) {
  final count = (_rate * seconds);
  final samples = Float64List(count);
  for (var i = 0; i < count; i++) {
    samples[i] = fn(i / _rate);
  }
  _writeWav(File('${dir.path}/$name'), samples);
}

void _writeWav(File file, Float64List samples) {
  const channels = 1;
  const bits = 16;
  final dataLength = samples.length * 2;
  final b = BytesBuilder();

  void ascii(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + dataLength);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(_rate);
  u32(_rate * channels * bits ~/ 8);
  u16(channels * bits ~/ 8);
  u16(bits);
  ascii('data');
  u32(dataLength);

  final pcm = Uint8List(dataLength);
  final view = pcm.buffer.asByteData();
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 0.92 * 32767).round().clamp(-32768, 32767);
    view.setInt16(i * 2, v, Endian.little);
  }
  b.add(pcm);

  file.writeAsBytesSync(b.takeBytes());
}
