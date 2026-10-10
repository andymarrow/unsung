import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum Access { granted, denied, blocked }

/// Runtime permissions, asked at the moment they're needed.
class Permissions {
  const Permissions();

  static Access _fold(Iterable<PermissionStatus> statuses) {
    if (statuses.any((s) => s.isGranted || s.isLimited)) return Access.granted;
    if (statuses.any((s) => s.isPermanentlyDenied)) return Access.blocked;
    return Access.denied;
  }

  /// READ_MEDIA_AUDIO on Android 13+, storage below.
  Future<Access> music() async =>
      _fold([await Permission.audio.status, await Permission.storage.status]);

  Future<Access> requestMusic() async {
    final r = await [Permission.audio, Permission.storage].request();
    return _fold(r.values);
  }

  Future<Access> microphone() async => _fold([await Permission.microphone.status]);

  Future<Access> requestMicrophone() async =>
      _fold([await Permission.microphone.request()]);

  Future<bool> openSettings() => openAppSettings();
}

final permissionsProvider = Provider<Permissions>((_) => const Permissions());
