import 'package:material_ui/material_ui.dart';

import '../engine/typing_session.dart';
import '../engine/word_bank.dart';
import '../theme/app_colors.dart';

class ConfigBar extends StatelessWidget {
  const ConfigBar({
    super.key,
    required this.session,
    required this.onOptionChanged,
  });

  final TypingSession session;
  final VoidCallback onOptionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.subBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          _ConfigToggleButton(
            buttonKey: const Key('toggle_punctuation'),
            prefix: '@',
            label: 'punctuation',
            active: session.includePunctuation,
            onTap: () {
              session.togglePunctuation();
              onOptionChanged();
            },
          ),
          _ConfigToggleButton(
            buttonKey: const Key('toggle_numbers'),
            prefix: '#',
            label: 'numbers',
            active: session.includeNumbers,
            onTap: () {
              session.toggleNumbers();
              onOptionChanged();
            },
          ),
          const _BarDivider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'words',
              style: TextStyle(
                color: AppColors.sub,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (final count in WordBank.wordCountPresets)
            _ConfigToggleButton(
              buttonKey: Key('word_count_$count'),
              label: '$count',
              active: session.wordCount == count,
              onTap: () {
                session.setWordCount(count);
                onOptionChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _BarDivider extends StatelessWidget {
  const _BarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ConfigToggleButton extends StatefulWidget {
  const _ConfigToggleButton({
    required this.buttonKey,
    required this.label,
    required this.active,
    required this.onTap,
    this.prefix,
  });

  final Key buttonKey;
  final String? prefix;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ConfigToggleButton> createState() => _ConfigToggleButtonState();
}

class _ConfigToggleButtonState extends State<_ConfigToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    if (widget.active) {
      foreground = AppColors.accent;
    } else if (_hovered) {
      foreground = AppColors.text;
    } else {
      foreground = AppColors.sub;
    }

    final text = widget.prefix == null
        ? widget.label
        : '${widget.prefix} ${widget.label}';

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: widget.buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 13.5,
                height: 1.35,
                fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }
}
