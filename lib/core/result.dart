/// Typed failures shown to the user. Each carries human copy.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Short, human, actionable.
  final String message;

  @override
  String toString() => message;
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {this.permanentlyDenied = false});

  /// True when the user must enable it in system settings.
  final bool permanentlyDenied;
}

final class OfflineFailure extends AppFailure {
  const OfflineFailure([
    super.message = "You're offline. This needs a connection.",
  ]);
}

final class NotConfiguredFailure extends AppFailure {
  const NotConfiguredFailure(super.message);
}

final class AudioFailure extends AppFailure {
  const AudioFailure(super.message);
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// A pasted link that can't become a song (not YouTube, private, too long…).
final class LinkFailure extends AppFailure {
  const LinkFailure(super.message);
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure() : super('Cancelled.');
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Something went wrong. Try again.']);
}

/// Maps anything thrown into an [AppFailure].
AppFailure toFailure(Object error) {
  if (error is AppFailure) return error;
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return const OfflineFailure();
  }
  return const UnknownFailure();
}
