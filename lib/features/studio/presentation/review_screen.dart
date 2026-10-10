import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:unsung/core/platform/native_audio.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/glass_sheet.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/core/widgets/waveform.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/player/widgets.dart';
import 'package:unsung/features/social/presentation/share_sheet.dart';
import 'package:unsung/features/studio/data/takes_repository.dart';
import 'package:unsung/features/studio/domain/take.dart';
import 'package:unsung/features/studio/presentation/takes_controller.dart';

/// Edit a take's mix. Nothing is baked in: the raw vocal is kept, so every
/// setting can be changed again later.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({required this.takeId, super.key});

  final String takeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final take = ref.watch(takeByIdProvider(takeId));
    final track =
        take == null ? null : ref.watch(karaokeTrackProvider(take.songId));
    if (take == null || track == null) {
      final loading = ref.watch(takesProvider).isLoading ||
          ref.watch(karaokeTracksProvider).isLoading;
      return Scaffold(
        appBar: AppBar(),
        body: loading
            ? const RowSkeletonList(count: 4)
            : EmptyState(
                kicker: 'Take',
                title: take == null
                    ? 'This take is gone'
                    : 'The instrumental is missing',
                message: take == null
                    ? 'It may have been deleted.'
                    : 'Unsing "${take.songTitle}" again to edit this take.',
                actionLabel: 'Back to takes',
                onAction: () => context.go(Routes.takes),
              ),
      );
    }
    return _Review(take: take, track: track);
  }
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.take, required this.track});

  final Take take;
  final KaraokeTrack track;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  final _player = AudioPlayer();
  late MixSettings _settings = widget.take.settings;
  List<double> _peaks = const [];
  bool _rendering = true;
  bool _saving = false;
  double _saveProgress = 0;
  AppFailure? _failure;
  Timer? _debounce;
  int _renderGen = 0;
  final _subs = <StreamSubscription<Object?>>[];
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;

  static const _syncStepMs = 20;
  static const _maxVoiceGain = 2.0;

  TakesRepository get _repo => ref.read(takesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.positionStream.listen((p) => setState(() => _pos = p)))
      ..add(
        _player.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed) {
            unawaited(_player.pause());
            unawaited(_player.seek(Duration.zero));
          }
          setState(() => _playing =
              s.playing && s.processingState != ProcessingState.completed);
        }),
      );
    unawaited(_renderPreview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  void _change(MixSettings next) {
    setState(() => _settings = next);
    _debounce?.cancel();
    _debounce = Timer(Motion.debounce, () => unawaited(_renderPreview()));
  }

  Future<void> _renderPreview() async {
    final gen = ++_renderGen;
    setState(() {
      _rendering = true;
      _failure = null;
    });
    try {
      final wasPlaying = _player.playing;
      final at = _player.position;
      final r = await _repo.render(widget.take, widget.track.path,
          preview: true, settings: _settings);
      if (!mounted || gen != _renderGen) return;
      final d = await _player.setFilePath(r.path, initialPosition: at);
      if (wasPlaying) unawaited(_player.play());
      setState(() {
        _peaks = r.peaks;
        _dur = d ?? r.duration;
        _rendering = false;
      });
    } on Object catch (e) {
      if (!mounted || gen != _renderGen) return;
      setState(() {
        _failure = toFailure(e);
        _rendering = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveProgress = 0;
    });
    await _player.pause();
    try {
      final r = await _repo.render(
        widget.take,
        widget.track.path,
        preview: false,
        settings: _settings,
        onProgress: (p) {
          if (mounted) setState(() => _saveProgress = p);
        },
      );
      final saved = widget.take.copyWith(
        mixPath: r.path,
        settings: _settings,
        peaks: r.peaks,
        duration: r.duration,
      );
      await ref.read(takesProvider.notifier).upsert(saved);
      final preview = File('${_repo.folderFor(saved.id)}/preview.wav');
      if (preview.existsSync()) await preview.delete();
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) context.go(Routes.takes);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(toFailure(e).message)));
    }
  }

  Future<void> _delete() async {
    final ok = await confirmSheet(
      context,
      title: 'Delete this take?',
      message: 'The recording and its mix are removed from this phone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    await _player.stop();
    await ref.read(takesProvider.notifier).delete(widget.take);
    if (mounted) context.go(Routes.takes);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final take = widget.take;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR TAKE', style: type.labelMuted),
            Text(take.songTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.rowTitle),
          ],
        ),
        actions: [
          if (take.mixPath != null)
            RoundIconButton(
              icon: take.postId == null
                  ? Icons.ios_share_rounded
                  : Icons.podcasts_rounded,
              label: take.postId == null ? 'Share take' : 'View on the Stage',
              onTap: () => unawaited(shareTake(context, ref, take)),
            ),
          RoundIconButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete take',
              onTap: () => unawaited(_delete())),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.xs, Space.gutter, Space.xxl),
        children: [
          _Stats(take: take),
          const SizedBox(height: Space.lg),
          _Preview(
            peaks: _peaks.isEmpty ? widget.track.instrumentalPeaks : _peaks,
            position: _pos,
            duration: _dur,
            playing: _playing,
            rendering: _rendering,
            failure: _failure,
            onSeek: (f) => unawaited(_player.seek(_dur * f)),
            onPlayPause: () =>
                unawaited(_playing ? _player.pause() : _player.play()),
          ),
          const SizedBox(height: Space.xl),
          _MixControls(
            settings: _settings,
            maxVoiceGain: _maxVoiceGain,
            syncStepMs: _syncStepMs,
            onChange: _change,
          ),
          const SizedBox(height: Space.xl),
          CueButton(
            label: _saving
                ? 'Saving ${(_saveProgress * 100).round()}%'
                : 'Save take',
            icon: Icons.check_rounded,
            busy: _saving,
            expand: true,
            onTap: _rendering ? null : () => unawaited(_save()),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Takes are private until you share them. You can change this mix any time.',
            textAlign: TextAlign.center,
            style: type.rowMeta,
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.take});

  final Take take;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    Widget stat(String label, String value, {bool accent = false}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: type.labelMuted),
              const SizedBox(height: Space.xxs),
              Text(value,
                  style: type.title.copyWith(color: accent ? c.cue : c.ink)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(Radii.card)),
      child: Row(
        children: [
          stat('IN TUNE', '${(take.inTune * 100).round()}%', accent: true),
          stat('SUNG', '${(take.presence * 100).round()}%'),
          stat('LENGTH', formatDuration(take.duration)),
        ],
      ),
    );
  }
}

/// Playback of the current preview mix, with its state line.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.peaks,
    required this.position,
    required this.duration,
    required this.playing,
    required this.rendering,
    required this.failure,
    required this.onSeek,
    required this.onPlayPause,
  });

  final List<double> peaks;
  final Duration position;
  final Duration duration;
  final bool playing;

  /// A new preview is being mixed: playback waits for it.
  final bool rendering;
  final AppFailure? failure;
  final ValueChanged<double> onSeek;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedOpacity(
          duration: Motion.of(context, Motion.base),
          opacity: rendering ? 0.4 : 1,
          child: Waveform(
            peaks: peaks,
            progress: progress,
            height: Sizes.waveformCompact,
            onSeek: rendering ? null : onSeek,
          ),
        ),
        TimeReadout(position: position, duration: duration),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            PlayButton(
              playing: playing,
              onTap: rendering ? null : onPlayPause,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.base),
                child: failure != null
                    ? Text(failure!.message,
                        key: const ValueKey('err'),
                        style: type.rowMeta.copyWith(color: c.cue))
                    : Text(
                        rendering
                            ? 'MIXING…'
                            : 'PREVIEW UPDATES AS YOU CHANGE THINGS',
                        key: ValueKey(rendering),
                        style: type.labelMuted,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Voice, music, reverb, echo, sync nudge and key. Every change re-renders
/// the preview from the raw vocal, so nothing here is destructive.
class _MixControls extends StatelessWidget {
  const _MixControls({
    required this.settings,
    required this.maxVoiceGain,
    required this.syncStepMs,
    required this.onChange,
  });

  final MixSettings settings;
  final double maxVoiceGain;
  final int syncStepMs;
  final ValueChanged<MixSettings> onChange;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MIX', style: type.labelMuted),
        const SizedBox(height: Space.xs),
        LevelSlider(
          label: 'Voice',
          value: settings.vocalGain / maxVoiceGain,
          display: '${(settings.vocalGain * 100).round()}%',
          onChanged: (v) =>
              onChange(settings.copyWith(vocalGain: v * maxVoiceGain)),
        ),
        LevelSlider(
          label: 'Music',
          value: settings.musicGain,
          onChanged: (v) => onChange(settings.copyWith(musicGain: v)),
        ),
        LevelSlider(
          label: 'Reverb',
          value: settings.reverb,
          onChanged: (v) => onChange(settings.copyWith(reverb: v)),
        ),
        LevelSlider(
          label: 'Echo',
          value: settings.echo,
          onChanged: (v) => onChange(settings.copyWith(echo: v)),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            SizedBox(
                width: Sizes.sliderLabel,
                child: Text('SYNC', style: type.labelMuted)),
            RoundIconButton(
              icon: Icons.remove_rounded,
              label: 'Voice earlier',
              onTap: () => onChange(
                  settings.copyWith(offsetMs: settings.offsetMs + syncStepMs)),
            ),
            Expanded(
              child: Text(
                '${settings.offsetMs} ms',
                textAlign: TextAlign.center,
                style: type.numeral,
              ),
            ),
            RoundIconButton(
              icon: Icons.add_rounded,
              label: 'Voice later',
              onTap: () => onChange(
                  settings.copyWith(offsetMs: settings.offsetMs - syncStepMs)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: Sizes.sliderLabel),
          child: Text(
            'If your voice sounds late, tap minus. Bluetooth headphones usually need more.',
            style: type.rowMeta,
          ),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            SizedBox(
                width: Sizes.sliderLabel,
                child: Text('KEY', style: type.labelMuted)),
            TapeLabel(
              settings.semitones == 0
                  ? 'Original key'
                  : '${settings.semitones > 0 ? '+' : ''}${settings.semitones} semitones',
            ),
          ],
        ),
      ],
    );
  }
}
