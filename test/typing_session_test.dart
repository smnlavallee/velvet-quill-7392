import 'package:flutter_test/flutter_test.dart';
import 'package:loremtype/engine/lorem_words.dart';
import 'package:loremtype/engine/typing_session.dart';

void main() {
  group('LoremWords', () {
    test('base corpus contains exactly 100 lowercase alphabetic words', () {
      expect(LoremWords.baseWords.length, 100);
      for (final word in LoremWords.baseWords) {
        expect(RegExp(r'^[a-z]+$').hasMatch(word), isTrue,
            reason: 'Expected lowercase alphabetic word, got "$word"');
      }
    });

    test('supports all presets up to 100 words deterministically', () {
      for (final count in LoremWords.wordCountPresets) {
        final first = LoremWords.generate(count: count);
        final second = LoremWords.generate(count: count);
        expect(first.length, count);
        expect(first, equals(second));
      }
    });

    test('punctuation option injects capitalization and punctuation marks', () {
      final words = LoremWords.generate(count: 10, includePunctuation: true);
      expect(words.first, 'Lorem');
      expect(words.last.endsWith('.'), isTrue);
      expect(
        words.any((w) => RegExp(r'[.,;:?!"]').hasMatch(w)),
        isTrue,
      );
    });

    test('numbers option injects numeric tokens', () {
      final words = LoremWords.generate(count: 10, includeNumbers: true);
      expect(words.any((w) => RegExp(r'^\d+$').hasMatch(w)), isTrue);
    });

    test('punctuation and numbers combine cleanly', () {
      final words = LoremWords.generate(
        count: 25,
        includePunctuation: true,
        includeNumbers: true,
      );
      expect(words.length, 25);
      expect(words.first, 'Lorem');
      expect(words.any((w) => RegExp(r'\d').hasMatch(w)), isTrue);
      expect(words.any((w) => RegExp(r'[.,;:?!"]').hasMatch(w)), isTrue);
      expect(words.last.endsWith('.'), isTrue);
    });
  });

  group('TypingSession', () {
    test('calculates WPM and accuracy accurately and completes on final word', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final session = TypingSession(
        initialWordCount: 10,
        clock: () => now,
      );
      addTearDown(session.dispose);

      expect(session.status, TestStatus.idle);
      expect(session.wpm, 0);

      final targetWords = List<String>.from(session.words);
      for (var i = 0; i < targetWords.length; i++) {
        for (final char in targetWords[i].split('')) {
          session.handleCharacter(char);
          now = now.add(const Duration(milliseconds: 120));
        }
        if (i < targetWords.length - 1) {
          session.handleSpace();
          now = now.add(const Duration(milliseconds: 120));
        }
      }

      expect(session.status, TestStatus.finished);
      expect(session.wpm, greaterThan(0));
      expect(session.accuracy, 100.0);
      expect(session.characterStats.incorrect, 0);
      expect(session.characterStats.extra, 0);
      expect(session.characterStats.missed, 0);

      session.reset();
      expect(session.status, TestStatus.idle);
      expect(session.currentWordIndex, 0);
      expect(session.words, equals(targetWords));
      expect(session.wpm, 0);
    });

    test('tracks mistakes, extra chars, and supports backspace fixes', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final session = TypingSession(
        initialWordCount: 10,
        clock: () => now,
      );
      addTearDown(session.dispose);

      session.handleCharacter('x');
      now = now.add(const Duration(milliseconds: 500));
      expect(session.characterStats.incorrect, 1);
      expect(session.accuracy, 0.0);

      session.handleBackspace();
      expect(session.typedWords.first, isEmpty);

      for (final ch in session.words.first.split('')) {
        session.handleCharacter(ch);
      }
      session.handleCharacter('z');
      expect(session.characterStats.extra, 1);

      session.handleBackspace();
      expect(session.characterStats.extra, 0);
      expect(session.accuracy, greaterThan(50.0));
    });

    test('toggling punctuation and numbers resets with updated words', () {
      final session = TypingSession(initialWordCount: 10);
      addTearDown(session.dispose);

      final plain = List<String>.from(session.words);
      session.togglePunctuation();
      expect(session.includePunctuation, isTrue);
      expect(session.words, isNot(equals(plain)));

      session.toggleNumbers();
      expect(session.includeNumbers, isTrue);
      expect(session.words.any((w) => RegExp(r'\d').hasMatch(w)), isTrue);
    });
  });
}
