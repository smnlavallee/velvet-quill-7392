import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';

import 'pages/typing_page.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoremTypeApp());
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
}

class LoremTypeApp extends StatelessWidget {
  const LoremTypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'loremtype — Typing Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'RobotoMono',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.bg,
          onSurface: AppColors.text,
          error: AppColors.error,
        ),
      ),
      home: const TypingPage(),
    );
  }
}
