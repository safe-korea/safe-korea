import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SafeKoreaApp());

class SafeKoreaApp extends StatelessWidget {
  const SafeKoreaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SAFE KOREA',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildAppTheme(),
    home: const AppShell(),
  );
}
