import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/router/spotlight_page.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/ambient_light.dart';
import 'package:unsung/core/widgets/glass.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Shell with the "tape deck" bottom bar: two tabs, the Sing button, two tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, required this.onSing, super.key});

  final StatefulNavigationShell shell;
  final VoidCallback onSing;

  static const _tabs = [
    (
      icon: Icons.library_music_outlined,
      active: Icons.library_music_rounded,
      label: 'Library'
    ),
    (
      icon: Icons.podcasts_outlined,
      active: Icons.podcasts_rounded,
      label: 'Stage'
    ),
    (
      icon: Icons.graphic_eq_outlined,
      active: Icons.graphic_eq_rounded,
      label: 'Takes'
    ),
    (
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Me'
    ),
  ];

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tab(int i) {
      final t = _tabs[i];
      return Expanded(
        child: _TabItem(
          icon: t.icon,
          activeIcon: t.active,
          label: t.label,
          selected: shell.currentIndex == i,
          onTap: () => _go(i),
        ),
      );
    }

    // Bar slots: two tabs, Sing, two tabs. The lens sits under a tab.
    final current = shell.currentIndex;
    final lensSlot = current < 2 ? current : current + 1;

    return Scaffold(
      backgroundColor: c.stage,
      // Content scrolls under the floating bar; Scaffold adds the bar's
      // height to the body's bottom padding.
      extendBody: true,
      body: AmbientLight(child: shell),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          Sizes.glassBarInset,
          0,
          Sizes.glassBarInset,
          Sizes.glassBarInset,
        ),
        child: GlassSurface(
          radius: Radii.full,
          blur: Blurs.bar,
          child: SizedBox(
            height: Sizes.glassBar,
            child: LayoutBuilder(
              builder: (context, box) {
                final slot = box.maxWidth / 5;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Motion.of(context, Motion.slow),
                      curve: Motion.emphasized,
                      left: slot * lensSlot + Space.xxs,
                      top: Space.xxs,
                      bottom: Space.xxs,
                      width: slot - Space.xs,
                      child: const _Lens(),
                    ),
                    Row(
                      children: [
                        tab(0),
                        tab(1),
                        Expanded(
                          child: Center(child: SingButton(onTap: onSing)),
                        ),
                        tab(2),
                        tab(3),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected tab's lens: a brighter pill of glass that glides between
/// tabs, like a drop of water moving under the bar.
class _Lens extends StatelessWidget {
  const _Lens();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassSurface(
      radius: Radii.full,
      frost: false,
      tint: c.glassSheen,
      child: const SizedBox.expand(),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = Motion.of(context, Motion.base);
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        haptic: PressHaptic.selection,
        semanticLabel: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: d,
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: selected ? c.ink : c.inkMuted,
                size: Sizes.icon,
              ),
            ),
            const SizedBox(height: Space.xxs),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: context.type.nav
                  .copyWith(color: selected ? c.ink : c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The record affordance: a cue disc with a soft glow.
class SingButton extends StatelessWidget {
  const SingButton(
      {required this.onTap, this.size = Sizes.recordButton, super.key});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.light,
      semanticLabel: 'Sing a song',
      child: Hero(
        tag: 'spotlight',
        flightShuttleBuilder: spotlightShuttle,
        child: Container(
          width: size,
          height: size * 0.72,
          decoration: BoxDecoration(
            color: c.cue,
            borderRadius: BorderRadius.circular(Radii.full),
            boxShadow: [
              BoxShadow(
                color: c.cue.withValues(alpha: Alphas.glowStrong),
                blurRadius: Space.lg,
              ),
            ],
          ),
          child: Icon(Icons.mic_rounded, color: c.onCue, size: Sizes.iconLg),
        ),
      ),
    );
  }
}
