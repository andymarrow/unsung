import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/theme/typography.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(UnsungColors.dark, Brightness.dark);
  static ThemeData get light => _build(UnsungColors.light, Brightness.light);

  static ThemeData _build(UnsungColors c, Brightness brightness) {
    final type = UnsungType.from(c);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.cue,
      onPrimary: c.onCue,
      secondary: c.ink,
      onSecondary: c.stage,
      error: c.cue,
      onError: c.onCue,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.raised,
      outline: c.hairline,
    );
    final overlay = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.stage,
      canvasColor: c.stage,
      fontFamily: Fonts.display,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: c.hairline,
      extensions: [c, type],
      textTheme: TextTheme(
        displayLarge: type.hero,
        headlineMedium: type.title,
        titleLarge: type.heading,
        bodyLarge: type.body,
        bodyMedium: type.body,
        labelLarge: type.label,
        labelMedium: type.label,
        labelSmall: type.labelMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.stage,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.heading,
        systemOverlayStyle: overlay.copyWith(
          statusBarColor: Colors.transparent,
        ),
      ),
      iconTheme: IconThemeData(color: c.ink, size: Sizes.icon),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBarrierColor: c.scrim,
        showDragHandle: true,
        dragHandleColor: c.inkFaint,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: type.body.copyWith(color: c.stage),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.cue,
        inactiveTrackColor: c.raised,
        thumbColor: c.ink,
        overlayColor: c.cue.withValues(alpha: Alphas.ghost),
        trackHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onCue : c.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.cue : c.raised,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.raised,
        hintStyle: type.bodyMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
          borderSide: BorderSide(color: c.cue, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.cue,
        selectionColor: c.cue.withValues(alpha: Alphas.glow),
        selectionHandleColor: c.cue,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.cue,
        linearTrackColor: c.raised,
        circularTrackColor: c.raised,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Push transition: the new page rises 4% and fades in on the decelerate
/// curve while the old page dims. Calm, and lets the stage colour carry.
class _FadeThroughBuilder extends PageTransitionsBuilder {
  const _FadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Motion.decelerate);
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.standard,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.6).animate(exit),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

extension ThemeX on BuildContext {
  UnsungColors get colors => Theme.of(this).extension<UnsungColors>()!;
  UnsungType get type => Theme.of(this).extension<UnsungType>()!;
}
