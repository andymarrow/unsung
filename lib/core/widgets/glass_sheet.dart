import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// Modal bottom sheet on frosted glass: the page behind stays faintly
/// visible, which says "this is temporary". Glass is used only on transient
/// layers like this one, per the design brief.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface.withValues(alpha: Alphas.glass),
    // The scrim is lighter than usual so the blur has something to show.
    barrierColor: c.scrim.withValues(alpha: Alphas.glowStrong),
    clipBehavior: Clip.antiAlias,
    builder: (sheet) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: Blurs.glass, sigmaY: Blurs.glass),
      child: builder(sheet),
    ),
  );
}
