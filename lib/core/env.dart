/// Build-time configuration passed with --dart-define. Nothing secret lives in
/// the repo; the anon key is a public client key protected by row-level
/// security on the server.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional server for high-quality (ML) vocal separation.
  static const separationApiUrl = String.fromEnvironment('SEPARATION_API_URL');

  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasStudioSeparation => separationApiUrl.isNotEmpty;

  /// Free, open synced-lyrics database.
  static const lyricsApi = 'https://lrclib.net/api';

  static const userAgent = 'Unsung/0.2 (https://github.com/andymarrow/unsung)';
}
