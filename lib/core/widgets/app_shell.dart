import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/pressable.dart';

/// Shell with the "tape deck" bottom bar: two tabs, the Sing button, two tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, required this.onSing, super.key});

  final StatefulNavigationShell shell;
  final VoidCallback onSing;

  static const _tabs = [
    (icon: Icons.library_music_outlined, active: Icons.library_music_rounded, label: 'Library'),
    (icon: Icons.podcasts_outlined, active: Icons.podcasts_rounded, label: 'Stage'),
    (icon: Icons.graphic_eq_outlined, active: Icons.graphic_eq_rounded, label: 'Takes'),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Me'),
  ];

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

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

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.stage,
          border: Border(top: BorderSide(color: c.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: Sizes.navBar,
            child: Row(
              children: [
                tab(0),
                tab(1),
                Expanded(child: Center(child: SingButton(onTap: onSing))),
                tab(2),
                tab(3),
              ],
            ),
          ),
        ),
      ),
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
              style: selected ? context.type.label : context.type.labelMuted,
            ),
            const SizedBox(height: Space.xxs),
            AnimatedContainer(
              duration: d,
              curve: Motion.emphasized,
              width: selected ? Space.md : 0,
              height: Sizes.stroke,
              decoration: BoxDecoration(
                color: c.cue,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The record affordance: a cue disc with a soft glow.
class SingButton extends StatelessWidget {
  const SingButton({required this.onTap, this.size = Sizes.recordButton, super.key});

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
