import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';

/// The index letter a title files under: A–Z, or `#` for everything else.
String scrubLetter(String title) {
  final t = title.trimLeft();
  if (t.isEmpty) return '#';
  final c = t[0].toUpperCase();
  return c.compareTo('A') >= 0 && c.compareTo('Z') <= 0 ? c : '#';
}

/// Index of the first title filed under each letter. Titles are expected
/// in alphabetical order, as the library delivers them.
Map<String, int> scrubIndex(List<String> titles) {
  final index = <String, int>{};
  for (var i = 0; i < titles.length; i++) {
    index.putIfAbsent(scrubLetter(titles[i]), () => i);
  }
  return index;
}

/// Vertical A–Z rail on the right edge of a long list. Drag or tap along it
/// to jump; the letter under the thumb shows in a cue bubble. Letters with
/// no songs are faint and jump to the next letter that has some.
class AlphabetScrub extends StatefulWidget {
  const AlphabetScrub({
    required this.index,
    required this.onJump,
    super.key,
  });

  /// First list index per letter, from [scrubIndex].
  final Map<String, int> index;

  /// Called with the list index to bring to the top.
  final ValueChanged<int> onJump;

  static const letters = [
    '#',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  State<AlphabetScrub> createState() => _AlphabetScrubState();
}

class _AlphabetScrubState extends State<AlphabetScrub> {
  String? _active;
  double _activeY = 0;

  void _at(double y, double height) {
    final slot = (y / height * AlphabetScrub.letters.length)
        .floor()
        .clamp(0, AlphabetScrub.letters.length - 1);
    final letter = AlphabetScrub.letters[slot];
    if (letter == _active) return;
    setState(() {
      _active = letter;
      _activeY = (slot + 0.5) * height / AlphabetScrub.letters.length;
    });
    unawaited(HapticFeedback.selectionClick());
    // Jump to this letter, or the next one that has songs.
    for (var i = slot; i < AlphabetScrub.letters.length; i++) {
      final target = widget.index[AlphabetScrub.letters[i]];
      if (target != null) {
        widget.onJump(target);
        return;
      }
    }
  }

  void _end() => setState(() => _active = null);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              label: 'Alphabet index. Drag to jump to a letter.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (d) => _at(d.localPosition.dy, height),
                onVerticalDragUpdate: (d) => _at(d.localPosition.dy, height),
                onVerticalDragEnd: (_) => _end(),
                onVerticalDragCancel: _end,
                onTapDown: (d) => _at(d.localPosition.dy, height),
                onTapUp: (_) => _end(),
                onTapCancel: _end,
                child: SizedBox(
                  width: Sizes.scrubRail,
                  height: height,
                  child: Column(
                    children: [
                      for (final l in AlphabetScrub.letters)
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              child: Text(
                                l,
                                style: type.label.copyWith(
                                  color: l == _active
                                      ? c.cue
                                      : widget.index.containsKey(l)
                                          ? c.inkMuted
                                          : c.inkFaint,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_active != null)
              Positioned(
                right: Sizes.scrubRail + Space.sm,
                top: _activeY - Sizes.scrubBubble / 2,
                child: IgnorePointer(
                  child: Container(
                    width: Sizes.scrubBubble,
                    height: Sizes.scrubBubble,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.cue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _active!,
                      style: type.title.copyWith(color: c.onCue),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
