import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/theme/typography.dart';
import 'package:unsung/features/social/domain/models.dart';

/// Monogram avatar: initials on raised, with a cue ring for emphasis.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.profile,
    this.size = Sizes.avatarSm,
    this.ring = false,
    super.key,
  });

  final Profile profile;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '${profile.name} avatar',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.raised,
          shape: BoxShape.circle,
          border: ring ? Border.all(color: c.cue, width: Sizes.stroke) : null,
        ),
        child: Text(
          profile.initials,
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: size * 0.4,
            height: 1,
            color: c.ink,
            fontWeight: FontWeight.w800,
            fontVariations: Axes.display(weight: 780, width: 80),
          ),
        ),
      ),
    );
  }
}
