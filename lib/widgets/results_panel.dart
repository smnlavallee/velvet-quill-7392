import 'package:flutter/material.dart';

import '../engine/typing_session.dart';
import '../theme/app_colors.dart';

class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.session,
    required this.onReset,
  });

  final TypingSession session;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final stats = session.characterStats;
    final elapsedSeconds = session.elapsed.inMilliseconds / 1000.0;
    final formattedTime = elapsedSeconds < 10
        ? '${elapsedSeconds.toStringAsFixed(1)}s'
        : '${elapsedSeconds.round()}s';

    final modifiers = <String>[
      if (session.includePunctuation) 'punctuation',
      if (session.includeNumbers) 'numbers',
    ];
    final testTypeLabel = modifiers.isEmpty
        ? 'words ${session.wordCount}'
        : 'words ${session.wordCount} · ${modifiers.join(' + ')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 56,
          runSpacing: 24,
          children: <Widget>[
            _HeroStat(
              statKey: const Key('result_wpm'),
              label: 'wpm',
              value: '${session.wpm}',
            ),
            _HeroStat(
              statKey: const Key('result_accuracy'),
              label: 'acc',
              value: '${session.accuracy.round()}%',
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.subBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 36,
            runSpacing: 16,
            children: <Widget>[
              _SecondaryStat(
                label: 'test type',
                value: testTypeLabel,
              ),
              _SecondaryStat(
                statKey: const Key('result_time'),
                label: 'time',
                value: formattedTime,
              ),
              _SecondaryStat(
                label: 'characters',
                value:
                    '${stats.correct}/${stats.incorrect}/${stats.extra}/${stats.missed}',
                tooltip: 'correct / incorrect / extra / missed',
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        Semantics(
          button: true,
          label: 'Reset',
          child: ElevatedButton.icon(
            key: const Key('reset_button'),
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Reset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              textStyle: const TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.statKey,
    required this.label,
    required this.value,
  });

  final Key statKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 22,
            color: AppColors.sub,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          key: statKey,
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 64,
            height: 1.05,
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SecondaryStat extends StatelessWidget {
  const _SecondaryStat({
    this.statKey,
    required this.label,
    required this.value,
    this.tooltip,
  });

  final Key? statKey;
  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 12,
            color: AppColors.sub,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          key: statKey,
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 17,
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: column);
    }
    return column;
  }
}
