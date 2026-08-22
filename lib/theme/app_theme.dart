import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFFFFAF2);
  static const primary = Color(0xFF4DB07A);
  static const primaryDark = Color(0xFF277A50);
  static const surface = Color(0xFFFFFEFB);
  static const outline = Color(0xFFE9E0D5);
  static const text = Color(0xFF292622);
  static const mutedText = Color(0xFF7A746D);
  static const warmAccent = Color(0xFFFFE9CE);
}

abstract final class AppTheme {
  static const _fontFallback = [
    'Hiragino Sans',
    'Noto Sans JP',
    'Noto Sans CJK JP',
    'sans-serif',
  ];

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      outline: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamilyFallback: _fontFallback,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontFamilyFallback: _fontFallback,
        ),
        titleLarge: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          fontFamilyFallback: _fontFallback,
        ),
        titleMedium: TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          fontFamilyFallback: _fontFallback,
        ),
        bodyLarge: TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
          fontFamilyFallback: _fontFallback,
        ),
        bodyMedium: TextStyle(
          color: AppColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.55,
          fontFamilyFallback: _fontFallback,
        ),
        bodySmall: TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
          fontFamilyFallback: _fontFallback,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: _fontFallback,
        ),
      ),
      appBarTheme: const AppBarTheme(
        foregroundColor: AppColors.text,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          fontFamilyFallback: _fontFallback,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
