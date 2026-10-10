import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/toggle_chip.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';
import 'package:unsung/features/studio/domain/take.dart';
import 'package:unsung/features/studio/presentation/takes_controller.dart';

/// Opens the share flow for a saved take, or its post if already shared.
Future<void> shareTake(BuildContext context, WidgetRef ref, Take take) async {
  final repo = ref.read(socialRepositoryProvider);
  if (take.postId != null) {
    unawaited(context.push(Routes.postFor(take.postId!)));
    return;
  }
  if (!repo.configured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sharing isn't connected in this build yet. Your take is saved on this phone.")),
    );
    return;
  }
  if (repo.userId == null) {
    unawaited(context.push(Routes.signIn));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ShareSheet(take: take),
  );
}

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({required this.take, super.key});

  final Take take;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  final _caption = TextEditingController();
  TakeVisibility _visibility = TakeVisibility.private;
  bool _busy = false;
  String? _error;

  static const _captionMax = 280;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final post = await ref.read(shareActionsProvider).publish(widget.take, _visibility, _caption.text);
      await ref.read(takesProvider.notifier).upsert(
            widget.take.copyWith(postId: post.id, visibility: _visibility, caption: _caption.text.trim()),
          );
      unawaited(HapticFeedback.heavyImpact());
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      unawaited(router.push(Routes.postFor(post.id)));
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = toFailure(e).message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final public = _visibility == TakeVisibility.public;
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
          Text('Share ${widget.take.songTitle}', style: type.heading),
          const SizedBox(height: Space.md),
          TextField(
            controller: _caption,
            maxLength: _captionMax,
            maxLines: 3,
            minLines: 1,
            style: type.body,
            decoration: const InputDecoration(hintText: 'Say something about this take'),
          ),
          const SizedBox(height: Space.sm),
          Text('WHO CAN HEAR IT', style: type.labelMuted),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              ToggleChip(
                label: 'Only me',
                selected: !public,
                onTap: () => setState(() => _visibility = TakeVisibility.private),
              ),
              const SizedBox(width: Space.xs),
              ToggleChip(
                label: 'Everyone',
                selected: public,
                onTap: () => setState(() => _visibility = TakeVisibility.public),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            public
                ? 'Goes on the Stage now. You can make it private again any time.'
                : 'Uploads to your profile where only you can hear it. Go public whenever you’re ready.',
            style: type.rowMeta,
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.sm),
            Text(_error!, style: type.rowMeta.copyWith(color: context.colors.cue)),
          ],
          const SizedBox(height: Space.lg),
          CueButton(
            label: public ? 'Put it on the Stage' : 'Upload privately',
            icon: public ? Icons.podcasts_rounded : Icons.lock_rounded,
            expand: true,
            busy: _busy,
            onTap: () => unawaited(_publish()),
          ),
        ],
      ),
    );
  }
}
