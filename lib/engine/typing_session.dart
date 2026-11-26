import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'lorem_words.dart';

enum TestStatus { idle, running, finished }

@immutable
class CharacterStats {
  const CharacterStats({
    required this.correct,
    required this.incorrect,
    required this.extra,
    required this.missed,
    required this.correctSpaces,
  });

  final int correct;
  final int incorrect;
  final int extra;
  final int missed;
  final int correctSpaces;
}

/// Pure state controller for the single-page Monkeytype-style typing test.
class TypingSession extends ChangeNotifier {
  TypingSession({
    int initialWordCount = 25,
    bool initialPunctuation = false,
    bool initialNumbers = false,
    DateTime Function()? clock,
  })  : _wordCount = initialWordCount.clamp(1, LoremWords.maxWords),
        _includePunctuation = initialPunctuation,
        _includeNumbers = initialNumbers,
        _clock = clock ?? DateTime.now {
    _rebuildWords();
  }

  static const int maxExtraCharsPerWord = 12;

  final DateTime Function() _clock;

  int _wordCount;
  bool _includePunctuation;
  bool _includeNumbers;

  late List<String> _words;
  late List<String> _typedWords;
  int _currentWordIndex = 0;
  TestStatus _status = TestStatus.idle;
  DateTime? _startTime;
  DateTime? _endTime;
  int _totalKeystrokes = 0;
  int _correctKeystrokes = 0;
  int _inputRevision = 0;
  Timer? _ticker;

  int get wordCount => _wordCount;
  bool get includePunctuation => _includePunctuation;
  bool get includeNumbers => _includeNumbers;
  List<String> get words => _words;
  List<String> get typedWords => List<String>.unmodifiable(_typedWords);
  int get currentWordIndex => _currentWordIndex;
  TestStatus get status => _status;
  int get inputRevision => _inputRevision;

  int get completedWordCount {
    if (_status == TestStatus.finished) {
      return _words.length;
    }
    return _currentWordIndex;
  }

  Duration get elapsed {
    final start = _startTime;
    if (start == null) {
      return Duration.zero;
    }
    final end = _endTime ?? _clock();
    final diff = end.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }

  CharacterStats get characterStats {
    var correct = 0;
    var incorrect = 0;
    var extra = 0;
    var missed = 0;
    var correctSpaces = 0;

    final lastIndex = _status == TestStatus.finished
        ? _words.length - 1
        : _currentWordIndex;

    for (var i = 0; i <= lastIndex; i++) {
      final target = _words[i];
      final typed = _typedWords[i];
      final overlap = math.min(target.length, typed.length);

      for (var j = 0; j < overlap; j++) {
        if (typed[j] == target[j]) {
          correct++;
        } else {
          incorrect++;
        }
      }

      if (typed.length > target.length) {
        extra += typed.length - target.length;
      }

      final wordCommitted =
          i < _currentWordIndex || _status == TestStatus.finished;
      if (wordCommitted && typed.length < target.length) {
        missed += target.length - typed.length;
      }

      if (i < _currentWordIndex && typed == target) {
        correctSpaces++;
      }
    }

    return CharacterStats(
      correct: correct,
      incorrect: incorrect,
      extra: extra,
      missed: missed,
      correctSpaces: correctSpaces,
    );
  }

  /// Standard Monkeytype WPM formula: (correct characters + correct spaces) / 5 / elapsed minutes.
  int get wpm {
    final elapsedMs = elapsed.inMilliseconds;
    if (elapsedMs <= 0) {
      return 0;
    }
    final stats = characterStats;
    final netChars = stats.correct + stats.correctSpaces;
    if (netChars <= 0) {
      return 0;
    }
    final minutes = elapsedMs / 60000.0;
    return ((netChars / 5.0) / minutes).round();
  }

  double get accuracy {
    if (_totalKeystrokes == 0) {
      return 100.0;
    }
    return ((_correctKeystrokes / _totalKeystrokes) * 100.0).clamp(0.0, 100.0);
  }

  bool isWordCommittedWithError(int index) {
    if (index >= _currentWordIndex && _status != TestStatus.finished) {
      return false;
    }
    return _typedWords[index] != _words[index];
  }

  void setWordCount(int count) {
    final next = count.clamp(1, LoremWords.maxWords);
    if (next == _wordCount && _status == TestStatus.idle) {
      return;
    }
    _wordCount = next;
    reset();
  }

  void togglePunctuation() {
    _includePunctuation = !_includePunctuation;
    reset();
  }

  void toggleNumbers() {
    _includeNumbers = !_includeNumbers;
    reset();
  }

  void handleCharacter(String char) {
    if (_status == TestStatus.finished || char.isEmpty) {
      return;
    }
    if (char == ' ') {
      handleSpace();
      return;
    }

    if (_status == TestStatus.idle) {
      _start();
    }

    final target = _words[_currentWordIndex];
    final current = _typedWords[_currentWordIndex];
    if (current.length >= target.length + maxExtraCharsPerWord) {
      return;
    }

    _totalKeystrokes++;
    if (current.length < target.length && target[current.length] == char) {
      _correctKeystrokes++;
    }

    final updated = '$current$char';
    _typedWords[_currentWordIndex] = updated;
    _inputRevision++;

    if (_currentWordIndex == _words.length - 1 && updated == target) {
      _finish();
      return;
    }

    notifyListeners();
  }

  void handleSpace() {
    if (_status == TestStatus.finished) {
      return;
    }

    final current = _typedWords[_currentWordIndex];
    if (current.isEmpty) {
      return;
    }

    final target = _words[_currentWordIndex];
    _totalKeystrokes++;
    if (current == target) {
      _correctKeystrokes++;
    }
    _inputRevision++;

    if (_currentWordIndex == _words.length - 1) {
      _finish();
      return;
    }

    _currentWordIndex++;
    notifyListeners();
  }

  void handleBackspace({bool wholeWord = false}) {
    if (_status != TestStatus.running) {
      return;
    }

    final current = _typedWords[_currentWordIndex];
    if (current.isNotEmpty) {
      _typedWords[_currentWordIndex] =
          wholeWord ? '' : current.substring(0, current.length - 1);
      _inputRevision++;
      notifyListeners();
      return;
    }

    if (_currentWordIndex > 0 &&
        _typedWords[_currentWordIndex - 1] != _words[_currentWordIndex - 1]) {
      _currentWordIndex--;
      if (wholeWord) {
        _typedWords[_currentWordIndex] = '';
      }
      _inputRevision++;
      notifyListeners();
    }
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _rebuildWords();
    _currentWordIndex = 0;
    _status = TestStatus.idle;
    _startTime = null;
    _endTime = null;
    _totalKeystrokes = 0;
    _correctKeystrokes = 0;
    _inputRevision++;
    notifyListeners();
  }

  void _rebuildWords() {
    _words = LoremWords.generate(
      count: _wordCount,
      includePunctuation: _includePunctuation,
      includeNumbers: _includeNumbers,
    );
    _typedWords = List<String>.filled(_words.length, '');
  }

  void _start() {
    _status = TestStatus.running;
    _startTime = _clock();
    _endTime = null;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_status == TestStatus.running) {
        notifyListeners();
      }
    });
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _endTime = _clock();
    _status = TestStatus.finished;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
