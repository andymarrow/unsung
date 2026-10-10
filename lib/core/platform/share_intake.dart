import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text shared into the app from other apps (Share → Unsung), via the
/// unsung/share channel in MainActivity.
class ShareIntake {
  ShareIntake([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('unsung/share') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) {
        _shared.add(call.arguments as String);
      }
    });
  }

  final MethodChannel _channel;
  final _shared = StreamController<String>.broadcast();

  /// What launched the app, if it was a share. Returned once.
  Future<String?> initialText() async {
    try {
      return await _channel.invokeMethod<String>('initialText');
    } on MissingPluginException {
      return null; // Tests and platforms without the channel.
    } on PlatformException {
      return null;
    }
  }

  /// Shares that arrive while the app is running.
  Stream<String> get shared => _shared.stream;

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_shared.close());
  }
}

final shareIntakeProvider = Provider<ShareIntake>((ref) {
  final intake = ShareIntake();
  ref.onDispose(intake.dispose);
  return intake;
});
