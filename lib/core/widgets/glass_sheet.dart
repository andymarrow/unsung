import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';

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
    backgroundColor: c.glass,
    // A rim of light along the sheet's top edge, like the edge of a pane.
    shape: RoundedRectangleBorder(
      side: BorderSide(color: c.glassEdge),
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    // The scrim is lighter than usual so the blur has something to show.
    barrierColor: c.scrim.withValues(alpha: Alphas.glowStrong),
    clipBehavior: Clip.antiAlias,
    builder: (sheet) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: Blurs.glass, sigmaY: Blurs.glass),
      child: builder(sheet),
    ),
  );
}

/// A short yes/no on glass, for destructive or leaving actions. Resolves to
/// true only when the user confirms.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Keep',
  IconData? icon,
}) async {
  final ok = await showGlassSheet<bool>(
    context,
    builder: (sheet) {
      final type = sheet.type;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg + MediaQuery.paddingOf(sheet).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: type.heading),
            const SizedBox(height: Space.xs),
            Text(message, style: type.bodyMuted),
            const SizedBox(height: Space.lg),
            CueButton(
              label: confirmLabel,
              icon: icon,
              expand: true,
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: Space.sm),
            QuietButton(
              label: cancelLabel,
              expand: true,
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      );
    },
  );
  return ok ?? false;
}
