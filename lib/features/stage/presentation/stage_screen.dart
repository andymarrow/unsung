import 'package:flutter/material.dart';
import 'package:unsung/core/widgets/state_views.dart';

class StageScreen extends StatelessWidget {
  const StageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          kicker: 'Stage',
          title: 'The stage',
          message: 'Public takes from the people you follow and everyone else.',
        ),
      ),
    );
  }
}
