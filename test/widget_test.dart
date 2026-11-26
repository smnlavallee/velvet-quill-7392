import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loremtype/engine/typing_session.dart';
import 'package:loremtype/pages/typing_page.dart';

void main() {
  testWidgets(
      'full typing flow: toggles, typing completion, results, and reset button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final session = TypingSession(
      initialWordCount: 25,
      clock: () => now,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TypingPage(session: session),
      ),
    );

    // Select 10 words, toggle punctuation, toggle numbers.
    await tester.tap(find.byKey(const Key('word_count_10')));
    await tester.pump();
    expect(session.words.length, 10);

    await tester.tap(find.byKey(const Key('toggle_punctuation')));
    await tester.pump();
    expect(session.includePunctuation, isTrue);
    expect(session.words.first, 'Lorem');

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

    // Clicking Reset restarts the session with the exact same words.
    await tester.tap(find.byKey(const Key('reset_button')));
    await tester.pump();

    expect(session.status, TestStatus.idle);
    expect(session.words, equals(wordsBeforeRun));
    expect(find.byKey(const Key('reset_button')), findsNothing);
    expect(find.byKey(const Key('live_progress')), findsOneWidget);
  });
}
