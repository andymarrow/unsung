import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';

/// Designed empty state: a mono kicker, a big line, one sentence, one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.kicker,
    required this.title,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    super.key,
  });

  final String kicker;
  final String title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A quieter second way forward, under the main action.
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: Sizes.tap + Space.md,
                  height: Sizes.tap + Space.md,
                  decoration: BoxDecoration(
                    color: c.raised,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: c.cue, size: Sizes.icon),
                ),
                const SizedBox(height: Space.lg),
              ],
              Text(kicker.toUpperCase(), style: context.type.labelMuted),
              const SizedBox(height: Space.xs),
              Text(title, style: context.type.title),
              const SizedBox(height: Space.sm),
              Text(message, style: context.type.bodyMuted),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Space.lg),
                CueButton(label: actionLabel!, onTap: onAction),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: Space.sm),
                QuietButton(
                  label: secondaryLabel!,
                  icon: secondaryIcon,
                  onTap: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with retry. Offline failures get their own copy and icon.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.failure, this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = failure is OfflineFailure;
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      kicker: offline ? 'Offline' : 'Hit a wrong note',
      title: offline ? 'No connection' : "That didn't work",
      message: failure.message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Skeleton block with a soft band of light sweeping across it. Every
/// skeleton reads the same clock and places the band in screen space, so a
/// whole loading screen shimmers as one sweep instead of blinking piecemeal.
class Skeleton extends StatefulWidget {
  const Skeleton({
    this.width,
    this.height = Space.md,
    this.radius = Radii.chip,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = Motion.reduced(context);
    if (still && _ticker.isActive) {
      _ticker.stop();
    } else if (!still && !_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 0..1 through the current sweep, shared by every skeleton.
  static double get _phase {
    final period = Motion.shimmer.inMicroseconds;
    return (DateTime.now().microsecondsSinceEpoch % period) / period;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final screen = MediaQuery.sizeOf(context).width;
    final box = context.findRenderObject();
    final left = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero).dx
        : 0.0;
    // Band centre travels from off-screen left to off-screen right.
    final band = screen * Sizes.progressSegment;
    final x = -band + (screen + 2 * band) * Motion.standard.transform(_phase);
    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: c.raised,
          gradient: LinearGradient(
            colors: [
              c.raised,
              Color.alphaBlend(c.glassSheen, c.raised),
              c.raised,
            ],
            transform: _BandAt(x - left, band),
          ),
        ),
      ),
    );
  }
}

/// Places a 3-stop gradient as a band of [width] centred at [x] (pixels,
/// in the painted box's own coordinates).
class _BandAt extends GradientTransform {
  const _BandAt(this.x, this.width);

  final double x;
  final double width;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // The gradient spans [bounds.left, bounds.right]; scale it to the band
    // width, then move it so its middle sits at x.
    final scale = width / bounds.width;
    return Matrix4.translationValues(x - width / 2 - bounds.left * scale, 0, 0)
      ..multiply(Matrix4.diagonal3Values(scale, 1, 1));
  }
}

/// A list of row skeletons matching the song/take row layout.
class RowSkeletonList extends StatelessWidget {
  const RowSkeletonList({this.count = 8, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.md,
      ),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: Space.md),
      itemBuilder: (_, i) => Row(
        children: [
          const Skeleton(
            width: Sizes.artworkRow,
            height: Sizes.artworkRow,
            radius: Radii.card,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.5 + (i % 3) * 0.15,
                  child: const Skeleton(),
                ),
                const SizedBox(height: Space.xs),
                const FractionallySizedBox(
                  widthFactor: 0.35,
                  child: Skeleton(height: Space.sm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin banner shown at the top of online-only screens while offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: c.raised,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: Sizes.iconSm, color: c.inkMuted),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              "OFFLINE — SHOWING WHAT'S SAVED",
              style: context.type.labelMuted,
            ),
          ),
        ],
      ),
    );
  }
}
