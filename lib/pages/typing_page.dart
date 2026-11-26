import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/typing_session.dart';
import '../theme/app_colors.dart';
import '../widgets/config_bar.dart';
import '../widgets/results_panel.dart';
import '../widgets/word_display.dart';

class TypingPage extends StatefulWidget {
  const TypingPage({
    super.key,
    this.session,
  });

  final TypingSession? session;

  @override
  State<TypingPage> createState() => _TypingPageState();
}

class _TypingPageState extends State<TypingPage> {
  late final TypingSession _session;
  late final bool _ownsSession;
  final FocusNode _typingFocusNode = FocusNode(debugLabel: 'typing_surface');

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ?? TypingSession();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _typingFocusNode.dispose();
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.escape) {
      _session.reset();
      _typingFocusNode.requestFocus();
      return true;
    }

    if (_session.status == TestStatus.finished) {
      return false;
    }

    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (logicalKey == LogicalKeyboardKey.backspace) {
      _session.handleBackspace(wholeWord: isControlPressed || isAltPressed);
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.space) {
      _session.handleSpace();
      return true;
    }

    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_session.currentWordIndex == _session.words.length - 1) {
        _session.handleSpace();
        return true;
      }
      return false;
    }

    // Allow browser shortcuts (Ctrl+R, Cmd+L, etc.) to pass through untouched.
    // Note: AltGr on some international Windows keyboards sets both Ctrl and Alt.
    if (isMetaPressed || (isControlPressed && !isAltPressed)) {
      return false;
    }

    final char = event.character;
    if (char != null && char.length == 1) {
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 32 && codeUnit != 127) {
        _session.handleCharacter(char);
        return true;
      }
    }

    return false;
  }

  void _refocusTyping() {
    _typingFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Focus(
        focusNode: _typingFocusNode,
        autofocus: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: AnimatedBuilder(
                  animation: _session,
                  builder: (BuildContext context, Widget? child) {
                    final isFinished = _session.status == TestStatus.finished;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildHeader(),
                        const SizedBox(height: 24),
                        Center(
                          child: ConfigBar(
                            session: _session,
                            onOptionChanged: _refocusTyping,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: isFinished
                                ? SingleChildScrollView(
                                    child: ResultsPanel(
                                      session: _session,
                                      onReset: () {
                                        _session.reset();
                                        _refocusTyping();
                                      },
                                    ),
                                  )
                                : _buildTypingStage(),
                          ),
                        ),
                        _buildFooter(isFinished: isFinished),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: <Widget>[
        Icon(
          Icons.keyboard_alt_rounded,
          color: AppColors.accent,
          size: 30,
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'loremtype',
              style: TextStyle(
                fontFamily: 'LexendDeca',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                height: 1.0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'lorem ipsum typing test',
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 11,
                color: AppColors.sub,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypingStage() {
    final isRunning = _session.status == TestStatus.running;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              '${_session.completedWordCount}/${_session.words.length}',
              key: const Key('live_progress'),
              style: const TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
              ),
            ),
            Text(
              isRunning ? '${_session.wpm} wpm' : 'start typing',
              key: const Key('live_wpm'),
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: isRunning ? 22 : 14,
                fontWeight: FontWeight.w500,
                color: isRunning ? AppColors.accent : AppColors.sub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        WordDisplay(
          session: _session,
          onTapArea: _refocusTyping,
        ),
      ],
    );
  }

  Widget _buildFooter({required bool isFinished}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Text(
          isFinished
              ? 'click reset or press esc to type again'
              : 'esc - restart test',
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 12,
            color: AppColors.sub,
          ),
        ),
      ),
    );
  }
}
