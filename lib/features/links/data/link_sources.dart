import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:unsung/core/env.dart';
import 'package:unsung/core/result.dart';
import 'package:unsung/features/links/domain/link.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Longest song a link may bring in. Matches the server's default.
const maxLinkDuration = Duration(minutes: 15);

/// Reads a YouTube link and fetches its audio. Two implementations: the
/// Studio server (yt-dlp, the most reliable) and on the phone (no server).
abstract interface class LinkSource {
  Future<LinkPreview> resolve(String videoId);

  /// Writes the audio to [out]. [onProgress] gets 0..1, or null while the
  /// size is unknown (the server preparing the file).
  Future<void> download(
    LinkPreview preview,
    File out, {
    required void Function(double? progress) onProgress,
    required bool Function() cancelled,
  });
}

/// Fetches through the Studio server's /link endpoints (server/app.py).
class ServerLinkSource implements LinkSource {
  ServerLinkSource(this._client, {String? baseUrl})
      : _base = baseUrl ?? Env.separationApiUrl;

  final http.Client _client;
  final String _base;

  Uri _uri(String path, String videoId) => Uri.parse('$_base$path').replace(
        queryParameters: {'url': youTubeUrl(videoId)},
      );

  @override
  Future<LinkPreview> resolve(String videoId) async {
    final r = await _client.get(_uri('/link', videoId), headers: {
      'User-Agent': Env.userAgent
    }).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw _failure(r.statusCode, r.body);
    final json = jsonDecode(r.body) as Map<String, Object?>;
    final rawTitle = json['title'] as String? ?? 'Untitled';
    final rawArtist = json['artist'] as String?;
    final cleaned = cleanTitle(rawTitle, channel: rawArtist);
    return LinkPreview(
      videoId: videoId,
      title: cleaned.title,
      artist: cleaned.artist,
      duration:
          Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      thumbnailUrl: json['thumbnail'] as String?,
    );
  }

  @override
  Future<void> download(
    LinkPreview preview,
    File out, {
    required void Function(double? progress) onProgress,
    required bool Function() cancelled,
  }) async {
    onProgress(null);
    final request = http.Request('GET', _uri('/link/audio', preview.videoId))
      ..headers['User-Agent'] = Env.userAgent;
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw _failure(
          response.statusCode, await response.stream.bytesToString());
    }
    await _pipe(
        response.stream, out, response.contentLength, onProgress, cancelled);
  }

  AppFailure _failure(int status, String body) {
    String? detail;
    try {
      detail = (jsonDecode(body) as Map<String, Object?>)['detail'] as String?;
    } on Object {
      detail = null;
    }
    if (status >= 400 && status < 500 && detail != null) {
      return LinkFailure('$detail.');
    }
    // Not about the link: let the next source (the phone) have a go.
    return const UnknownFailure(
        "The studio server couldn't fetch this link. Try again in a bit.");
  }
}

/// Fetches on the phone with youtube_explode_dart. Works without a server,
/// but YouTube changes often, so the server is preferred when there is one.
class DeviceLinkSource implements LinkSource {
  DeviceLinkSource([yt.YoutubeExplode Function()? create])
      : _create = create ?? yt.YoutubeExplode.new;

  final yt.YoutubeExplode Function() _create;

  /// Clients that serve audio without a JavaScript challenge.
  static const _clients = [
    yt.YoutubeApiClient.androidSdkless,
    yt.YoutubeApiClient.androidVr,
  ];

  @override
  Future<LinkPreview> resolve(String videoId) async {
    final client = _create();
    try {
      final video = await client.videos.get(videoId);
      if (video.isLive || video.duration == null) {
        throw const LinkFailure("Live streams can't be turned into karaoke.");
      }
      final cleaned = cleanTitle(video.title, channel: video.author);
      return LinkPreview(
        videoId: videoId,
        title: cleaned.title,
        artist: cleaned.artist,
        duration: video.duration!,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } on yt.VideoUnavailableException {
      throw const LinkFailure('This video is private or unavailable.');
    } on yt.YoutubeExplodeException {
      throw const LinkFailure("YouTube didn't answer for this link.");
    } finally {
      client.close();
    }
  }

  @override
  Future<void> download(
    LinkPreview preview,
    File out, {
    required void Function(double? progress) onProgress,
    required bool Function() cancelled,
  }) async {
    onProgress(null);
    final client = _create();
    try {
      final manifest = await client.videos.streams
          .getManifest(preview.videoId, ytClients: _clients);
      final audio = manifest.audioOnly;
      if (audio.isEmpty) {
        throw const LinkFailure(
            "YouTube didn't offer audio for this one on the phone.");
      }
      // AAC in MP4 decodes everywhere; fall back to whatever is best.
      final mp4 =
          audio.where((s) => s.container == yt.StreamContainer.mp4).toList();
      final info = (mp4.isNotEmpty ? mp4 : audio.toList()).reduce(
          (a, b) => a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b);
      await _pipe(client.videos.streams.get(info), out, info.size.totalBytes,
          onProgress, cancelled);
    } on yt.VideoUnavailableException {
      throw const LinkFailure('This video is private or unavailable.');
    } on yt.YoutubeExplodeException {
      throw const LinkFailure(
          'YouTube blocked the download on the phone. A Studio server can fetch it.');
    } finally {
      client.close();
    }
  }
}

Future<void> _pipe(
  Stream<List<int>> stream,
  File out,
  int? total,
  void Function(double?) onProgress,
  bool Function() cancelled,
) async {
  final sink = out.openWrite();
  var received = 0;
  try {
    await for (final chunk in stream) {
      if (cancelled()) throw const CancelledFailure();
      sink.add(chunk);
      received += chunk.length;
      if (total != null && total > 0) {
        onProgress((received / total).clamp(0, 1));
      }
    }
  } finally {
    await sink.close();
  }
  if (received == 0) {
    throw const LinkFailure('The download came back empty. Try again.');
  }
}
