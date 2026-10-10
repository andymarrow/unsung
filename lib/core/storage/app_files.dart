import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// App-private folders and small JSON documents (indexes, metadata).
class AppFiles {
  AppFiles(this.root);

  final Directory root;

  static Future<AppFiles> open() async =>
      AppFiles(await getApplicationDocumentsDirectory());

  Directory dir(String name) {
    final d = Directory('${root.path}/$name');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  String path(String folder, String file) => '${dir(folder).path}/$file';

  Future<Map<String, Object?>> readJson(String folder, String file) async {
    final f = File(path(folder, file));
    if (!f.existsSync()) return {};
    try {
      final decoded = jsonDecode(await f.readAsString());
      return decoded is Map<String, Object?> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  /// Writes atomically (temp file + rename) so a crash never corrupts an index.
  Future<void> writeJson(
    String folder,
    String file,
    Map<String, Object?> data,
  ) async {
    final target = path(folder, file);
    final tmp = File('$target.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(target);
  }
}

/// Overridden in main() with the opened instance.
final appFilesProvider = Provider<AppFiles>(
  (ref) => throw UnimplementedError('appFilesProvider must be overridden'),
);
