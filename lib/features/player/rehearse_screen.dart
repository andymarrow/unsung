import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/waveform.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';
import 'package:unsung/features/lyrics/data/lyrics_repository.dart';
import 'package:unsung/features/lyrics/domain/lyrics.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_editor_sheet.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_view.dart';
import 'package:unsung/features/player/rehearse_controller.dart';
import 'package:unsung/features/player/widgets.dart';

/// Resolves the song and its instrumental, then shows the rehearsal room.
class RehearseScreen extends ConsumerWidget {
  const RehearseScreen({required this.songId, super.key});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(songByIdProvider(songId));
    final track = ref.watch(karaokeTrackProvider(songId));
    final loading = ref.watch(libraryProvider).isLoading ||
        ref.watch(karaokeTracksProvider).isLoading;
    if (song == null || track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: loading
            ? const RowSkeletonList(count: 4)
            : EmptyState(
                kicker: 'Rehearse',
                title: 'This song isn’t ready',
                message: 'Unsing it from your Library first.',
                actionLabel: 'Go to Library',
                onAction: () => context.go(Routes.library),
              ),
      );
    }
    return _RehearseRoom(song: song, track: track);
  }
}

class _RehearseRoom extends ConsumerStatefulWidget {
  const _RehearseRoom({required this.song, required this.track});

  final Song song;
  final KaraokeTrack track;

  @override
  ConsumerState<_RehearseRoom> createState() => _RehearseRoomState();
}

class _RehearseRoomState extends ConsumerState<_RehearseRoom> {
  late final Rehearsal _r = Rehearsal(
    song: widget.song,
    track: widget.track,
    onChange: (f) {
      if (mounted) setState(() => _state = f(_state));
    },
  );
  var _state = const RehearseState();

  @override
  void initState() {
    super.initState();
    final offset = ref.read(lyricsOffsetsProvider).get(widget.song.id);
    _state = _state.copyWith(lyricsOffset: offset);
    unawaited(_r.open());
  }

  @override
  void dispose() {
    unawaited(_r.dispose());
    super.dispose();
  }

  Future<void> _nudge(int ms) async {
    final next = _state.lyricsOffset + Duration(milliseconds: ms);
    setState(() => _state = _state.copyWith(lyricsOffset: next));
    await ref.read(lyricsOffsetsProvider).set(widget.song.id, next);
  }

  Future<void> _sing() async {
    await _r.pause();
    if (!mounted) return;
    unawaited(context.push(Routes.studioFor(widget.song.id)));
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final lyrics = ref.watch(lyricsProvider(song));
    final error = _state.error;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REHEARSE', style: context.type.labelMuted),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.rowTitle,
            ),
          ],
        ),
        actions: [
          RoundIconButton(
            icon: Icons.tune_rounded,
            label: 'Lyrics options',
            onTap: () => unawaited(
              _showLyricsOptions(context, lyrics.valueOrNull),
            ),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: error != null
          ? ErrorState(failure: error, onRetry: () => unawaited(_r.open()))
          : Column(
              children: [
                Expanded(
                  child: switch (lyrics) {
                    AsyncData(:final value) => LyricsView(
                        lyrics: value,
                        position: _r.position,
                        offset: _state.lyricsOffset,
                        onAddLyrics: () =>
                            unawaited(showLyricsEditor(context, song)),
                      ),
                    AsyncError(:final error) => ErrorState(
                        failure: toFailure(error),
                        onRetry: () => ref.invalidate(lyricsProvider(song)),
                      ),
                    _ => const _LyricsLoading(),
                  },
                ),
                _Deck(
                  state: _state,
                  track: widget.track,
                  onPlay: () => unawaited(
                    _state.playing ? _r.pause() : _r.play(),
                  ),
                  onSeek: (f) => unawaited(
                    _r.seek(_state.duration * f),
                  ),
                  onKey: (k) => unawaited(_r.setKey(k)),
                  onGuide: (v) => unawaited(_r.setGuide(v)),
                  onSing: () => unawaited(_sing()),
                ),
              ],
            ),
    );
  }

  Future<void> _showLyricsOptions(BuildContext context, Lyrics? lyrics) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final ms = _state.lyricsOffset.inMilliseconds;
          final type = sheet.type;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lyrics', style: type.heading),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: Text('TIMING', style: type.labelMuted),
                    ),
                    RoundIconButton(
                      icon: Icons.fast_rewind_rounded,
                      label: 'Show lyrics earlier',
                      onTap: () async {
                        await _nudge(-100);
                        setSheet(() {});
                      },
                    ),
                    SizedBox(
                      width: Sizes.tap * 1.5,
                      child: Text(
                        '${ms > 0 ? '+' : ''}${(ms / 1000).toStringAsFixed(1)}s',
                        textAlign: TextAlign.center,
                        style: type.numeral,
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.fast_forward_rounded,
                      label: 'Show lyrics later',
                      onTap: () async {
                        await _nudge(100);
                        setSheet(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                QuietButton(
                  label: lyrics == null || lyrics.isEmpty
                      ? 'Paste lyrics'
                      : 'Replace lyrics',
                  icon: Icons.edit_note_rounded,
                  expand: true,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    unawaited(showLyricsEditor(context, widget.song));
                  },
                ),
                const SizedBox(height: Space.xs),
                QuietButton(
                  label: 'Search lyrics again',
                  icon: Icons.manage_search_rounded,
                  expand: true,
                  onTap: () async {
                    Navigator.of(sheet).pop();
                    await ref.read(lyricsRepositoryProvider).forget(widget.song);
                    ref.invalidate(lyricsProvider(widget.song));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: Sizes.artworkHero, height: Space.lg),
          SizedBox(height: Space.md),
          Skeleton(width: Sizes.artworkHero * 1.2, height: Space.xl),
          SizedBox(height: Space.md),
          Skeleton(width: Sizes.artworkHero * 0.8, height: Space.lg),
        ],
      ),
    );
  }
}

class _Deck extends StatelessWidget {
  const _Deck({
    required this.state,
    required this.track,
    required this.onPlay,
    required this.onSeek,
    required this.onKey,
    required this.onGuide,
    required this.onSing,
  });

  final RehearseState state;
  final KaraokeTrack track;
  final VoidCallback onPlay;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onKey;
  final ValueChanged<double> onGuide;
  final VoidCallback onSing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Waveform(
                peaks: track.instrumentalPeaks,
                progress: state.progress,
                onSeek: state.ready ? onSeek : null,
              ),
              TimeReadout(position: state.position, duration: state.duration),
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  KeyStepper(semitones: state.semitones, onChanged: onKey),
                  const Spacer(),
                  PlayButton(
                    playing: state.playing,
                    onTap: state.ready ? onPlay : null,
                  ),
                  const Spacer(),
                  CueButton(label: 'Sing', icon: Icons.mic_rounded, onTap: onSing),
                ],
              ),
              const SizedBox(height: Space.xs),
              LevelSlider(
                label: 'Vocal guide',
                value: state.guide,
                onChanged: onGuide,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
