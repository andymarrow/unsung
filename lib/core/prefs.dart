import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

abstract final class PrefKeys {
  static const onboarded = 'onboarded.v1';
  static const themeMode = 'theme.mode';
  static const lyricsOffsetPrefix = 'lyrics.offset.';
}

/// Whether the user has finished onboarding.
final onboardedProvider = NotifierProvider<OnboardedNotifier, bool>(
  OnboardedNotifier.new,
);

class OnboardedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getBool(PrefKeys.onboarded) ?? false;

  Future<void> complete() async {
    await ref.read(prefsProvider).setBool(PrefKeys.onboarded, true);
    state = true;
  }
}
