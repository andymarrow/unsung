import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/entrance.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/core/widgets/toggle_chip.dart';
import 'package:unsung/features/karaoke/presentation/karaoke_controller.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/library/presentation/library_controller.dart';
import 'package:unsung/features/library/presentation/song_row.dart';
import 'package:unsung/features/library/presentation/song_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from system settings: re-check access.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(libraryProvider).valueOrNull is LibraryNeedsAccess) {
      unawaited(ref.read(libraryProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (library) {
          AsyncData(value: LibraryNeedsAccess(:final blocked)) => _NeedsAccess(
              blocked: blocked,
              onAllow: () =>
                  unawaited(ref.read(libraryProvider.notifier).requestAccess()),
            ),
          AsyncData(value: LibraryLoaded(:final songs)) => songs.isEmpty
              ? EmptyState(
                  icon: Icons.music_off_rounded,
                  kicker: 'Library',
                  title: 'No songs on this phone yet',
                  message:
                      'Unsung uses the music files saved on your device (MP3, M4A, FLAC…). Download or copy some songs, then pull to refresh.',
                  actionLabel: 'Check again',
                  onAction: () =>
                      unawaited(ref.read(libraryProvider.notifier).refresh()),
                )
              : _SongList(songs: songs),
          AsyncError(:final error) => ErrorState(
              failure: toFailure(error),
              onRetry: () =>
                  unawaited(ref.read(libraryProvider.notifier).refresh()),
            ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(subtitle: 'READING YOUR MUSIC…'),
        Expanded(child: RowSkeletonList()),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Library', style: context.type.title),
          const SizedBox(height: Space.xxs),
          Text(subtitle, style: context.type.labelMuted),
        ],
      ),
    );
  }
}

class _NeedsAccess extends StatelessWidget {
  const _NeedsAccess({required this.blocked, required this.onAllow});

  final bool blocked;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.library_music_rounded,
      kicker: 'Your library',
      title: 'Let Unsung see your music',
      message: blocked
          ? 'Music access is turned off for Unsung. Turn on "Music and audio" in settings and come back. Your files never leave your phone unless you share a take.'
          : 'Unsung reads the songs saved on this phone so you can turn them into karaoke. Your files never leave your phone unless you share a take.',
      actionLabel: blocked ? 'Open settings' : 'Allow music access',
      onAction: onAllow,
    );
  }
}

class _SongList extends ConsumerWidget {
  const _SongList({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(libraryQueryProvider);
    final ready = ref.watch(karaokeTracksProvider).valueOrNull ?? const {};
    final text = query.text.trim().toLowerCase();
    final visible = [
      for (final s in songs)
        if ((query.filter == LibraryFilter.all || ready.containsKey(s.id)) &&
            (text.isEmpty || s.searchText.contains(text)))
          s,
    ];
    final readyCount = songs.where((s) => ready.containsKey(s.id)).length;

    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              subtitle: '${songs.length} SONGS · $readyCount READY TO SING',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: TextField(
                onChanged: ref.read(libraryQueryProvider.notifier).setText,
                textInputAction: TextInputAction.search,
                style: context.type.body,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.colors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.xs,
              ),
              child: Row(
                children: [
                  ToggleChip(
                    label: 'All',
                    count: songs.length,
                    selected: query.filter == LibraryFilter.all,
                    onTap: () => ref
                        .read(libraryQueryProvider.notifier)
                        .setFilter(LibraryFilter.all),
                  ),
                  const SizedBox(width: Space.xs),
                  ToggleChip(
                    label: 'Ready',
                    count: readyCount,
                    selected: query.filter == LibraryFilter.ready,
                    onTap: () => ref
                        .read(libraryQueryProvider.notifier)
                        .setFilter(LibraryFilter.ready),
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: query.filter == LibraryFilter.ready && text.isEmpty
                  ? const EmptyState(
                      kicker: 'Ready to sing',
                      title: 'Nothing unsung yet',
                      message:
                          'Tap any song and choose "Unsing it". It takes about as long as a cup of tea, and you only do it once.',
                    )
                  : EmptyState(
                      kicker: 'Search',
                      title: 'No match for "${query.text.trim()}"',
                      message: 'Try a shorter word, or the artist name.',
                    ),
            )
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) => Entrance(
                index: i,
                child: SongRow(
                  song: visible[i],
                  onTap: () => unawaited(showSongSheet(context, visible[i])),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
        ],
      ),
    );
  }
}

/// Exposed for the Sing button: pick a ready song quickly.
class ReadySongPicker extends ConsumerWidget {
  const ReadySongPicker({required this.onPick, super.key});

  final ValueChanged<Song> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(karaokeTracksProvider).valueOrNull ?? const {};
    final songs =
        ref.watch(songsProvider).where((s) => ready.containsKey(s.id)).toList();
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nothing ready yet', style: context.type.heading),
            const SizedBox(height: Space.xs),
            Text(
              'Pick a song in your Library and unsing it first.',
              style: context.type.bodyMuted,
            ),
            const SizedBox(height: Space.lg),
            QuietButton(
              label: 'Got it',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: Space.lg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.sm,
          ),
          child: Text('What are we singing?', style: context.type.heading),
        ),
        for (final s in songs) SongRow(song: s, onTap: () => onPick(s)),
      ],
    );
  }
}
