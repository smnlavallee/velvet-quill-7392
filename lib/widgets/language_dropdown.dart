import 'package:material_ui/material_ui.dart';

import '../engine/typing_session.dart';
import '../engine/word_bank.dart';
import '../theme/app_colors.dart';

class LanguageDropdown extends StatefulWidget {
  const LanguageDropdown({
    super.key,
    required this.session,
    required this.onOptionChanged,
  });

  final TypingSession session;
  final VoidCallback onOptionChanged;

  @override
  State<LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeLanguage = widget.session.language;
    final labelColor = _hovered ? AppColors.accent : AppColors.text;
    final chevronColor = _hovered ? AppColors.text : AppColors.sub;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.subBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: PopupMenuButton<TypingLanguage>(
          key: const Key('language_dropdown'),
          tooltip: '',
          initialValue: activeLanguage,
          color: AppColors.subBg,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF3E4044), width: 1),
          ),
          onSelected: (TypingLanguage selected) {
            widget.session.setLanguage(selected);
            widget.onOptionChanged();
          },
          onCanceled: widget.onOptionChanged,
          itemBuilder: (BuildContext context) {
            return TypingLanguage.values.map((TypingLanguage lang) {
              final isSelected = lang == activeLanguage;
              return PopupMenuItem<TypingLanguage>(
                key: Key('language_option_${lang.name}'),
                value: lang,
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 18,
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: AppColors.accent,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.label,
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.accent : AppColors.text,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          child: Semantics(
            button: true,
            label: 'Language: ${activeLanguage.label}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.language_rounded,
                    size: 15,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 120),
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                    child: Text(activeLanguage.label),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: chevronColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
