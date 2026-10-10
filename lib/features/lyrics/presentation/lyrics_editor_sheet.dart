import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/features/library/domain/song.dart';
import 'package:unsung/features/lyrics/data/lyrics_repository.dart';

Future<void> showLyricsEditor(BuildContext context, Song song, {String initial = ''}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LyricsEditorSheet(song: song, initial: initial),
  );
}

/// Paste lyrics (plain or LRC). Saved on the device with the song.
class LyricsEditorSheet extends ConsumerStatefulWidget {
  const LyricsEditorSheet({required this.song, this.initial = '', super.key});

  final Song song;
  final String initial;

  @override
  ConsumerState<LyricsEditorSheet> createState() => _LyricsEditorSheetState();
}

class _LyricsEditorSheetState extends ConsumerState<LyricsEditorSheet> {
  late final _text = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref.read(lyricsRepositoryProvider).saveOwn(widget.song, _text.text);
    ref.invalidate(lyricsProvider(widget.song));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
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
          Text('Lyrics for ${widget.song.title}', style: type.heading),
          const SizedBox(height: Space.xs),
          Text(
            'Paste plain lyrics, or LRC with [mm:ss.xx] timestamps so they follow the music.',
            style: type.rowMeta,
          ),
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: TextField(
              controller: _text,
              autofocus: widget.initial.isEmpty,
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              style: type.body,
              decoration: const InputDecoration(
                hintText: '[00:12.40] First line\n[00:16.90] Second line',
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          ListenableBuilder(
            listenable: _text,
            builder: (context, _) => CueButton(
              label: 'Save lyrics',
              icon: Icons.check_rounded,
              expand: true,
              busy: _saving,
              onTap: _text.text.trim().isEmpty ? null : () => unawaited(_save()),
            ),
          ),
        ],
      ),
    );
  }
}
