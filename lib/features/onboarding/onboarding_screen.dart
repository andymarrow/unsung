import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/prefs.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/cue_glow.dart';

class _Beat {
  const _Beat(this.kicker, this.lead, this.accent, this.body);
  final String kicker;
  final String lead;
  final String accent;
  final String body;
}

const _beats = [
  _Beat(
    '01 — Your library',
    'Every song you own is a',
    'karaoke track.',
    'Unsung finds the music already on your phone. One tap lifts the vocals out and leaves the band.',
  ),
  _Beat(
    '02 — The studio',
    'Sing it. Keep',
    'every take.',
    'Live lyrics, a pitch ribbon that glows when you hit the note, and effects you can change any time.',
  ),
  _Beat(
    '03 — The stage',
    'Private first.',
    'Public when ready.',
    'Takes start private. Put the good ones on the Stage, collect likes, and follow the voices you love.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < _beats.length - 1) {
      await _pages.nextPage(
        duration: Motion.of(context, Motion.slow),
        curve: Motion.standard,
      );
      return;
    }
    await ref.read(onboardedProvider.notifier).complete();
    if (mounted) context.go(Routes.library);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _index == _beats.length - 1;
    return Scaffold(
      body: CueGlow(
        alignment: Alignment.bottomCenter,
        radius: 1.1,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.xs,
                  0,
                ),
                child: Row(
                  children: [
                    Text('UNSUNG', style: context.type.label),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        onPressed: () => unawaited(
                          _pages.animateToPage(
                            _beats.length - 1,
                            duration: Motion.of(context, Motion.slow),
                            curve: Motion.standard,
                          ),
                        ),
                        child: Text('SKIP', style: context.type.labelMuted),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _beats.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _BeatView(beat: _beats[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.lg,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _beats.length; i++)
                      AnimatedContainer(
                        duration: Motion.of(context, Motion.base),
                        curve: Motion.emphasized,
                        margin: const EdgeInsets.only(right: Space.xs),
                        width: i == _index ? Space.lg : Space.xs,
                        height: Space.xs,
                        decoration: BoxDecoration(
                          color: i == _index ? c.cue : c.raised,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                      ),
                    const Spacer(),
                    CueButton(
                      label: last ? "Let's sing" : 'Next',
                      icon: last
                          ? Icons.mic_rounded
                          : Icons.arrow_forward_rounded,
                      onTap: () => unawaited(_next()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeatView extends StatelessWidget {
  const _BeatView({required this.beat});

  final _Beat beat;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Space.xxxl),
          Text(beat.kicker.toUpperCase(), style: context.type.labelMuted),
          const SizedBox(height: Space.md),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${beat.lead} '),
                TextSpan(
                  text: beat.accent,
                  style: TextStyle(color: c.cue),
                ),
              ],
            ),
            style: context.type.hero,
          ),
          const SizedBox(height: Space.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxContentWidth),
            child: Text(beat.body, style: context.type.bodyMuted),
          ),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}
