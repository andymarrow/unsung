import 'package:flutter/foundation.dart';

/// One word with its start time (estimated when the source has line timing only).
@immutable
class LyricWord {
  const LyricWord(this.text, this.start);

  final String text;
  final Duration start;
}

@immutable
class LyricLine {
  const LyricLine({
    required this.start,
    required this.end,
    required this.words,
  });

  final Duration start;
  final Duration end;
  final List<LyricWord> words;

  String get text => words.map((w) => w.text).join(' ');

  bool get isInstrumentalBreak => words.isEmpty;

  /// 0..1 progress of [position] through this line.
  double progressAt(Duration position) {
    final span = (end - start).inMicroseconds;
    if (span <= 0) return position >= start ? 1 : 0;
    return ((position - start).inMicroseconds / span).clamp(0.0, 1.0);
  }

  /// 0..1 fill for word [i] at [position].
  double wordFill(int i, Duration position) {
    final s = words[i].start;
    final e = i + 1 < words.length ? words[i + 1].start : end;
    final span = (e - s).inMicroseconds;
    if (position <= s) return 0;
    if (span <= 0 || position >= e) return 1;
    return (position - s).inMicroseconds / span;
  }
}

@immutable
class Lyrics {
  const Lyrics({required this.lines, required this.synced, this.source});

  /// Parses LRC, including enhanced word timing (`<mm:ss.xx>`). Text without
  /// any timestamps becomes unsynced lyrics.
  factory Lyrics.parse(String raw, {Duration? songDuration, String? source}) {
    final lineTag = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final wordTag = RegExp(r'<(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?>');
    final timed = <(Duration, String)>[];
    final plain = <String>[];

    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final tags = lineTag.allMatches(rawLine).toList();
      if (tags.isEmpty) {
        final t = rawLine.trim();
        if (t.isNotEmpty && !RegExp(r'^\[[a-z]+:').hasMatch(t)) plain.add(t);
        continue;
      }
      final text = rawLine.substring(tags.last.end).trim();
      for (final tag in tags) {
        timed.add((_time(tag), text));
      }
    }

    if (timed.isEmpty) {
      return Lyrics(
        synced: false,
        source: source,
        lines: [
          for (final p in plain)
            LyricLine(
              start: Duration.zero,
              end: Duration.zero,
              words: [for (final w in _words(p)) LyricWord(w, Duration.zero)],
            ),
        ],
      );
    }

    timed.sort((a, b) => a.$1.compareTo(b.$1));
    final lines = <LyricLine>[];
    for (var i = 0; i < timed.length; i++) {
      final (start, text) = timed[i];
      final next = i + 1 < timed.length
          ? timed[i + 1].$1
          : (songDuration != null && songDuration > start
              ? songDuration
              : start + const Duration(seconds: 5));
      lines.add(
        LyricLine(
            start: start,
            end: next,
            words: _timedWords(text, start, next, wordTag)),
      );
    }
    return Lyrics(lines: lines, synced: true, source: source);
  }

  static const empty = Lyrics(lines: [], synced: false);

  final List<LyricLine> lines;
  final bool synced;

  /// Where the lyrics came from (e.g. "LRCLIB"), for attribution.
  final String? source;

  bool get isEmpty => lines.every((l) => l.isInstrumentalBreak);

  /// Index of the line being sung at [position], or -1 before the first.
  int indexAt(Duration position) {
    if (!synced) return -1;
    var lo = 0;
    var hi = lines.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].start <= position) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  static Duration _time(RegExpMatch m) {
    final frac = m.group(3) ?? '0';
    final ms = switch (frac.length) {
      1 => int.parse(frac) * 100,
      2 => int.parse(frac) * 10,
      _ => int.parse(frac.substring(0, 3)),
    };
    return Duration(
      minutes: int.parse(m.group(1)!),
      seconds: int.parse(m.group(2)!),
      milliseconds: ms,
    );
  }

  static List<String> _words(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Uses word tags when present; otherwise spreads words across the line by
  /// character count (longer words take longer to sing), ending at 85% of the
  /// line so the last word isn't still filling during the gap.
  static List<LyricWord> _timedWords(
    String text,
    Duration start,
    Duration end,
    RegExp wordTag,
  ) {
    if (wordTag.hasMatch(text)) {
      final words = <LyricWord>[];
      var cursor = start;
      final parts = text.split(wordTag);
      final tags = wordTag.allMatches(text).toList();
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) cursor = _time(tags[i - 1]);
        for (final w in _words(parts[i])) {
          words.add(LyricWord(w, cursor));
        }
      }
      return words;
    }
    final words = _words(text);
    if (words.isEmpty) return const [];
    final total = words.fold<int>(0, (n, w) => n + w.length + 1);
    final span = (end - start).inMicroseconds * 0.85;
    final out = <LyricWord>[];
    var acc = 0;
    for (final w in words) {
      final offset = Duration(microseconds: (span * acc / total).round());
      out.add(LyricWord(w, start + offset));
      acc += w.length + 1;
    }
    return out;
  }
}
