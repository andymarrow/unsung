import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/env.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/artwork.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/glass_sheet.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/core/widgets/toggle_chip.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/karaoke/presentation/unsinging_view.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';

Future<void> showSongSheet(BuildContext context, Song song) {
  return showGlassSheet<void>(
    context,
    builder: (_) => SongSheet(song: song),
  );
}

/// Everything about one song: unsing it, then rehearse or sing.
class SongSheet extends ConsumerStatefulWidget {
  const SongSheet({required this.song, super.key});

  final Song song;

  @override
  ConsumerState<SongSheet> createState() => _SongSheetState();
}

class _SongSheetState extends ConsumerState<SongSheet> {
  SeparationMode _mode = SeparationMode.quick;

  /// True between the end of a conversion and the settle animation finishing.
  bool _justFinished = false;
  KaraokeRunning? _lastRun;

  Song get song => widget.song;

  void _start() {
    unawaited(ref.read(karaokeJobsProvider.notifier).start(song, _mode));
  }

  /// Imported songs live only in the app; this deletes the audio, cover and
  /// any karaoke made from it.
  void _deleteImport() => unawaited(() async {
        final ok = await confirmSheet(
          context,
          title: 'Delete this download?',
          message:
              'The song and its karaoke leave this phone. Your takes stay. You can bring it in again from the link.',
          confirmLabel: 'Delete',
          icon: Icons.delete_outline_rounded,
        );
        if (!ok || !mounted) return;
        final navigator = Navigator.of(context);
        await ref.read(karaokeTracksProvider.notifier).remove(song.id);
        await ref.read(libraryProvider.notifier).removeImported(song);
        navigator.pop();
      }());

  void _go(String location) {
    Navigator.of(context).pop();
    unawaited(context.push(location));
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final art = ref.watch(artworkProvider(song)).valueOrNull;
    final track = ref.watch(karaokeTrackProvider(song.id));
    final job = ref.watch(karaokeJobProvider(song.id));

    ref.listen(karaokeJobProvider(song.id), (prev, next) {
      if (prev is KaraokeRunning && next == null) {
        unawaited(HapticFeedback.mediumImpact());
        setState(() => _justFinished = true);
      }
    });
    if (job is KaraokeRunning) _lastRun = job;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'art-${song.id}',
                child: Artwork(
                  title: song.title,
                  bytes: art,
                  size: Sizes.artworkSheet,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: type.heading,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(song.artistOrUnknown, style: type.rowMeta),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        TapeLabel(formatDuration(song.duration)),
                        if (song.isImported)
                          const TapeLabel('YouTube', tone: TapeTone.outline),
                        if (track != null)
                          TapeLabel(
                            track.mode == SeparationMode.studio
                                ? 'Studio'
                                : 'Ready',
                            tone: TapeTone.cue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          AnimatedSize(
            duration: Motion.of(context, Motion.base),
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.base),
              child: switch (job) {
                KaraokeRunning() => _Running(
                    key: const ValueKey('running'),
                    job: job,
                    onCancel: () => unawaited(
                      ref.read(karaokeJobsProvider.notifier).cancel(song),
                    ),
                  ),
                KaraokeFailed(:final message, :final mode) => _Failed(
                    key: const ValueKey('failed'),
                    message: message,
                    onRetry: () {
                      ref.read(karaokeJobsProvider.notifier).dismiss(song.id);
                      _mode = mode == SeparationMode.studio
                          ? SeparationMode.quick
                          : mode;
                      _start();
                    },
                  ),
                null when track != null => _Ready(
                    key: const ValueKey('ready'),
                    track: track,
                    lastRun: _justFinished ? _lastRun : null,
                    onSing: () => _go(Routes.studioFor(song.id)),
                    onRehearse: () => _go(Routes.rehearseFor(song.id)),
                    onRedo: _start,
                    onRemove: () => unawaited(
                      ref.read(karaokeTracksProvider.notifier).remove(song.id),
                    ),
                    onDeleteImport: song.isImported ? _deleteImport : null,
                  ),
                null => _Idle(
                    key: const ValueKey('idle'),
                    mode: _mode,
                    onMode: (m) => setState(() => _mode = m),
                    onStart: _start,
                    onDeleteImport: song.isImported ? _deleteImport : null,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({
    required this.mode,
    required this.onMode,
    required this.onStart,
    this.onDeleteImport,
    super.key,
  });

  final SeparationMode mode;
  final ValueChanged<SeparationMode> onMode;
  final VoidCallback onStart;
  final VoidCallback? onDeleteImport;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UNSING THIS SONG', style: type.labelMuted),
        const SizedBox(height: Space.xs),
        Text(
          mode == SeparationMode.quick
              ? 'Quick works right here on your phone and keeps the bass, drums and stereo band. Centred instruments get softer too.'
              : 'Studio sends the song to your separation server for a much cleaner instrumental. It takes a minute or two.',
          style: type.bodyMuted,
        ),
        if (Env.hasStudioSeparation) ...[
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              ToggleChip(
                label: 'Quick',
                selected: mode == SeparationMode.quick,
                onTap: () => onMode(SeparationMode.quick),
              ),
              ToggleChip(
                label: 'Studio',
                selected: mode == SeparationMode.studio,
                onTap: () => onMode(SeparationMode.studio),
              ),
            ],
          ),
        ],
        const SizedBox(height: Space.lg),
        CueButton(
          label: 'Unsing it',
          icon: Icons.auto_fix_high_rounded,
          expand: true,
          onTap: onStart,
        ),
        if (onDeleteImport != null) ...[
          const SizedBox(height: Space.sm),
          QuietButton(
            label: 'Delete download',
            icon: Icons.delete_outline_rounded,
            expand: true,
            onTap: onDeleteImport,
          ),
        ],
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.job, required this.onCancel, super.key});

  final KaraokeRunning job;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text('Lifting the vocals out', style: type.heading),
            ),
            Text(
              '${(job.progress * 100).round()}%',
              style: type.title.copyWith(color: context.colors.cue),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        UnsingingView(
          progress: job.progress,
          instrumentalPeaks: job.instrumentalPeaks,
          vocalPeaks: job.vocalPeaks,
        ),
        const SizedBox(height: Space.md),
        Text(
          'You can close this. It keeps going in the background.',
          style: type.rowMeta,
        ),
        const SizedBox(height: Space.md),
        QuietButton(label: 'Cancel', onTap: onCancel),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HIT A WRONG NOTE', style: type.labelMuted),
        const SizedBox(height: Space.xs),
        Text(message, style: type.body),
        const SizedBox(height: Space.lg),
        CueButton(
            label: 'Try again', icon: Icons.refresh_rounded, onTap: onRetry),
      ],
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.track,
    required this.lastRun,
    required this.onSing,
    required this.onRehearse,
    required this.onRedo,
    required this.onRemove,
    this.onDeleteImport,
    super.key,
  });

  final KaraokeTrack track;

  /// Set right after a conversion so the settle animation plays.
  final KaraokeRunning? lastRun;
  final VoidCallback onSing;
  final VoidCallback onRehearse;
  final VoidCallback onRedo;
  final VoidCallback onRemove;
  final VoidCallback? onDeleteImport;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final run = lastRun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (run != null)
          _Settling(run: run, track: track)
        else
          UnsingingView(
            progress: 1,
            done: true,
            instrumentalPeaks: track.instrumentalPeaks,
            vocalPeaks: track.vocalPeaks,
            height: Sizes.waveformCompact,
          ),
        if (track.mayLeakVocals) ...[
          const SizedBox(height: Space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: Sizes.iconSm, color: c.inkMuted),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  "This mix is close to mono, so some of the voice may still come through. It's still great for rehearsing.",
                  style: type.rowMeta,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Space.sm),
        Text(
          track.mode == SeparationMode.studio
              ? 'Separated on your studio server. Voice out, band in.'
              : 'Unsung on this phone. Voice out, band in.',
          style: type.rowMeta,
        ),
        const SizedBox(height: Space.lg),
        CueButton(
          label: 'Sing',
          icon: Icons.mic_rounded,
          expand: true,
          onTap: onSing,
        ),
        const SizedBox(height: Space.sm),
        QuietButton(
          label: 'Rehearse first',
          icon: Icons.headphones_rounded,
          expand: true,
          onTap: onRehearse,
        ),
        const SizedBox(height: Space.lg),
        Container(height: Sizes.hairline, color: c.hairline),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            _MoreAction(
                icon: Icons.refresh_rounded,
                label: 'Unsing again',
                onTap: onRedo),
            _MoreAction(
                icon: Icons.layers_clear_rounded,
                label: 'Remove karaoke',
                onTap: onRemove),
            if (onDeleteImport != null)
              _MoreAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete download',
                  onTap: onDeleteImport!),
          ],
        ),
      ],
    );
  }
}

/// Plays the settle: the last frame of the live run with the ribbon floating off.
class _Settling extends StatefulWidget {
  const _Settling({required this.run, required this.track});

  final KaraokeRunning run;
  final KaraokeTrack track;

  @override
  State<_Settling> createState() => _SettlingState();
}

class _SettlingState extends State<_Settling> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return UnsingingView(
      progress: 1,
      done: _done,
      instrumentalPeaks: widget.track.instrumentalPeaks,
      vocalPeaks: widget.track.vocalPeaks,
      height: Sizes.waveformCompact,
    );
  }
}

/// Secondary action: icon + mono label, no fill, full tap target.
class _MoreAction extends StatelessWidget {
  const _MoreAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.selection,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.xs, vertical: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Sizes.iconMd, color: c.inkMuted),
            const SizedBox(width: Space.xs),
            Text(label.toUpperCase(), style: context.type.labelMuted),
          ],
        ),
      ),
    );
  }
}
