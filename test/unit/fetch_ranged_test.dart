import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:unsung/core/result.dart';
import 'package:unsung/features/links/data/link_sources.dart';

void main() {
  late Directory dir;
  final data = List<int>.generate(5000, (i) => i % 251);

  setUp(() => dir = Directory.systemTemp.createTempSync('ranged'));
  tearDown(() => dir.deleteSync(recursive: true));

  DateTime later() => DateTime.now().add(const Duration(minutes: 1));

  /// Serves [data] for the range in the query parameter or Range header.
  http.Client server({int status = 206, bool stall = false}) =>
      _Fake((request) {
        final q = request.url.queryParameters['range'];
        final h = request.headers['Range']?.replaceFirst('bytes=', '');
        final parts = (q ?? h)!.split('-').map(int.parse).toList();
        final body = data.sublist(parts[0], parts[1] + 1);
        final stream = stall
            ? StreamController<List<int>>().stream // never sends
            : Stream.value(body);
        return http.StreamedResponse(stream, status);
      });

  test('joins ranged chunks into the whole file', () async {
    final out = File('${dir.path}/a.m4a');
    final progress = <double?>[];
    await fetchRanged(
      server(),
      Uri.parse('https://example.com/v?c=WEB'),
      data.length,
      out,
      chunk: 1024,
      onProgress: progress.add,
      cancelled: () => false,
      deadline: later(),
    );
    expect(out.readAsBytesSync(), data);
    expect(progress.last, 1);
  });

  test('android streams use a Range header', () async {
    final out = File('${dir.path}/b.m4a');
    await fetchRanged(
      server(),
      Uri.parse('https://example.com/v?c=ANDROID_VR'),
      data.length,
      out,
      chunk: 2048,
      onProgress: (_) {},
      cancelled: () => false,
      deadline: later(),
    );
    expect(out.readAsBytesSync(), data);
  });

  test('a refused stream fails instead of retrying forever', () async {
    expect(
      fetchRanged(
        server(status: 403),
        Uri.parse('https://example.com/v?c=WEB'),
        data.length,
        File('${dir.path}/c.m4a'),
        onProgress: (_) {},
        cancelled: () => false,
        deadline: later(),
      ),
      throwsA(isA<StreamStalled>()),
    );
  });

  test('a stream that stops sending times out', () async {
    expect(
      fetchRanged(
        server(stall: true),
        Uri.parse('https://example.com/v?c=WEB'),
        data.length,
        File('${dir.path}/d.m4a'),
        onProgress: (_) {},
        cancelled: () => false,
        deadline: later(),
        idle: const Duration(milliseconds: 50),
      ),
      throwsA(isA<StreamStalled>()),
    );
  });

  test('cancelling stops the download', () async {
    expect(
      fetchRanged(
        server(),
        Uri.parse('https://example.com/v?c=WEB'),
        data.length,
        File('${dir.path}/e.m4a'),
        chunk: 512,
        onProgress: (_) {},
        cancelled: () => true,
        deadline: later(),
      ),
      throwsA(isA<CancelledFailure>()),
    );
  });
}

class _Fake extends http.BaseClient {
  _Fake(this._handle);

  final http.StreamedResponse Function(http.BaseRequest) _handle;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      _handle(request);
}
