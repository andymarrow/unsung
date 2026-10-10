import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/features/links/domain/link.dart';

void main() {
  test('finds the video id in every common link shape', () {
    const id = 'dQw4w9WgXcQ';
    for (final text in [
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&t=42s&list=PL123',
      'https://m.youtube.com/watch?v=$id',
      'https://music.youtube.com/watch?v=$id&feature=share',
      'https://youtu.be/$id?si=abc',
      'youtu.be/$id',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/live/$id',
      'Listen to this!! https://youtu.be/$id it slaps',
    ]) {
      expect(youTubeIdFrom(text), id, reason: text);
    }
  });

  test('rejects things that are not one video', () {
    for (final text in [
      '',
      'hello',
      'https://vimeo.com/123456',
      'https://www.youtube.com/playlist?list=PL123',
      'https://www.youtube.com/@channel',
      'https://www.youtube.com/watch?v=short',
      'https://notyoutube.com/watch?v=dQw4w9WgXcQ',
    ]) {
      expect(youTubeIdFrom(text), isNull, reason: text);
    }
  });

  test('cleans video titles into song titles', () {
    expect(
      cleanTitle('The Lanterns - Paper Moons (Official Music Video) [4K]'),
      (title: 'Paper Moons', artist: 'The Lanterns'),
    );
    expect(
      cleanTitle('Paper Moons (Lyric Video)', channel: 'The Lanterns - Topic'),
      (title: 'Paper Moons', artist: 'The Lanterns'),
    );
    expect(
      cleanTitle('Harbour Lights', channel: 'SofiaRenVEVO'),
      (title: 'Harbour Lights', artist: 'SofiaRen'),
    );
    expect(cleanTitle('(Official Video)'),
        (title: '(Official Video)', artist: null));
  });

  test('preview ids and urls', () {
    const p = LinkPreview(
        videoId: 'dQw4w9WgXcQ', title: 't', duration: Duration.zero);
    expect(p.songId, 'yt-dQw4w9WgXcQ');
    expect(p.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
  });
}
