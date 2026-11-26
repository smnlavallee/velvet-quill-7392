import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loremtype/engine/typing_session.dart';
import 'package:loremtype/engine/word_bank.dart';

void main() {
  group('WordBank', () {
    test('every language pool contains exactly 100 unique lowercase words', () {
      for (final lang in TypingLanguage.values) {
        final pool = WordBank.poolFor(lang);
        expect(pool.length, 100, reason: '${lang.label} must have 100 words');
        expect(
          pool.toSet().length,
          100,
          reason: '${lang.label} pool must contain 100 unique words',
        );
        for (final word in pool) {
          expect(
            word,
            equals(word.toLowerCase()),
            reason: 'Expected lowercase word in ${lang.label}, got "$word"',
          );
          expect(word.trim(), equals(word));
          expect(word.isNotEmpty, isTrue);
        }
      }
    });

    test('produces a different order on every generation, including at 100 words', () {
      final rng = math.Random(42);
      for (final lang in TypingLanguage.values) {
        for (final count in WordBank.wordCountPresets) {
          final first = WordBank.generate(
            language: lang,
            count: count,
            random: rng,
          );
          final second = WordBank.generate(
            language: lang,
            count: count,
            previousWords: first,
            random: rng,
          );
          expect(first.length, count);
          expect(second.length, count);
          expect(
            second,
            isNot(equals(first)),
            reason: '${lang.label} ($count words) must reshuffle on repeat',
          );
        }
      }
    });

    test('punctuation option injects capitalization and punctuation marks', () {
      final words = WordBank.generate(
        language: TypingLanguage.english,
        count: 10,
        includePunctuation: true,
        random: math.Random(7),
      );
      expect(words.first[0], equals(words.first[0].toUpperCase()));
      expect(RegExp(r'[.?!]$').hasMatch(words.last), isTrue);
      expect(
        words.any((w) => RegExp(r'[.,;:?!"]').hasMatch(w)),
        isTrue,
      );
    });

    test('numbers option injects numeric tokens', () {
      final words = WordBank.generate(
        language: TypingLanguage.french,
        count: 10,
        includeNumbers: true,
        random: math.Random(11),
      );
      expect(words.any((w) => RegExp(r'^\d+$').hasMatch(w)), isTrue);
    });

    test('punctuation and numbers combine cleanly across all languages', () {
      for (final lang in TypingLanguage.values) {
        final words = WordBank.generate(
          language: lang,
          count: 25,
          includePunctuation: true,
          includeNumbers: true,
          random: math.Random(19),
        );
        expect(words.length, 25);
        expect(words.any((w) => RegExp(r'\d').hasMatch(w)), isTrue);
        expect(words.any((w) => RegExp(r'[.,;:?!"]').hasMatch(w)), isTrue);
        expect(RegExp(r'[.?!]$').hasMatch(words.last), isTrue);
      }
    });
  });

  group('TypingSession', () {
    test('calculates WPM and accuracy, completes, and resets with new word order', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final session = TypingSession(
        initialLanguage: TypingLanguage.english,
        initialWordCount: 10,
        clock: () => now,
        random: math.Random(123),
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
      expect(session.words, isNot(equals(targetWords)));
      expect(session.wpm, 0);
    });

    test('switching languages updates the word pool cleanly', () {
      final session = TypingSession(
        initialLanguage: TypingLanguage.english,
        initialWordCount: 10,
        random: math.Random(9),
      );
      addTearDown(session.dispose);

      for (final word in session.words) {
        expect(WordBank.englishWords, contains(word));
      }

      session.setLanguage(TypingLanguage.french);
      expect(session.language, TypingLanguage.french);
      for (final word in session.words) {
        expect(WordBank.frenchWords, contains(word));
      }

      session.setLanguage(TypingLanguage.loremIpsum);
      expect(session.language, TypingLanguage.loremIpsum);
      for (final word in session.words) {
        expect(WordBank.loremIpsumWords, contains(word));
      }
    });

    test('resetting at 100 words produces a different order every time', () {
      final session = TypingSession(
        initialLanguage: TypingLanguage.loremIpsum,
        initialWordCount: 100,
        random: math.Random(55),
      );
      addTearDown(session.dispose);

      final first = List<String>.from(session.words);
      session.reset();
      final second = List<String>.from(session.words);
      session.reset();
      final third = List<String>.from(session.words);

      expect(first.length, 100);
      expect(second.length, 100);
      expect(third.length, 100);
      expect(second, isNot(equals(first)));
      expect(third, isNot(equals(second)));
    });

    test('tracks mistakes, extra chars, and supports backspace fixes', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final session = TypingSession(
        initialWordCount: 10,
        clock: () => now,
        random: math.Random(77),
      );
      addTearDown(session.dispose);

      final wrongChar = session.words.first.startsWith('z') ? 'q' : 'z';
      session.handleCharacter(wrongChar);
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
  });
}
