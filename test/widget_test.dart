import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loremtype/engine/typing_session.dart';
import 'package:loremtype/engine/word_bank.dart';
import 'package:loremtype/pages/typing_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
      'full flow: language dropdown, toggles, typing completion, results, and reshuffled reset',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final session = TypingSession(
      initialLanguage: TypingLanguage.english,
      initialWordCount: 25,
      clock: () => now,
      random: math.Random(42),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TypingPage(session: session),
      ),
    );

    // Language selector sits in a separate box to the right of the 100 button.
    final btn100Rect = tester.getRect(find.byKey(const Key('word_count_100')));
    final dropdownRect =
        tester.getRect(find.byKey(const Key('language_dropdown')));
    expect(dropdownRect.left, greaterThan(btn100Rect.right));

    // Switch to French via the dropdown.
    await tester.tap(find.byKey(const Key('language_dropdown')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('language_option_french')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.language, TypingLanguage.french);
    for (final word in session.words) {
      expect(WordBank.frenchWords, contains(word));
    }

    // Switch to Lorem Ipsum via the dropdown.
    await tester.tap(find.byKey(const Key('language_dropdown')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('language_option_loremIpsum')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.language, TypingLanguage.loremIpsum);
    for (final word in session.words) {
      expect(WordBank.loremIpsumWords, contains(word));
    }

    // Select 10 words, toggle punctuation, toggle numbers.
    await tester.tap(find.byKey(const Key('word_count_10')));
    await tester.pump();
    expect(session.words.length, 10);

    await tester.tap(find.byKey(const Key('toggle_punctuation')));
    await tester.pump();
    expect(session.includePunctuation, isTrue);

    await tester.tap(find.byKey(const Key('toggle_numbers')));
    await tester.pump();
    expect(session.includeNumbers, isTrue);
    expect(session.words.any((w) => RegExp(r'\d').hasMatch(w)), isTrue);

    final wordsBeforeRun = List<String>.from(session.words);

    // Type all 10 words to completion.
    for (var i = 0; i < wordsBeforeRun.length; i++) {
      for (final char in wordsBeforeRun[i].split('')) {
        session.handleCharacter(char);
        now = now.add(const Duration(milliseconds: 100));
      }
      if (i < wordsBeforeRun.length - 1) {
        session.handleSpace();
        now = now.add(const Duration(milliseconds: 100));
      }
    }
    await tester.pumpAndSettle();

    // Completion view shows WPM, Accuracy, Time, and Reset button.
    expect(find.byKey(const Key('result_wpm')), findsOneWidget);
    expect(find.byKey(const Key('result_accuracy')), findsOneWidget);
    expect(find.byKey(const Key('result_time')), findsOneWidget);
    expect(find.byKey(const Key('reset_button')), findsOneWidget);
    expect(session.wpm, greaterThan(0));

    // Clicking Reset restarts the session with a NEW sequence of words.
    await tester.tap(find.byKey(const Key('reset_button')));
    await tester.pump();

    expect(session.status, TestStatus.idle);
    expect(session.words.length, 10);
    expect(session.words, isNot(equals(wordsBeforeRun)));
    expect(find.byKey(const Key('reset_button')), findsNothing);
    expect(find.byKey(const Key('live_progress')), findsOneWidget);
  });
}
