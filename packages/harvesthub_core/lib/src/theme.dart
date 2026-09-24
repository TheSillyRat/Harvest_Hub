import 'package:flutter/material.dart';

class HhColors {
  static const primary = Color(0xFF2E7D32);
  static const primaryDark = Color(0xFF1B5E20);
  static const accent = Color(0xFFF9A825);
  static const bg = Color(0xFFF7FBF4);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B3A2F);
  static const muted = Color(0xFF6B7C73);
  static const danger = Color(0xFFC62828);
}

ThemeData harvestHubTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: HhColors.primary,
          primary: HhColors.primary,
          secondary: HhColors.accent,
          surface: HhColors.surface,
          error: HhColors.danger),
      scaffoldBackgroundColor: HhColors.bg,
      appBarTheme: const AppBarTheme(
          backgroundColor: HhColors.bg,
          foregroundColor: HhColors.text,
          centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC8E6C9)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
    );
