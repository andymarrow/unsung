import 'package:flutter/material.dart';
import 'package:unsung/core/widgets/state_views.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          kicker: 'Me',
          title: 'Your profile',
          message: 'Sign in to claim a name and share takes.',
        ),
      ),
    );
  }
}
