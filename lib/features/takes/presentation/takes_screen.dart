import 'package:flutter/material.dart';
import 'package:unsung/core/widgets/state_views.dart';

class TakesScreen extends StatelessWidget {
  const TakesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          kicker: 'Takes',
          title: 'Your takes',
          message: 'Everything you record lands here first, private.',
        ),
      ),
    );
  }
}
