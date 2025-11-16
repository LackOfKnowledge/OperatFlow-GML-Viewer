import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  runApp(const GmlViewerApp());
}

class GmlViewerApp extends StatelessWidget {
  const GmlViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color baseBackground = Color(0xFFF5F7FA);
    const Color surface = Color(0xFFFFFFFF);
    const Color primary = Color(0xFF2F80ED);
    const Color secondary = Color(0xFF4B5B70);
    const Color success = Color(0xFF23A36E);
    const Color warning = Color(0xFFF57C00);
    const Color error = Color(0xFFE53935);
    const Color onBackground = Color(0xFF0B1727);
    const Color border = Color(0xFFE1E6ED);

    final ColorScheme colorScheme = ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: onBackground,
    );

    return MaterialApp(
      title: 'OperatFlow GML Viewer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: baseBackground,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: surface,
          foregroundColor: onBackground,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
        ),
        dividerColor: border,
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onBackground,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onBackground,
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            color: onBackground,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            color: secondary,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: error,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: primary, width: 1.4),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            padding: const MaterialStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            side: MaterialStateProperty.resolveWith<BorderSide?>(
              (states) {
                if (states.contains(MaterialState.selected)) {
                  return const BorderSide(color: primary, width: 1.4);
                }
                return const BorderSide(color: border);
              },
            ),
            backgroundColor: MaterialStateProperty.resolveWith<Color?>(
              (states) {
                if (states.contains(MaterialState.selected)) {
                  return primary.withOpacity(0.08);
                }
                return surface;
              },
            ),
            foregroundColor: MaterialStateProperty.resolveWith<Color?>(
              (states) {
                if (states.contains(MaterialState.selected)) {
                  return primary;
                }
                return onBackground;
              },
            ),
          ),
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor:
              MaterialStatePropertyAll<Color>(Color(0xFFF0F3F9)),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: onBackground,
          ),
          dataTextStyle: TextStyle(
            fontSize: 13,
            color: onBackground,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
