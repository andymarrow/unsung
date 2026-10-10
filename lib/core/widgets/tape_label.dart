import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

enum TapeTone { neutral, cue, outline }

/// Square-cornered mono tag, like a label on a tape reel: READY, PRIVATE, 3:42.
class TapeLabel extends StatelessWidget {
  const TapeLabel(this.text, {this.tone = TapeTone.neutral, this.icon, super.key});

  final String text;
  final TapeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, border) = switch (tone) {
      TapeTone.neutral => (c.raised, c.inkMuted, Colors.transparent),
      TapeTone.cue => (c.cue, c.onCue, Colors.transparent),
      TapeTone.outline => (Colors.transparent, c.inkMuted, c.hairline),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(Radii.tape),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.tapeX,
          vertical: Space.tapeY,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: Sizes.iconXs, color: fg),
              const SizedBox(width: Space.xxs),
            ],
            Text(
              text.toUpperCase(),
              style: context.type.label.copyWith(color: fg, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}
