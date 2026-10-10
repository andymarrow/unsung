import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/core/router/routes.dart';
import 'package:unsung/core/theme/app_theme.dart';
import 'package:unsung/core/theme/motion.dart';
import 'package:unsung/core/theme/tokens.dart';
import 'package:unsung/core/widgets/backdrop.dart';
import 'package:unsung/core/widgets/buttons.dart';
import 'package:unsung/features/social/data/social_repository.dart';

/// Passwordless sign-in: email → 6-digit code.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _codeLength = 6;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _error = toFailure(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        if (!_emailPattern.hasMatch(_email.text.trim())) {
          throw const AuthFailure("That email doesn't look right.");
        }
        await ref.read(socialRepositoryProvider).sendCode(_email.text);
        if (mounted) setState(() => _codeSent = true);
      });

  Future<void> _verify() => _run(() async {
        await ref
            .read(socialRepositoryProvider)
            .verifyCode(_email.text, _code.text);
        unawaited(HapticFeedback.mediumImpact());
        if (mounted) context.go(Routes.me);
      });

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(),
      body: Backdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(Space.gutter),
            children: [
              Text('SIGN IN', style: type.labelMuted),
              const SizedBox(height: Space.xs),
              Text(
                  _codeSent
                      ? 'Check your inbox'
                      : 'Claim your name on the Stage',
                  style: type.title),
              const SizedBox(height: Space.sm),
              Text(
                _codeSent
                    ? 'We sent a 6-digit code to ${_email.text.trim()}. It expires in an hour.'
                    : 'No passwords. We email you a code each time you sign in.',
                style: type.bodyMuted,
              ),
              const SizedBox(height: Space.lg),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.base),
                child: _codeSent
                    ? TextField(
                        key: const ValueKey('code'),
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: _codeLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: type.title.copyWith(letterSpacing: Space.sm),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                            hintText: '000000', counterText: ''),
                        onChanged: (v) {
                          if (v.length == _codeLength) unawaited(_verify());
                        },
                      )
                    : TextField(
                        key: const ValueKey('email'),
                        controller: _email,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.send,
                        style: type.body,
                        decoration:
                            const InputDecoration(hintText: 'you@example.com'),
                        onSubmitted: (_) => unawaited(_send()),
                      ),
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.base),
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: Text(_error!,
                            style: type.rowMeta.copyWith(color: c.cue)),
                      ),
              ),
              const SizedBox(height: Space.lg),
              CueButton(
                label: _codeSent ? 'Verify' : 'Send code',
                icon: _codeSent
                    ? Icons.check_rounded
                    : Icons.mail_outline_rounded,
                expand: true,
                busy: _busy,
                onTap: () => unawaited(_codeSent ? _verify() : _send()),
              ),
              if (_codeSent) ...[
                const SizedBox(height: Space.sm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _code.clear();
                          }),
                  child: Text('USE A DIFFERENT EMAIL', style: type.labelMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
