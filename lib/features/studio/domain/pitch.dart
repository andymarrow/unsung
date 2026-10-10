import 'dart:math' as math;
import 'dart:typed_data';

/// Real-time monophonic pitch tracking (YIN, de Cheveigné & Kawahara 2002).
///
/// Feed 16-bit mono PCM with [add]; every [hop] samples a new estimate is
/// produced. Input is decimated by 2 before analysis to halve the cost.
class PitchTracker {
  PitchTracker({
    this.sampleRate = 44100,
    this.window = 2048,
    this.hop = 1024,
    this.minHz = 70,
    this.maxHz = 1000,
    this.threshold = 0.15,
    this.silenceRms = 0.012,
  })  : _ring = Float64List(window),
        _half = Float64List(window ~/ 2);

  final int sampleRate;
  final int window;
  final int hop;
  final double minHz;
  final double maxHz;
  final double threshold;

  /// Below this RMS the frame is treated as silence.
  final double silenceRms;

  final Float64List _ring;
  final Float64List _half;
  int _filled = 0;
  int _write = 0;
  int _sinceHop = 0;

  /// Adds little-endian PCM16 bytes; returns any new estimates (Hz, or null
  /// for unvoiced frames), oldest first.
  List<double?> add(Uint8List pcm) {
    final out = <double?>[];
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i + 1 < pcm.length; i += 2) {
      final s = data.getInt16(i, Endian.little) / 32768.0;
      // Circular buffer: _write is the oldest sample once full.
      _ring[_write] = s;
      _write = (_write + 1) % window;
      if (_filled < window) _filled++;
      if (_filled == window && ++_sinceHop >= hop) {
        _sinceHop = 0;
        out.add(_estimate());
      }
    }
    return out;
  }

  double? _estimate() {
    var energy = 0.0;
    for (var i = 0; i < _half.length; i++) {
      final a = _ring[(_write + 2 * i) % window];
      final b = _ring[(_write + 2 * i + 1) % window];
      final v = (a + b) * 0.5;
      _half[i] = v;
      energy += v * v;
    }
    if (math.sqrt(energy / _half.length) < silenceRms) return null;
    return yin(_half, sampleRate / 2, minHz: minHz, maxHz: maxHz, threshold: threshold);
  }

  /// YIN on a single buffer. Returns Hz or null.
  static double? yin(
    Float64List x,
    double rate, {
    double minHz = 70,
    double maxHz = 1000,
    double threshold = 0.15,
  }) {
    final tauMin = math.max(2, (rate / maxHz).floor());
    final tauMax = math.min(x.length ~/ 2, (rate / minHz).ceil());
    if (tauMax <= tauMin + 2) return null;
    final w = x.length - tauMax;
    final d = Float64List(tauMax + 1);
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var j = 0; j < w; j++) {
        final diff = x[j] - x[j + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }
    // Cumulative mean normalised difference.
    var running = 0.0;
    d[0] = 1;
    for (var tau = 1; tau <= tauMax; tau++) {
      running += d[tau];
      d[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }
    var tau = tauMin;
    var found = -1;
    while (tau < tauMax) {
      if (d[tau] < threshold) {
        while (tau + 1 < tauMax && d[tau + 1] < d[tau]) {
          tau++;
        }
        found = tau;
        break;
      }
      tau++;
    }
    if (found < 0) return null;
    // Parabolic interpolation around the minimum.
    final a = d[found - 1];
    final b = d[found];
    final c = d[found + 1];
    final denom = a + c - 2 * b;
    final shift = denom == 0 ? 0.0 : (a - c) / (2 * denom);
    return rate / (found + shift);
  }
}

/// Fractional MIDI note number for [hz] (A4 = 69).
double hzToMidi(double hz) => 69 + 12 * (math.log(hz / 440) / math.ln2);

/// Distance in cents from the nearest equal-tempered note.
double centsOff(double midi) => (midi - midi.roundToDouble()) * 100;

const _names = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];

/// "A4", "C♯3".
String noteName(double midi) {
  final n = midi.round();
  return '${_names[n % 12]}${(n ~/ 12) - 1}';
}

/// How a take went, for the review screen and the profile.
class SingingStats {
  int voiced = 0;
  int centred = 0;
  int frames = 0;

  /// Within this many cents of a note counts as centred.
  static const tolerance = 25.0;

  void add(double? hz) {
    frames++;
    if (hz == null) return;
    voiced++;
    if (centsOff(hzToMidi(hz)).abs() <= tolerance) centred++;
  }

  /// Share of sung frames that sat on a note.
  double get inTune => voiced == 0 ? 0 : centred / voiced;

  /// Share of the take with singing in it.
  double get presence => frames == 0 ? 0 : voiced / frames;
}
