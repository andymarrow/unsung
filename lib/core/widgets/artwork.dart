import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/theme/typography.dart';

/// Song artwork, or a typographic "tape label" cover when the file has none.
class Artwork extends StatelessWidget {
  const Artwork({
    required this.title,
    required this.size,
    this.bytes,
    this.radius = Radii.card,
    super.key,
  });

  final String title;
  final double size;
  final Uint8List? bytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: image != null && image.isNotEmpty
            ? Image.memory(
                image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                semanticLabel: 'Cover art for $title',
                errorBuilder: (_, __, ___) =>
                    _TypeCover(title: title, size: size),
              )
            : ColoredBox(
                color: c.raised,
                child: _TypeCover(title: title, size: size),
              ),
      ),
    );
  }
}

class _TypeCover extends StatelessWidget {
  const _TypeCover({required this.title, required this.size});

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w.characters.first).join();
    return Semantics(
      label: 'No cover art for $title',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.raised),
          Positioned(
            left: 0,
            right: 0,
            bottom: size * 0.18,
            height: size * 0.06,
            child: ColoredBox(color: c.hairline),
          ),
          Center(
            child: Text(
              initials.isEmpty ? '♪' : initials.toUpperCase(),
              style: TextStyle(
                fontFamily: Fonts.display,
                fontSize: size * 0.36,
                height: 1,
                color: c.ink,
                fontWeight: FontWeight.w800,
                fontVariations: Axes.display(weight: 800, width: 75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
