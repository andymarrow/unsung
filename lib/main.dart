import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unsung/app.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/storage/app_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (prefs, files) = await (
    SharedPreferences.getInstance(),
    AppFiles.open(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        appFilesProvider.overrideWithValue(files),
      ],
      child: const UnsungApp(),
    ),
  );
}
