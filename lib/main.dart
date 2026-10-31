import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
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
      scaffoldBackgroundColor: const Color(0xFFF5F7F2),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F2),
        foregroundColor: ink,
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
    home: const HomeScreen(),
  );
}
