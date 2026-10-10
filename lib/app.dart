import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/platform/share_intake.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/router/app_router.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/features/links/domain/link.dart';
import 'package:unsung/features/links/presentation/link_sheet.dart';

class UnsungApp extends ConsumerStatefulWidget {
  const UnsungApp({super.key});

  @override
  ConsumerState<UnsungApp> createState() => _UnsungAppState();
}

class _UnsungAppState extends ConsumerState<UnsungApp> {
  StreamSubscription<String>? _shares;

  @override
  void initState() {
    super.initState();
    final intake = ref.read(shareIntakeProvider);
    _shares = intake.shared.listen(_openShared);
    unawaited(intake.initialText().then((t) {
      if (t != null) _openShared(t);
    }));
  }

  @override
  void dispose() {
    unawaited(_shares?.cancel());
    super.dispose();
  }

  /// A YouTube link shared from another app opens "From a link", once the
  /// app is past onboarding and has a navigator.
  void _openShared(String text) {
    if (youTubeIdFrom(text) == null || !ref.read(onboardedProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        unawaited(showLinkSheet(context, initialText: text));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
