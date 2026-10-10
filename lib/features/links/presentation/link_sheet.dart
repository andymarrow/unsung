import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/glass_sheet.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/song_sheet.dart';
import 'package:unsung/features/links/domain/link.dart';
import 'package:unsung/features/links/presentation/link_controller.dart';

/// Opens "From a link". [initialText] pre-fills it, e.g. from Share → Unsung.
/// When a song comes in and the user taps "Unsing it", its song sheet opens.
Future<void> showLinkSheet(BuildContext context, {String? initialText}) async {
  final song = await showGlassSheet<Song>(
    context,
    builder: (_) => LinkSheet(initialText: initialText),
  );
  if (song != null && context.mounted) {
    await showSongSheet(context, song);
  }
}

class LinkSheet extends ConsumerStatefulWidget {
  const LinkSheet({this.initialText, super.key});

  final String? initialText;

  @override
  ConsumerState<LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends ConsumerState<LinkSheet> {
  late final _field = TextEditingController(text: widget.initialText);

  LinkController get _controller => ref.read(linkControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_controller.submit(initial)));
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    _field.text = text;
    await _controller.submit(text);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final state = ref.watch(linkControllerProvider);
    final busy = state is LinkImporting;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FROM A LINK', style: type.labelMuted),
          const SizedBox(height: Space.xxs),
          Text('Bring in a song from YouTube', style: type.heading),
          const SizedBox(height: Space.md),
          TextField(
            controller: _field,
            enabled: !busy,
            autofocus: widget.initialText == null,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            style: type.body,
            onChanged: (t) => unawaited(_controller.submit(t)),
            onSubmitted: (t) => unawaited(_controller.submit(t)),
            decoration: InputDecoration(
              hintText: 'youtube.com/watch?v=…',
              prefixIcon: Icon(Icons.link_rounded, color: c.inkMuted),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: Space.xxs),
                child: TextButton(
                  onPressed: busy ? null : () => unawaited(_paste()),
                  child: Text('PASTE', style: type.label),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          AnimatedSize(
            duration: Motion.of(context, Motion.base),
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.base),
              switchInCurve: Motion.decelerate,
              switchOutCurve: Motion.standard,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, if (current != null) current],
              ),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, Motion.riseFraction),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_stage(state)),
                child: _Body(state: state),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Only bring in songs you have the right to use. Audio stays on this phone.',
            style: type.rowMeta,
          ),
        ],
      ),
    );
  }

  /// Which body is showing. Progress updates keep the same key so the card
  /// doesn't cross-fade on every tick.
  static String _stage(LinkState s) => switch (s) {
        LinkIdle() => 'idle',
        LinkResolving() => 'resolving',
        LinkReady() || LinkImporting() => 'preview',
        LinkDone() => 'done',
        LinkFailed() => 'failed',
      };
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final LinkState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final controller = ref.read(linkControllerProvider.notifier);
    return switch (state) {
      LinkIdle() => Text(
          'Paste a link from YouTube or YouTube Music. Or, in the YouTube app, tap Share → Unsung.',
          style: type.bodyMuted,
        ),
      LinkResolving() => const _PreviewSkeleton(),
      LinkReady(:final preview, :final alreadyHave) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PreviewCard(preview: preview),
            const SizedBox(height: Space.md),
            if (alreadyHave != null)
              CueButton(
                label: 'Already here: open it',
                icon: Icons.library_music_rounded,
                expand: true,
                onTap: () => Navigator.of(context).pop(alreadyHave),
              )
            else
              CueButton(
                label: 'Bring it in',
                icon: Icons.south_rounded,
                expand: true,
                onTap: () => unawaited(controller.import()),
              ),
          ],
        ),
      LinkImporting(:final preview, :final progress) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PreviewCard(preview: preview, progress: progress, busy: true),
            const SizedBox(height: Space.md),
            QuietButton(
                label: 'Cancel', onTap: controller.cancel, expand: true),
          ],
        ),
      LinkDone(:final song) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Arrived(song: song),
            const SizedBox(height: Space.md),
            CueButton(
              label: 'Unsing it',
              icon: Icons.graphic_eq_rounded,
              expand: true,
              onTap: () => Navigator.of(context).pop(song),
            ),
          ],
        ),
      LinkFailed(:final message, :final preview) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview != null) ...[
              _PreviewCard(preview: preview),
              const SizedBox(height: Space.sm),
            ],
            Text(message, style: type.body.copyWith(color: context.colors.cue)),
            if (preview != null) ...[
              const SizedBox(height: Space.md),
              QuietButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                expand: true,
                onTap: () => unawaited(controller.import()),
              ),
            ],
          ],
        ),
    };
  }
}

/// The video as a song: cover, title, artist, length. While importing, a cue
/// line runs along the bottom edge (sliding when the size isn't known yet).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, this.progress, this.busy = false});

  final LinkPreview preview;
  final double? progress;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final pct = progress == null ? null : (progress! * 100).round();
    return Semantics(
      label:
          '${preview.title}${preview.artist == null ? '' : ' by ${preview.artist}'}'
          '${busy ? ', downloading${pct == null ? '' : ' $pct percent'}' : ''}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: ColoredBox(
          color: c.raised,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Row(
                  children: [
                    _Thumb(url: preview.thumbnailUrl, title: preview.title),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preview.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: type.rowTitle),
                          if (preview.artist != null) ...[
                            const SizedBox(height: Space.xxs),
                            Text(preview.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.rowMeta),
                          ],
                          const SizedBox(height: Space.xs),
                          Wrap(
                            spacing: Space.xs,
                            runSpacing: Space.xxs,
                            children: [
                              TapeLabel(formatDuration(preview.duration)),
                              AnimatedSwitcher(
                                duration: Motion.of(context, Motion.fast),
                                child: busy
                                    ? TapeLabel(
                                        pct == null
                                            ? 'Finding audio'
                                            : 'Fetching $pct%',
                                        key: const ValueKey('busy'),
                                        tone: TapeTone.outline,
                                        icon: Icons.graphic_eq_rounded,
                                      )
                                    : const TapeLabel('YouTube',
                                        key: ValueKey('src'),
                                        tone: TapeTone.outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: busy ? 1 : 0,
                duration: Motion.of(context, Motion.base),
                child: busy
                    ? _ProgressLine(value: progress)
                    : const SizedBox(height: Sizes.strokeBold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const size = Sizes.linkThumb;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.chip),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? ColoredBox(
                color: c.stage,
                child: Icon(Icons.music_note_rounded,
                    color: c.inkFaint, size: Sizes.iconLg),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: (size * dpr * Sizes.videoAspect).round(),
                semanticLabel: 'Thumbnail for $title',
                // Fade in once loaded instead of popping.
                frameBuilder: (context, child, frame, sync) => sync
                    ? child
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: Motion.of(context, Motion.slow),
                        curve: Motion.decelerate,
                        child: child,
                      ),
                errorBuilder: (_, __, ___) => ColoredBox(color: c.stage),
              ),
      ),
    );
  }
}

/// Determinate: eases to the value. Indeterminate: a short segment glides
/// across, calm rather than flashing.
class _ProgressLine extends StatefulWidget {
  const _ProgressLine({required this.value});

  final double? value;

  @override
  State<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<_ProgressLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide =
      AnimationController(vsync: this, duration: Motion.signature * 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ProgressLine old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.value == null && !Motion.reduced(context);
    if (run && !_slide.isAnimating) {
      unawaited(_slide.repeat());
    } else if (!run && _slide.isAnimating) {
      _slide.stop();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: Sizes.strokeBold,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final value = widget.value;
          if (value != null) {
            return Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: value),
                duration: Motion.of(context, Motion.base),
                curve: Motion.standard,
                builder: (_, v, __) => Container(width: w * v, color: c.cue),
              ),
            );
          }
          return AnimatedBuilder(
            animation: _slide,
            builder: (_, __) {
              final t = Motion.standard.transform(_slide.value);
              final seg = w * Sizes.progressSegment;
              return Stack(children: [
                Positioned(
                  left: -seg + (w + seg) * t,
                  width: seg,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(color: c.cue),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Looking up the link',
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: context.colors.raised,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: const Row(
          children: [
            Skeleton(
              width: Sizes.linkThumb,
              height: Sizes.linkThumb,
            ),
            SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(),
                  SizedBox(height: Space.xs),
                  Skeleton(width: Sizes.sliderLabel, height: Space.sm),
                  SizedBox(height: Space.sm),
                  Skeleton(width: Space.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The imported song, settled: a check that pops in once.
class _Arrived extends StatelessWidget {
  const _Arrived({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.of(context, Motion.slow),
            curve: Motion.emphasized,
            builder: (_, t, child) => Transform.scale(scale: t, child: child),
            child: Container(
              width: Sizes.chip,
              height: Sizes.chip,
              decoration: BoxDecoration(color: c.cue, shape: BoxShape.circle),
              child:
                  Icon(Icons.check_rounded, color: c.onCue, size: Sizes.icon),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IN YOUR LIBRARY', style: type.labelMuted),
                const SizedBox(height: Space.xxs),
                Text(song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.rowTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
