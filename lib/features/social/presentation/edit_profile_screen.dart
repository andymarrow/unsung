import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/core/widgets/state_views.dart';
import 'package:unsung/features/social/data/social_repository.dart';
import 'package:unsung/features/social/domain/models.dart';
import 'package:unsung/features/social/presentation/social_providers.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: switch (me) {
        AsyncData(value: final Profile p) => _Form(profile: p),
        AsyncData() => const EmptyState(
            kicker: 'Profile',
            title: 'Signed out',
            message: 'Sign in to edit your profile.',
          ),
        AsyncError(:final error) => ErrorState(
            failure: toFailure(error),
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
        _ => const RowSkeletonList(count: 3),
      },
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _key = GlobalKey<FormState>();
  late final _handle = TextEditingController(text: widget.profile.handle);
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _bio = TextEditingController(text: widget.profile.bio);
  bool _busy = false;

  static final _handlePattern = RegExp(r'^[a-z0-9_]{3,24}$');
  static const _nameMax = 48;
  static const _bioMax = 160;

  @override
  void dispose() {
    _handle.dispose();
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(socialRepositoryProvider).updateProfile(
            handle: _handle.text,
            displayName: _name.text,
            bio: _bio.text,
          );
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(profileProvider(widget.profile.id));
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(toFailure(e).message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          Text('HANDLE', style: type.labelMuted),
          const SizedBox(height: Space.xs),
          TextFormField(
            controller: _handle,
            style: type.body,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
              TextInputFormatter.withFunction(
                  (_, v) => v.copyWith(text: v.text.toLowerCase())),
            ],
            decoration: const InputDecoration(prefixText: '@'),
            validator: (v) => _handlePattern.hasMatch(v ?? '')
                ? null
                : '3–24 characters: letters, numbers, underscores.',
          ),
          const SizedBox(height: Space.lg),
          Text('NAME', style: type.labelMuted),
          const SizedBox(height: Space.xs),
          TextFormField(
            controller: _name,
            style: type.body,
            maxLength: _nameMax,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: Space.md),
          Text('BIO', style: type.labelMuted),
          const SizedBox(height: Space.xs),
          TextFormField(
            controller: _bio,
            style: type.body,
            maxLength: _bioMax,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Shower tenor. Car-ride soprano.'),
          ),
          const SizedBox(height: Space.lg),
          CueButton(
            label: 'Save',
            icon: Icons.check_rounded,
            expand: true,
            busy: _busy,
            onTap: () => unawaited(_save()),
          ),
        ],
      ),
    );
  }
}
