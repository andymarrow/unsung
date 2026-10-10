import 'package:flutter/foundation.dart';
import 'package:unsung/features/links/domain/link.dart';

/// A well-known song suggested on an empty-feeling library. Only a link:
/// nothing is downloaded until the user taps it and brings it in.
@immutable
class Starter {
  const Starter(this.videoId, this.title, this.artist);

  final String videoId;
  final String title;
  final String artist;

  String get url => youTubeUrl(videoId);

  /// YouTube's own thumbnail for the official video.
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}

/// Sing-along classics, each its artist's official upload on YouTube.
const starters = <Starter>[
  Starter('fJ9rUzIMcZQ', 'Bohemian Rhapsody', 'Queen'),
  Starter('hLQl3WQQoQ0', 'Someone Like You', 'Adele'),
  Starter('1k8craCGpgs', "Don't Stop Believin'", 'Journey'),
  Starter('2Vv-BfVoq4g', 'Perfect', 'Ed Sheeran'),
  Starter('djV11Xbc914', 'Take On Me', 'a-ha'),
  Starter('4NRXx6U8ABQ', 'Blinding Lights', 'The Weeknd'),
  Starter('FTQbiNvZqaY', 'Africa', 'Toto'),
  Starter('LjhCEhWiKXk', 'Just the Way You Are', 'Bruno Mars'),
  Starter('YQHsXMglC9A', 'Hello', 'Adele'),
  Starter('dvgZkm1xWPE', 'Viva La Vida', 'Coldplay'),
  Starter('OPf0YbXqDm0', 'Uptown Funk', 'Mark Ronson ft. Bruno Mars'),
  Starter('RgKAFK5djSk', 'See You Again', 'Wiz Khalifa ft. Charlie Puth'),
];
