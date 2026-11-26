/// Deterministic Lorem Ipsum word corpus (100 words) with optional
/// punctuation and number injection matching Monkeytype's modifiers.
abstract final class LoremWords {
  static const List<int> wordCountPresets = <int>[10, 25, 50, 100];
  static const int maxWords = 100;

  /// Classic 100-word lowercase Lorem Ipsum passage.
  static const List<String> baseWords = <String>[
    'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing', 'elit', 'sed', 'do',
    'eiusmod', 'tempor', 'incididunt', 'ut', 'labore', 'et', 'dolore', 'magna', 'aliqua', 'ut',
    'enim', 'ad', 'minim', 'veniam', 'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi',
    'ut', 'aliquip', 'ex', 'ea', 'commodo', 'consequat', 'duis', 'aute', 'irure', 'dolor',
    'in', 'reprehenderit', 'in', 'voluptate', 'velit', 'esse', 'cillum', 'dolore', 'eu', 'fugiat',
    'nulla', 'pariatur', 'excepteur', 'sint', 'occaecat', 'cupidatat', 'non', 'proident', 'sunt', 'in',
    'culpa', 'qui', 'officia', 'deserunt', 'mollit', 'anim', 'id', 'est', 'laborum', 'sed',
    'ut', 'perspiciatis', 'unde', 'omnis', 'iste', 'natus', 'error', 'sit', 'voluptatem', 'accusantium',
    'doloremque', 'laudantium', 'totam', 'rem', 'aperiam', 'eaque', 'ipsa', 'quae', 'ab', 'illo',
    'inventore', 'veritatis', 'et', 'quasi', 'architecto', 'beatae', 'vitae', 'dicta', 'sunt', 'explicabo',
  ];

  static const Map<int, String> _numberReplacements = <int, String>{
    2: '42',
    7: '2026',
    13: '108',
    19: '7',
    24: '512',
    31: '99',
    37: '304',
    44: '16',
    51: '840',
    58: '23',
    65: '4096',
    72: '15',
    79: '620',
    86: '88',
    94: '1975',
  };

  static const Map<int, String> _trailingPunctuation = <int, String>{
    3: ',',
    5: '.',
    8: ';',
    11: ',',
    15: '?',
    18: ',',
    21: ':',
    23: '.',
    27: ',',
    30: '!',
    35: '.',
    39: ',',
    43: ';',
    47: '.',
    51: '.',
    55: ',',
    59: '?',
    64: ',',
    68: '.',
    73: ',',
    77: ':',
    81: '.',
    85: ',',
    89: '!',
    93: ',',
    96: ';',
  };

  static const Set<int> _quotedIndices = <int>{12, 33, 53, 75, 91};

  /// Generates a deterministic list of [count] words (clamped 1..100).
  static List<String> generate({
    required int count,
    bool includePunctuation = false,
    bool includeNumbers = false,
  }) {
    final safeCount = count.clamp(1, maxWords);
    final words = List<String>.generate(safeCount, (int index) {
      if (includeNumbers && _numberReplacements.containsKey(index)) {
        return _numberReplacements[index]!;
      }
      return baseWords[index];
    });

    if (!includePunctuation) {
      return List<String>.unmodifiable(words);
    }

    var capitalizeNext = true;
    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      if (capitalizeNext) {
        word = _capitalize(word);
        capitalizeNext = false;
      }

      if (_quotedIndices.contains(i) && !_trailingPunctuation.containsKey(i)) {
        word = '"$word"';
      }

      final mark = _trailingPunctuation[i];
      if (mark != null && i < words.length - 1) {
        word = '$word$mark';
        if (mark == '.' || mark == '?' || mark == '!') {
          capitalizeNext = true;
        }
      }

      words[i] = word;
    }

    // Ensure the passage concludes with terminal punctuation.
    final lastIndex = words.length - 1;
    var last = words[lastIndex];
    if (!last.endsWith('.') && !last.endsWith('?') && !last.endsWith('!')) {
      if (last.endsWith(',') || last.endsWith(';') || last.endsWith(':')) {
        last = last.substring(0, last.length - 1);
      }
      words[lastIndex] = '$last.';
    }

    return List<String>.unmodifiable(words);
  }

  static String _capitalize(String word) {
    if (word.isEmpty) return word;
    final first = word[0];
    final upper = first.toUpperCase();
    if (first == upper) return word;
    return '$upper${word.substring(1)}';
  }
}
