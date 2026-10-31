import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_shell.dart';
import 'widgets/common.dart';

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
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDFE7E1)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFF5F7F2),
        indicatorColor: Color(0xFFCDE8DF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7F2),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F2),
        foregroundColor: ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 18, height: 1.55, color: ink),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.all(16),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: const AppShell(),
  );
}
