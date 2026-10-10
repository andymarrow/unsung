import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/features/studio/domain/pitch.dart';

Uint8List sine(double hz, {int samples = 8192, int rate = 44100, double amp = 0.5}) {
  final b = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final v = (math.sin(2 * math.pi * hz * i / rate) * amp * 32767).round();
    b.setInt16(i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  test('tracks a 220 Hz tone', () {
    final t = PitchTracker();
    final estimates = t.add(sine(220)).whereType<double>().toList();
    expect(estimates, isNotEmpty);
    expect(estimates.last, closeTo(220, 3));
  });

  test('silence is unvoiced', () {
    final t = PitchTracker();
    final estimates = t.add(Uint8List(8192 * 2));
    expect(estimates, isNotEmpty);
    expect(estimates.every((e) => e == null), isTrue);
  });

  test('note helpers', () {
    expect(hzToMidi(440), closeTo(69, 1e-9));
    expect(noteName(69), 'A4');
    expect(noteName(60), 'C4');
    expect(centsOff(69.1), closeTo(10, 1e-6));
  });

  test('stats count centred frames', () {
    final s = SingingStats()
      ..add(440)
      ..add(452) // ~47 cents sharp
      ..add(null);
    expect(s.presence, closeTo(2 / 3, 1e-9));
    expect(s.inTune, closeTo(0.5, 1e-9));
  });
}
