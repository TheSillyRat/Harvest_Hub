import 'package:flutter/material.dart';

class HhColors {
  static const primary = Color(0xFF22442A);
  static const primaryDark = Color(0xFF1B2C1F);
  static const accent = Color(0xFFF9A825);
  static const sageLight = Color(0xFFDDE5D9);
  static const bg = Color(0xFFF7F8F4);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B2C1F);
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
        error: HhColors.danger,
      ),
      scaffoldBackgroundColor: HhColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: HhColors.text,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HhColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
