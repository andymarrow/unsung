import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Loads the real app fonts (and Material icons) so goldens look like the
/// device instead of the test placeholder font.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await load('Bricolage', 'assets/fonts/BricolageGrotesque.ttf');
  await load('JetBrainsMono', 'assets/fonts/JetBrainsMono.ttf');
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await load(
      'MaterialIcons',
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  }
  _loaded = true;
}
