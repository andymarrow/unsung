import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/theme/typography.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/features/lyrics/domain/lyrics.dart';

/// Signature moment 2: "Breathing lyrics".
///
/// The active line fills word by word with cue in time with the music, and
/// each word physically opens (variable-font width 82 → 100, weight up) the
/// moment it is sung. The upcoming line is larger and brighter than past
/// lines, which fade to faint. With reduce-motion on, only colour changes.
class LyricsView extends StatefulWidget {
  const LyricsView({
    required this.lyrics,
    required this.position,
    this.offset = Duration.zero,
    this.onAddLyrics,
    this.topInset = Space.lg,
    super.key,
  });

  final Lyrics lyrics;

  /// Polled every frame. Use an interpolating clock such as
  /// `AudioPlayer.position` so the fill is smooth between updates.
  final Duration Function() position;

  /// User nudge for lyric timing; positive shows lyrics later.
  final Duration offset;

  final VoidCallback? onAddLyrics;
  final double topInset;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _now = ValueNotifier<Duration>(Duration.zero);
  final _active = ValueNotifier<int>(-1);
  final _scroll = ScrollController();
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _rekey();
    _ticker.start();
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (!identical(old.lyrics, widget.lyrics)) _rekey();
  }

  void _rekey() {
    _keys = List.generate(widget.lyrics.lines.length, (_) => GlobalKey());
    _active.value = -1;
  }

  void _tick(Duration _) {
    final t = widget.position() - widget.offset;
    _now.value = t;
    final i = widget.lyrics.indexAt(t);
    if (i != _active.value) {
      _active.value = i;
      _follow(i);
    }
  }

  void _follow(int i, {bool retried = false}) {
    if (i < 0 || i >= _keys.length || !_scroll.hasClients) return;
    final ctx = _keys[i].currentContext;
    if (ctx == null) {
      // Not built yet (e.g. after a seek): jump near it, then align.
      if (retried) return;
      final p = _scroll.position;
      _scroll.jumpTo((i * _approxLineExtent).clamp(0, p.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _follow(i, retried: true),
      );
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.28,
        duration: Motion.of(context, retried ? Duration.zero : Motion.slow),
        curve: Motion.decelerate,
      ),
    );
  }

  static const _approxLineExtent = Space.xxxl;

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    _active.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    if (lyrics.isEmpty) {
      return EmptyState(
        kicker: 'No lyrics yet',
        title: 'Sing it from memory?',
        message:
            "We couldn't find lyrics for this song. Paste them in and they'll be saved with it. LRC timestamps make them follow the music.",
        icon: Icons.lyrics_outlined,
        actionLabel: widget.onAddLyrics == null ? null : 'Add lyrics',
        onAction: widget.onAddLyrics,
      );
    }
    final lines = lyrics.lines;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        widget.topInset,
        Space.gutter,
        MediaQuery.sizeOf(context).height * 0.5,
      ),
      itemCount: lines.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Row(
              children: [
                if (!lyrics.synced) ...[
                  const TapeLabel('Unsynced', tone: TapeTone.outline),
                  const SizedBox(width: Space.xs),
                ],
                if (lyrics.source != null)
                  TapeLabel('Lyrics · ${lyrics.source}',
                      tone: TapeTone.outline),
                const Spacer(),
                if (lyrics.synced)
                  _Intro(lyrics: lyrics, now: _now, active: _active),
              ],
            ),
          );
        }
        final index = i - 1;
        return Padding(
          key: _keys[index],
          padding: const EdgeInsets.only(bottom: Space.md),
          child: lyrics.synced
              ? ValueListenableBuilder<int>(
                  valueListenable: _active,
                  builder: (context, active, _) => _SyncedLine(
                    line: lines[index],
                    slot: index - active,
                    now: _now,
                  ),
                )
              : Text(lines[index].text, style: context.type.lyricNext),
        );
      },
    );
  }
}

/// "♪ 0:12" countdown until the first line.
class _Intro extends StatelessWidget {
  const _Intro({required this.lyrics, required this.now, required this.active});

  final Lyrics lyrics;
  final ValueNotifier<Duration> now;
  final ValueNotifier<int> active;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: active,
      builder: (context, a, _) {
        if (a >= 0 || lyrics.lines.isEmpty) return const SizedBox.shrink();
        return ValueListenableBuilder<Duration>(
          valueListenable: now,
          builder: (context, t, _) {
            final left = lyrics.lines.first.start - t;
            final secs = left.inSeconds.clamp(0, 5999);
            return TapeLabel(
              '♪ in ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
              tone: TapeTone.cue,
            );
          },
        );
      },
    );
  }
}

class _SyncedLine extends StatelessWidget {
  const _SyncedLine(
      {required this.line, required this.slot, required this.now});

  final LyricLine line;

  /// 0 = active, negative = sung, 1 = next, 2+ = later.
  final int slot;
  final ValueNotifier<Duration> now;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final d = Motion.of(context, Motion.base);

    if (line.isInstrumentalBreak) {
      return AnimatedOpacity(
        duration: d,
        opacity: slot == 0 ? 1 : 0.4,
        child: Text('♪', style: type.lyricNext.copyWith(color: c.inkFaint)),
      );
    }

    if (slot == 0) {
      return ValueListenableBuilder<Duration>(
        valueListenable: now,
        builder: (context, t, _) => _ActiveLine(line: line, now: t),
      );
    }

    final style = switch (slot) {
      < 0 => type.lyricPast,
      1 => type.lyricNext,
      _ => type.lyricNext.copyWith(color: c.inkMuted),
    };
    return AnimatedDefaultTextStyle(
      duration: d,
      curve: Motion.standard,
      style: style,
      child: Text(line.text),
    );
  }
}

class _ActiveLine extends StatelessWidget {
  const _ActiveLine({required this.line, required this.now});

  final LyricLine line;
  final Duration now;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final reduced = Motion.reduced(context);
    final space = type.lyricActive.fontSize! * 0.28;
    return Semantics(
      liveRegion: true,
      label: line.text,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: space,
          runSpacing: Space.xxs,
          children: [
            for (var i = 0; i < line.words.length; i++)
              _Word(
                text: line.words[i].text,
                fill: line.wordFill(i, now),
                base: type.lyricActive,
                sung: c.cue,
                unsung: c.ink,
                animate: !reduced,
              ),
          ],
        ),
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.text,
    required this.fill,
    required this.base,
    required this.sung,
    required this.unsung,
    required this.animate,
  });

  final String text;
  final double fill;
  final TextStyle base;
  final Color sung;
  final Color unsung;
  final bool animate;

  static const _closedWidth = 82.0;
  static const _openWidth = 100.0;
  static const _closedWeight = 650.0;
  static const _openWeight = 780.0;

  @override
  Widget build(BuildContext context) {
    final opened = fill > 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: opened ? 1 : 0),
      duration: animate ? Motion.base : Duration.zero,
      curve: Motion.emphasized,
      builder: (context, open, _) {
        final width = _closedWidth + (_openWidth - _closedWidth) * open;
        final weight = _closedWeight + (_openWeight - _closedWeight) * open;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [sung, sung, unsung, unsung],
            stops: [0, fill, fill, 1],
          ).createShader(bounds),
          child: Text(
            text,
            style: base.copyWith(
              fontWeight: Axes.nearestWeight(weight),
              fontVariations: Axes.display(
                weight: weight,
                width: width,
                opticalSize: base.fontSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
