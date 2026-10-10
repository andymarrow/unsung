import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';

/// Heart + count. Likes pop on the emphasized curve and update optimistically.
class LikeButton extends ConsumerStatefulWidget {
  const LikeButton({required this.post, super.key});

  final Post post;

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final (liked, _) = ref.read(likesProvider.notifier).of(widget.post);
    if (!liked) {
      unawaited(HapticFeedback.lightImpact());
      if (!Motion.reduced(context)) unawaited(_pop.forward(from: 0));
    }
    final error = await ref.read(likesProvider.notifier).toggle(widget.post);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(likesProvider.select((m) => m[widget.post.id]));
    final (liked, count) = ref.read(likesProvider.notifier).of(widget.post);
    final c = context.colors;
    final scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1, end: Motion.popScale), weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: Motion.popScale, end: 1), weight: 65),
    ]).animate(CurvedAnimation(parent: _pop, curve: Motion.emphasized));

    return Semantics(
      toggled: liked,
      child: Pressable(
        onTap: () => unawaited(_toggle()),
        semanticLabel: liked ? 'Unlike, $count likes' : 'Like, $count likes',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: scale,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(liked),
                    color: liked ? c.cue : c.ink,
                    size: Sizes.icon,
                  ),
                ),
              ),
              const SizedBox(width: Space.xxs),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                      .animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Text('$count',
                    key: ValueKey(count), style: context.type.numeral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
