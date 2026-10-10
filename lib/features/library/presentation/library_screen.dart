import 'package:flutter/material.dart';
import 'package:unsung/core/widgets/state_views.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: EmptyState(
          kicker: 'Library',
          title: 'Your library',
          message: 'Songs on this phone appear here, ready to unsing.',
        ),
      ),
    );
  }
}
