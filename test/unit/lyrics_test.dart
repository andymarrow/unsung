import 'package:flutter_test/flutter_test.dart';
import 'package:unsung/features/lyrics/domain/lyrics.dart';

void main() {
  group('Lyrics.parse', () {
    test('reads line-timed LRC and sorts lines', () {
      final l = Lyrics.parse(
        '[ti:Song]\n[00:12.50] Second line here\n[00:05.00] First line\n',
        songDuration: const Duration(seconds: 30),
      );
      expect(l.synced, isTrue);
      expect(l.lines.map((x) => x.text), ['First line', 'Second line here']);
      expect(l.lines.first.start, const Duration(seconds: 5));
      expect(l.lines.first.end, const Duration(milliseconds: 12500));
      expect(l.lines.last.end, const Duration(seconds: 30));
    });

    test('expands repeated timestamps on one line', () {
      final l = Lyrics.parse('[00:01.00][00:09.00]Chorus');
      expect(l.lines.length, 2);
      expect(l.lines[1].start, const Duration(seconds: 9));
    });

    test('uses enhanced word timing when present', () {
      final l = Lyrics.parse('[00:10.00]<00:10.00>Hello <00:11.20>world');
      final words = l.lines.single.words;
      expect(words.map((w) => w.text), ['Hello', 'world']);
      expect(words[1].start, const Duration(milliseconds: 11200));
    });

    test('estimates word timing within the line', () {
      final l = Lyrics.parse('[00:00.00]aa bb\n[00:10.00]next');
      final line = l.lines.first;
      expect(line.words[0].start, Duration.zero);
      expect(line.words[1].start, greaterThan(Duration.zero));
      expect(line.words[1].start, lessThan(const Duration(seconds: 10)));
      expect(line.wordFill(0, const Duration(seconds: 1)), greaterThan(0));
    });

    test('plain text becomes unsynced lyrics', () {
      final l = Lyrics.parse('One\nTwo\n\nThree');
      expect(l.synced, isFalse);
      expect(l.lines.length, 3);
      expect(l.indexAt(const Duration(seconds: 3)), -1);
    });

    test('indexAt finds the active line', () {
      final l = Lyrics.parse('[00:01.00]a\n[00:02.00]b\n[00:03.00]c');
      expect(l.indexAt(Duration.zero), -1);
      expect(l.indexAt(const Duration(milliseconds: 2500)), 1);
      expect(l.indexAt(const Duration(seconds: 9)), 2);
    });
  });
}
