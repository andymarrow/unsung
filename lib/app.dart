import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/router/app_router.dart';
import 'package:unsung/core/theme/app_theme.dart';

class UnsungApp extends ConsumerWidget {
  const UnsungApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Unsung',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Dark is the primary experience; ThemeMode.system (default) lets the
      // device setting win.
      routerConfig: ref.watch(routerProvider),
    );
  }
}
