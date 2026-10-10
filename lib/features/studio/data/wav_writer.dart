import 'dart:io';
import 'dart:typed_data';

/// Streams mono PCM16 to a WAV file and patches the header on close.
class WavWriter {
  WavWriter._(this._file, this.sampleRate);

  static Future<WavWriter> create(String path, {int sampleRate = 44100}) async {
    final f = await File(path).open(mode: FileMode.write);
    await f.writeFrom(Uint8List(44));
    return WavWriter._(f, sampleRate);
  }

  final RandomAccessFile _file;
  final int sampleRate;
  int _bytes = 0;
  Future<void> _pending = Future.value();

  int get samples => _bytes ~/ 2;

  Duration get duration =>
      Duration(microseconds: samples * 1000000 ~/ sampleRate);

  /// Appends PCM16LE bytes. Writes are serialised.
  void add(Uint8List pcm) {
    _bytes += pcm.length;
    _pending = _pending.then((_) => _file.writeFrom(pcm));
  }

  Future<void> close() async {
    await _pending;
    final h = ByteData(44)
      ..setUint32(0, 0x52494646) // RIFF
      ..setUint32(4, 36 + _bytes, Endian.little)
      ..setUint32(8, 0x57415645) // WAVE
      ..setUint32(12, 0x666d7420) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // data
      ..setUint32(40, _bytes, Endian.little);
    await _file.setPosition(0);
    await _file.writeFrom(h.buffer.asUint8List());
    await _file.close();
  }
}
