import 'package:flutter/material.dart';
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

/// Skeleton block that breathes between surface and raised.
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.signature * 2,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              c.surface,
              c.raised,
              Motion.standard.transform(_c.value),
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
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
