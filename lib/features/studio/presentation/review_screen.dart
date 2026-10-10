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
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/core/widgets/waveform.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/player/widgets.dart';
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

  static const _debounceDelay = Duration(milliseconds: 500);
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
    _debounce = Timer(_debounceDelay, () => unawaited(_renderPreview()));
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: d.colors.surface,
        title: Text('Delete this take?', style: d.type.heading),
        content: Text('The recording and its mix are removed from this phone.',
            style: d.type.bodyMuted),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text('KEEP', style: d.type.label)),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('DELETE',
                style: d.type.label.copyWith(color: d.colors.cue)),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await _player.stop();
    await ref.read(takesProvider.notifier).delete(widget.take);
    if (mounted) context.go(Routes.takes);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    final take = widget.take;
    final progress = _dur.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);

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
          AnimatedOpacity(
            duration: Motion.of(context, Motion.base),
            opacity: _rendering ? 0.4 : 1,
            child: Waveform(
              peaks: _peaks.isEmpty ? widget.track.instrumentalPeaks : _peaks,
              progress: progress,
              height: Sizes.waveformCompact,
              onSeek:
                  _rendering ? null : (f) => unawaited(_player.seek(_dur * f)),
            ),
          ),
          TimeReadout(position: _pos, duration: _dur),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              PlayButton(
                playing: _playing,
                onTap: _rendering
                    ? null
                    : () =>
                        unawaited(_playing ? _player.pause() : _player.play()),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.base),
                  child: _failure != null
                      ? Text(_failure!.message,
                          key: const ValueKey('err'),
                          style: type.rowMeta.copyWith(color: c.cue))
                      : Text(
                          _rendering
                              ? 'MIXING…'
                              : 'PREVIEW UPDATES AS YOU CHANGE THINGS',
                          key: ValueKey(_rendering),
                          style: type.labelMuted,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('MIX', style: type.labelMuted),
          const SizedBox(height: Space.xs),
          LevelSlider(
            label: 'Voice',
            value: _settings.vocalGain / _maxVoiceGain,
            display: '${(_settings.vocalGain * 100).round()}%',
            onChanged: (v) =>
                _change(_settings.copyWith(vocalGain: v * _maxVoiceGain)),
          ),
          LevelSlider(
            label: 'Music',
            value: _settings.musicGain,
            onChanged: (v) => _change(_settings.copyWith(musicGain: v)),
          ),
          LevelSlider(
            label: 'Reverb',
            value: _settings.reverb,
            onChanged: (v) => _change(_settings.copyWith(reverb: v)),
          ),
          LevelSlider(
            label: 'Echo',
            value: _settings.echo,
            onChanged: (v) => _change(_settings.copyWith(echo: v)),
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
                onTap: () => _change(_settings.copyWith(
                    offsetMs: _settings.offsetMs + _syncStepMs)),
              ),
              Expanded(
                child: Text(
                  '${_settings.offsetMs} ms',
                  textAlign: TextAlign.center,
                  style: type.numeral,
                ),
              ),
              RoundIconButton(
                icon: Icons.add_rounded,
                label: 'Voice later',
                onTap: () => _change(_settings.copyWith(
                    offsetMs: _settings.offsetMs - _syncStepMs)),
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
                _settings.semitones == 0
                    ? 'Original key'
                    : '${_settings.semitones > 0 ? '+' : ''}${_settings.semitones} semitones',
              ),
            ],
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
