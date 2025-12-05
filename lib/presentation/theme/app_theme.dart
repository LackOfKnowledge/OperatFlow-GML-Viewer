import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 1. Paleta Kolorów (Colors)
class AppColors {
  // Główne Tła
  static const Color baseBackground = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color.fromRGBO(0, 0, 0, 0.1);

  // Tekst i Treść
  static const Color primaryText = Color(0xFF0B1727);
  static const Color secondaryText = Color(0xFF4B5B70);
  static const Color tertiaryText = Color(0xFF6B7A8F);

  // Akcenty i Statusy
  static const Color success = Color(0xFF23A36E);
  static const Color info = Color(0xFF2F80ED);
  static const Color infoAlpha = Color(0xCC2F80ED);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFE53935);

  // Obramowania
  static const Color border = Color(0xFFE1E6ED);
  static const Color inputBorder = Color(0xFFE1E6ED);
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primaryText),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primaryText),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.primaryText),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.baseBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.success,
        primary: AppColors.success,
        background: AppColors.baseBackground,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      
      // 3. Komponenty
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        elevation: 1,
        shadowColor: AppColors.surfaceDim,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.0)),
          side: BorderSide(color: AppColors.border),
        ),
        elevation: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          elevation: 1,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.info,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        space: 1,
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.baseBackground,
        labelStyle: textTheme.bodySmall,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        floatingLabelStyle: const TextStyle(color: AppColors.infoAlpha),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.info, width: 2.0),
        ),
      ),
    );
  }
}
