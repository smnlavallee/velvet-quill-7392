import 'dart:math' as math;

enum TypingLanguage {
  english('English'),
  french('French'),
  loremIpsum('Lorem Ipsum');

  const TypingLanguage(this.label);

  final String label;
}

/// 100-word pools for English, French, and Lorem Ipsum with randomized
/// non-repeating sequence generation, punctuation, and numbers.
abstract final class WordBank {
  static const List<int> wordCountPresets = <int>[10, 25, 50, 100];
  static const int maxWords = 100;

  static const List<String> englishWords = <String>[
    'the', 'be', 'of', 'and', 'a', 'to', 'in', 'he', 'have', 'it',
    'that', 'for', 'they', 'with', 'as', 'not', 'on', 'she', 'at', 'by',
    'this', 'we', 'you', 'do', 'but', 'from', 'or', 'which', 'one', 'would',
    'all', 'will', 'there', 'say', 'who', 'make', 'when', 'can', 'more', 'if',
    'no', 'man', 'out', 'other', 'so', 'what', 'time', 'up', 'go', 'about',
    'than', 'into', 'could', 'state', 'only', 'new', 'year', 'some', 'take', 'come',
    'these', 'know', 'see', 'use', 'get', 'like', 'then', 'first', 'any', 'work',
    'now', 'may', 'such', 'give', 'over', 'think', 'most', 'even', 'find', 'day',
    'also', 'after', 'way', 'many', 'must', 'look', 'before', 'great', 'back', 'through',
    'long', 'where', 'much', 'should', 'well', 'people', 'down', 'own', 'just', 'because',
  ];

  static const List<String> frenchWords = <String>[
    'le', 'de', 'un', 'être', 'et', 'à', 'il', 'avoir', 'ne', 'je',
    'son', 'que', 'se', 'qui', 'ce', 'dans', 'en', 'du', 'elle', 'au',
    'pour', 'pas', 'vous', 'par', 'sur', 'faire', 'plus', 'dire', 'me', 'on',
    'mon', 'lui', 'nous', 'comme', 'mais', 'pouvoir', 'avec', 'tout', 'aller', 'voir',
    'bien', 'où', 'sans', 'tu', 'ou', 'leur', 'homme', 'si', 'deux', 'mari',
    'moi', 'vouloir', 'te', 'femme', 'venir', 'quand', 'grand', 'celui', 'notre', 'devoir',
    'jour', 'prendre', 'même', 'votre', 'rien', 'petit', 'encore', 'aussi', 'quelque', 'dont',
    'temps', 'très', 'savoir', 'falloir', 'donner', 'parler', 'main', 'chose', 'monde', 'vie',
    'année', 'après', 'déjà', 'maison', 'travail', 'ville', 'pays', 'moment', 'heure', 'idée',
    'école', 'enfant', 'ami', 'terre', 'soleil', 'nuit', 'matin', 'soir', 'livre', 'chemin',
  ];

  static const List<String> loremIpsumWords = <String>[
    'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing', 'elit', 'sed', 'do',
    'eiusmod', 'tempor', 'incididunt', 'ut', 'labore', 'et', 'dolore', 'magna', 'aliqua', 'enim',
    'ad', 'minim', 'veniam', 'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi', 'aliquip',
    'ex', 'ea', 'commodo', 'consequat', 'duis', 'aute', 'irure', 'in', 'reprehenderit', 'voluptate',
    'velit', 'esse', 'cillum', 'eu', 'fugiat', 'nulla', 'pariatur', 'excepteur', 'sint', 'occaecat',
    'cupidatat', 'non', 'proident', 'sunt', 'culpa', 'qui', 'officia', 'deserunt', 'mollit', 'anim',
    'id', 'est', 'laborum', 'perspiciatis', 'unde', 'omnis', 'iste', 'natus', 'error', 'voluptatem',
    'accusantium', 'doloremque', 'laudantium', 'totam', 'rem', 'aperiam', 'eaque', 'ipsa', 'quae', 'ab',
    'illo', 'inventore', 'veritatis', 'quasi', 'architecto', 'beatae', 'vitae', 'dicta', 'explicabo', 'nemo',
    'ipsam', 'quia', 'voluptas', 'aspernatur', 'aut', 'odit', 'fugit', 'numquam', 'eius', 'modi',
  ];

  static const List<String> _punctuationMarks = <String>[
    ',', ',', ',', '.', '.', '.', ';', ':', '?', '!',
  ];

  static List<String> poolFor(TypingLanguage language) {
    return switch (language) {
      TypingLanguage.english => englishWords,
      TypingLanguage.french => frenchWords,
      TypingLanguage.loremIpsum => loremIpsumWords,
    };
  }

  /// Generates a fresh randomized sequence of [count] words (1..100) from the
  /// selected language's 100-word pool, guaranteed to differ from [previousWords].
  static List<String> generate({
    required TypingLanguage language,
    required int count,
    bool includePunctuation = false,
    bool includeNumbers = false,
    List<String>? previousWords,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final safeCount = count.clamp(1, maxWords);
    final pool = poolFor(language);

    late List<String> result;
    for (var attempt = 0; attempt < 6; attempt++) {
      final shuffled = List<String>.from(pool)..shuffle(rng);
      final words = shuffled.sublist(0, safeCount);

      if (includeNumbers) {
        _injectNumbers(words, rng);
      }
      if (includePunctuation) {
        _applyPunctuation(words, rng);
      }

      result = words;
      if (previousWords == null || !_listEquals(result, previousWords)) {
        break;
      }
    }

    // Guarantee a visibly different order even under extreme coincidence.
    if (previousWords != null &&
        _listEquals(result, previousWords) &&
        result.length >= 2) {
      final first = result[0];
      result[0] = result[1];
      result[1] = first;
    }

    return List<String>.unmodifiable(result);
  }

  static void _injectNumbers(List<String> words, math.Random rng) {
    if (words.isEmpty) return;
    final targetNumbers =
        math.max(2, (words.length * 0.16).round()).clamp(1, words.length);
    final availableIndices = List<int>.generate(
      words.length > 1 ? words.length - 1 : 1,
      (int i) => words.length > 1 ? i + 1 : 0,
    )..shuffle(rng);

    for (var i = 0; i < targetNumbers && i < availableIndices.length; i++) {
      words[availableIndices[i]] = _randomNumber(rng);
    }
  }

  static String _randomNumber(math.Random rng) {
    return switch (rng.nextInt(4)) {
      0 => '${rng.nextInt(9) + 1}',
      1 => '${rng.nextInt(90) + 10}',
      2 => '${rng.nextInt(900) + 100}',
      _ => '${rng.nextInt(3000) + 1000}',
    };
  }

  static void _applyPunctuation(List<String> words, math.Random rng) {
    if (words.isEmpty) return;

    var capitalizeNext = true;
    var wordsSinceMark = 0;
    var nextGap = 2 + rng.nextInt(3);

    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      if (capitalizeNext) {
        word = _capitalize(word);
        capitalizeNext = false;
      }

      final isLast = i == words.length - 1;
      if (!isLast) {
        wordsSinceMark++;
        if (wordsSinceMark >= nextGap) {
          if (rng.nextInt(7) == 0 && !_isNumeric(word)) {
            word = '"$word"';
          } else {
            final mark =
                _punctuationMarks[rng.nextInt(_punctuationMarks.length)];
            word = '$word$mark';
            if (mark == '.' || mark == '?' || mark == '!') {
              capitalizeNext = true;
            }
          }
          wordsSinceMark = 0;
          nextGap = 3 + rng.nextInt(4);
        }
      }

      words[i] = word;
    }

    final lastIndex = words.length - 1;
    var last = words[lastIndex];
    if (!last.endsWith('.') && !last.endsWith('?') && !last.endsWith('!')) {
      if (last.endsWith(',') || last.endsWith(';') || last.endsWith(':')) {
        last = last.substring(0, last.length - 1);
      }
      words[lastIndex] = '$last.';
    }
  }

  static bool _isNumeric(String word) {
    if (word.isEmpty) return false;
    for (var i = 0; i < word.length; i++) {
      final unit = word.codeUnitAt(i);
      if (unit < 48 || unit > 57) return false;
    }
    return true;
  }

  static String _capitalize(String word) {
    if (word.isEmpty) return word;
    final first = word[0];
    final upper = first.toUpperCase();
    if (first == upper) return word;
    return '$upper${word.substring(1)}';
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
