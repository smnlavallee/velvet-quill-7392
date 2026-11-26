import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../engine/typing_session.dart';
import '../theme/app_colors.dart';

class WordDisplay extends StatefulWidget {
  const WordDisplay({
    super.key,
    required this.session,
    required this.onTapArea,
  });

  final TypingSession session;
  final VoidCallback onTapArea;

  @override
  State<WordDisplay> createState() => _WordDisplayState();
}

class _WordDisplayState extends State<WordDisplay>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _caretBlinkController;
  List<GlobalKey> _wordKeys = <GlobalKey>[];
  int _lastScrolledWordIndex = 0;
  int _lastInputRevision = -1;
  bool _activelyTyping = false;
  Timer? _idleCaretTimer;

  @override
  void initState() {
    super.initState();
    _caretBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);
    _syncWordKeys();
  }

  @override
  void didUpdateWidget(covariant WordDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWordKeys();
    _handleTypingActivity();
    _maybeScrollToActiveWord();
  }

  void _syncWordKeys() {
    final wordCount = widget.session.words.length;
    if (_wordKeys.length != wordCount) {
      _wordKeys = List<GlobalKey>.generate(wordCount, (_) => GlobalKey());
    }
  }

  void _handleTypingActivity() {
    final revision = widget.session.inputRevision;
    if (revision == _lastInputRevision) {
      return;
    }
    _lastInputRevision = revision;

    if (widget.session.status == TestStatus.running) {
      _activelyTyping = true;
      _idleCaretTimer?.cancel();
      _idleCaretTimer = Timer(const Duration(milliseconds: 550), () {
        if (mounted) {
          setState(() => _activelyTyping = false);
        }
      });
    } else {
      _activelyTyping = false;
      _idleCaretTimer?.cancel();
    }
  }

  void _maybeScrollToActiveWord() {
    final currentIndex = widget.session.currentWordIndex;
    if (currentIndex == _lastScrolledWordIndex &&
        widget.session.status != TestStatus.idle) {
      return;
    }
    _lastScrolledWordIndex = currentIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (currentIndex == 0 && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
        return;
      }
      if (currentIndex >= 0 && currentIndex < _wordKeys.length) {
        final ctx = _wordKeys[currentIndex].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.32,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _idleCaretTimer?.cancel();
    _caretBlinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final words = session.words;
    final typedWords = session.typedWords;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTapArea,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 132,
          maxHeight: 176,
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          child: Semantics(
            key: const Key('word_display_semantics'),
            label: 'Typing passage: ${words.join(' ')}',
            container: true,
            child: Wrap(
              spacing: 14,
              runSpacing: 12,
              children: List<Widget>.generate(words.length, (int index) {
                final target = words[index];
                final typed = typedWords[index];
                final isActiveWord =
                    index == session.currentWordIndex &&
                    session.status != TestStatus.finished;
                final hasCommittedError =
                    session.isWordCommittedWithError(index);

                return _WordToken(
                  key: _wordKeys[index],
                  target: target,
                  typed: typed,
                  isActiveWord: isActiveWord,
                  hasCommittedError: hasCommittedError,
                  activelyTyping: _activelyTyping,
                  caretBlinkAnimation: _caretBlinkController,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordToken extends StatelessWidget {
  const _WordToken({
    super.key,
    required this.target,
    required this.typed,
    required this.isActiveWord,
    required this.hasCommittedError,
    required this.activelyTyping,
    required this.caretBlinkAnimation,
  });

  final String target;
  final String typed;
  final bool isActiveWord;
  final bool hasCommittedError;
  final bool activelyTyping;
  final Animation<double> caretBlinkAnimation;

  static const TextStyle _baseCharStyle = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 28,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final totalChars = math.max(target.length, typed.length);
    final caretIndex = typed.length;

    final children = <Widget>[];
    for (var i = 0; i < totalChars; i++) {
      final bool isExtra = i >= target.length;
      final String displayChar = isExtra ? typed[i] : target[i];

      final Color color;
      if (isExtra) {
        color = AppColors.errorExtra;
      } else if (i < typed.length) {
        color = typed[i] == target[i] ? AppColors.text : AppColors.error;
      } else {
        color = AppColors.sub;
      }

      Widget charWidget = Text(
        displayChar,
        style: _baseCharStyle.copyWith(color: color),
      );

      if (isActiveWord && i == caretIndex) {
        charWidget = Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            charWidget,
            Positioned(
              left: -1.5,
              top: 5,
              bottom: 5,
              child: _Caret(
                solid: activelyTyping,
                blink: caretBlinkAnimation,
              ),
            ),
          ],
        );
      }

      children.add(charWidget);
    }

    if (isActiveWord && caretIndex >= totalChars) {
      children.add(
        SizedBox(
          width: 0,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                top: 5,
                bottom: 5,
                child: _Caret(
                  solid: activelyTyping,
                  blink: caretBlinkAnimation,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: Container(
        decoration: hasCommittedError
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.error, width: 2),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret({
    required this.solid,
    required this.blink,
  });

  final bool solid;
  final Animation<double> blink;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: 2.5,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    if (solid) {
      return bar;
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.15, end: 1.0).animate(blink),
      child: bar,
    );
  }
}
