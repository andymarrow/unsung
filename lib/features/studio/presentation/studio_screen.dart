import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/platform/permissions.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/cue_glow.dart';
import 'package:unsung/core/widgets/pressable.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/tape_label.dart';
import 'package:unsung/features/karaoke/domain/karaoke_track.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';
import 'package:unsung/features/lyrics/data/lyrics_repository.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_editor_sheet.dart';
import 'package:unsung/features/lyrics/presentation/lyrics_view.dart';
import 'package:unsung/features/player/rehearse_controller.dart';
import 'package:unsung/features/player/widgets.dart';
import 'package:unsung/features/studio/data/takes_repository.dart';
import 'package:unsung/features/studio/presentation/pitch_ribbon.dart';
import 'package:unsung/features/studio/presentation/studio_session.dart';
import 'package:unsung/features/studio/presentation/takes_controller.dart';

class StudioScreen extends ConsumerWidget {
  const StudioScreen({required this.songId, super.key});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(songByIdProvider(songId));
    final track = ref.watch(karaokeTrackProvider(songId));
    if (song == null || track == null) {
      final loading = ref.watch(libraryProvider).isLoading ||
          ref.watch(karaokeTracksProvider).isLoading;
      return Scaffold(
        appBar: AppBar(),
        body: loading
            ? const RowSkeletonList(count: 4)
            : EmptyState(
                kicker: 'Studio',
                title: 'Unsing this song first',
                message:
                    'The studio needs the instrumental. Open the song in your Library and tap "Unsing it".',
                actionLabel: 'Go to Library',
                onAction: () => context.go(Routes.library),
              ),
      );
    }
    return _Studio(song: song, track: track);
  }
}

class _Studio extends ConsumerStatefulWidget {
  const _Studio({required this.song, required this.track});

  final Song song;
  final KaraokeTrack track;

  @override
  ConsumerState<_Studio> createState() => _StudioState();
}

class _StudioState extends ConsumerState<_Studio> {
  late final StudioSession _s = StudioSession(
    song: widget.song,
    track: widget.track,
    takes: ref.read(takesRepositoryProvider),
    permissions: ref.read(permissionsProvider),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_s.prepare());
  }

  @override
  void dispose() {
    _s.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    await _s.countIn(Motion.beat, (n) {
      unawaited(
          n == 1 ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact());
    });
  }

  Future<void> _stop() async {
    unawaited(HapticFeedback.mediumImpact());
    final take = await _s.stop();
    if (take == null || !mounted) return;
    await ref.read(takesProvider.notifier).upsert(take);
    if (mounted) unawaited(context.pushReplacement(Routes.reviewFor(take.id)));
  }

  Future<bool> _confirmLeave() async {
    if (_s.phase != StudioPhase.recording) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: d.colors.surface,
        title: Text('Throw this take away?', style: d.type.heading),
        content: Text("You're mid-song. Leaving now discards it.",
            style: d.type.bodyMuted),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text('KEEP SINGING', style: d.type.label),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('DISCARD',
                style: d.type.label.copyWith(color: d.colors.cue)),
          ),
        ],
      ),
    );
    if (leave ?? false) await _s.discard();
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsProvider(widget.song));
    final offset = ref.read(lyricsOffsetsProvider).get(widget.song.id);

    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        final phase = _s.phase;
        final live = phase == StudioPhase.recording;
        return PopScope(
          canPop: !live,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            if (await _confirmLeave()) nav.pop();
          },
          child: Scaffold(
            body: AnimatedContainer(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.standard,
              color: context.colors.stage,
              child: CueGlow(
                alignment: Alignment.bottomCenter,
                radius: 1.2,
                intensity: live ? Alphas.glow : Alphas.ghost,
                child: SafeArea(
                  child: switch (phase) {
                    StudioPhase.needsMic => EmptyState(
                        icon: Icons.mic_off_rounded,
                        kicker: 'Studio',
                        title: 'Unsung needs your microphone',
                        message: _s.micBlocked
                            ? 'Microphone access is off. Turn it on in settings, then come back.'
                            : 'To record your voice over the music, allow microphone access.',
                        actionLabel: _s.micBlocked
                            ? 'Open settings'
                            : 'Allow microphone',
                        onAction: () => unawaited(_s.retryMic()),
                      ),
                    StudioPhase.failed => ErrorState(
                        failure: _s.failure!,
                        onRetry: () => unawaited(_s.prepare()),
                      ),
                    _ => Column(
                        children: [
                          _TopBar(
                            song: widget.song,
                            live: live,
                            elapsed: _s.elapsed,
                            onClose: () async {
                              final nav = Navigator.of(context);
                              if (await _confirmLeave()) nav.pop();
                            },
                          ),
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: lyrics.when(
                                    data: (l) => LyricsView(
                                      lyrics: l,
                                      position: _s.position,
                                      offset: offset,
                                      topInset: Space.md,
                                      onAddLyrics: () => unawaited(
                                        showLyricsEditor(context, widget.song),
                                      ),
                                    ),
                                    error: (_, __) => const SizedBox.shrink(),
                                    loading: () => const SizedBox.shrink(),
                                  ),
                                ),
                                if (phase == StudioPhase.countdown)
                                  Positioned.fill(
                                      child: _Countdown(n: _s.countdown)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Space.gutter),
                            child: PitchRibbon(history: _s.history),
                          ),
                          _Controls(
                            session: _s,
                            onRecord: () => unawaited(_record()),
                            onStop: () => unawaited(_stop()),
                            onDiscard: () => unawaited(_s.discard()),
                          ),
                        ],
                      ),
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.song,
    required this.live,
    required this.elapsed,
    required this.onClose,
  });

  final Song song;
  final bool live;
  final Duration elapsed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.gutter, 0),
      child: Row(
        children: [
          RoundIconButton(
              icon: Icons.close_rounded, label: 'Close studio', onTap: onClose),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STUDIO', style: context.type.labelMuted),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.rowTitle,
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.base),
            child: live
                ? TapeLabel(
                    '● Rec ${formatDuration(elapsed)}',
                    key: const ValueKey('rec'),
                    tone: TapeTone.cue,
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.n});

  final int n;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.scrim,
      child: Center(
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.base),
          switchInCurve: Motion.emphasized,
          transitionBuilder: (child, a) => ScaleTransition(
            scale: Tween<double>(begin: 1.6, end: 1).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
          child: Text(
            n > 0 ? '$n' : 'Sing',
            key: ValueKey(n),
            style: context.type.hero.copyWith(color: context.colors.cue),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.session,
    required this.onRecord,
    required this.onStop,
    required this.onDiscard,
  });

  final StudioSession session;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final phase = session.phase;
    final recording = phase == StudioPhase.recording;
    final busy = phase == StudioPhase.preparing || phase == StudioPhase.saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Space.gutter, Space.sm, Space.gutter, Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    duration: Motion.of(context, Motion.base),
                    opacity: phase == StudioPhase.ready ? 1 : 0,
                    child: KeyStepper(
                      semitones: session.semitones,
                      onChanged: (k) => unawaited(session.setKey(k)),
                    ),
                  ),
                ),
              ),
              _RecordButton(
                recording: recording,
                busy: busy,
                onTap: switch (phase) {
                  StudioPhase.ready => onRecord,
                  StudioPhase.recording => onStop,
                  _ => null,
                },
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: recording
                      ? TextButton(
                          onPressed: onDiscard,
                          child: Text('RESTART', style: type.labelMuted),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.base),
            child: Text(
              switch (phase) {
                StudioPhase.preparing => 'SETTING UP THE STUDIO…',
                StudioPhase.ready => 'HEADPHONES ON · TAP TO RECORD',
                StudioPhase.countdown => 'GET READY',
                StudioPhase.recording => 'TAP TO FINISH',
                StudioPhase.saving => 'SAVING YOUR TAKE…',
                _ => '',
              },
              key: ValueKey(phase),
              style: type.labelMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Signature 3 lands here: the cue disc that the spotlight opens from.
class _RecordButton extends StatelessWidget {
  const _RecordButton(
      {required this.recording, required this.busy, required this.onTap});

  final bool recording;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = Motion.of(context, Motion.base);
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.heavy,
      semanticLabel: recording ? 'Stop recording' : 'Start recording',
      child: Hero(
        tag: 'spotlight',
        child: AnimatedContainer(
          duration: d,
          curve: Motion.emphasized,
          width: Sizes.recordButtonLarge,
          height: Sizes.recordButtonLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? c.ink : c.cue,
            boxShadow: [
              BoxShadow(
                color: c.cue.withValues(
                    alpha: recording ? Alphas.glowStrong : Alphas.glow),
                blurRadius: Space.xl,
              ),
            ],
          ),
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: Sizes.icon,
                    child: CircularProgressIndicator(
                        strokeWidth: Sizes.stroke, color: c.onCue),
                  )
                : AnimatedContainer(
                    duration: d,
                    curve: Motion.emphasized,
                    width: recording ? Sizes.icon : Sizes.iconLg,
                    height: recording ? Sizes.icon : Sizes.iconLg,
                    decoration: BoxDecoration(
                      color: recording ? c.cue : c.onCue,
                      borderRadius: BorderRadius.circular(
                          recording ? Radii.chip : Radii.full),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
