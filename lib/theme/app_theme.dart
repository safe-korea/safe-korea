import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppPalette {
  static const green = Color(0xFF086B50);
  static const ink = Color(0xFF17352D);
  static const background = Color(0xFFF5F8F6);
  static const surface = Colors.white;
  static const muted = Color(0xFF53665E);
  static const caution = Color(0xFF8D421F);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppPalette.green).copyWith(
    primary: AppPalette.green,
    onPrimary: Colors.white,
    surface: AppPalette.surface,
    onSurface: AppPalette.ink,
    onSurfaceVariant: AppPalette.muted,
    outlineVariant: AppPalette.green.withValues(alpha: 0.16),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: defaultTargetPlatform == TargetPlatform.iOS
        ? 'Apple SD Gothic Neo'
        : 'sans-serif',
    fontFamilyFallback: const ['Noto Sans CJK KR', 'Noto Sans KR'],
    scaffoldBackgroundColor: AppPalette.background,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 26,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: AppPalette.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: AppPalette.ink,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5, color: AppPalette.ink),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: AppPalette.ink),
      bodySmall: TextStyle(fontSize: 14, height: 1.45, color: AppPalette.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.background,
      foregroundColor: AppPalette.ink,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPalette.surface,
      indicatorColor: AppPalette.green.withValues(alpha: 0.13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      filled: true,
      fillColor: AppPalette.surface,
    ),
  );
}
