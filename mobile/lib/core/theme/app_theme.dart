
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ============================================================
  // OFFICIAL MICROBLOG COLORS
  // ============================================================

  // Brand
  static const Color roseAccent = Color(0xFFF91880);

  // Dark theme
  static const Color darkBackground = Color(0xFF08090B);
  static const Color darkSurface = Color(0xFF15171B);
  static const Color darkSecondarySurface = Color(0xFF202329);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF9297A0);
  static const Color darkDivider = Color(0xFF282B31);
  static const Color darkButtonIcon = Color(0xFFFFFFFF);

  // Light theme
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSecondarySurface = Color(0xFFF0F1F4);
  static const Color lightPrimaryText = Color(0xFF111318);
  static const Color lightSecondaryText = Color(0xFF737B86);
  static const Color lightDivider = Color(0xFFE6E8EC);
  static const Color lightButtonIcon = Color(0xFF111318);

  // ============================================================
  // DESIGN DIMENSIONS
  // ============================================================

  static const double screenPadding = 16;
  static const double cardRadius = 16;
  static const double buttonRadius = 12;
  static const double inputRadius = 12;
  static const double smallRadius = 8;

  static const double iconSize = 24;
  static const double minimumTouchTarget = 48;

  static const double navigationHeight = 70;
  static const Duration animationDuration =
      Duration(milliseconds: 180);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData lightTheme = ThemeData(
    fontFamily: GoogleFonts.roboto().fontFamily,
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    primaryColor: roseAccent,
    colorScheme: const ColorScheme.light(
      primary: roseAccent,
      onPrimary: Colors.white,
      secondary: roseAccent,
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightPrimaryText,
      error: Color(0xFFDC2626),
      onError: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: lightBackground,
      foregroundColor: lightPrimaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: lightPrimaryText,
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: const CardThemeData(
      color: lightSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(cardRadius),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSecondarySurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(inputRadius),
  borderSide: const BorderSide(
    color: roseAccent,
    width: 1.3,
  ),
),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
        ),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: lightDivider,
      thickness: 1,
      space: 1,
    ),

    iconTheme: const IconThemeData(
      color: lightButtonIcon,
      size: iconSize,
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: lightPrimaryText,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: lightPrimaryText,
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: lightPrimaryText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: lightPrimaryText,
        fontSize: 15,
      ),
      bodyMedium: TextStyle(
        color: lightSecondaryText,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: lightSecondaryText,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        color: lightPrimaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimaryText,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: roseAccent,
        minimumSize: const Size(48, 48),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: lightPrimaryText,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: lightDivider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),

    splashFactory: InkRipple.splashFactory,
  );

  // ============================================================
  // DARK THEME
  // ============================================================

  static ThemeData darkTheme = ThemeData(
    fontFamily: GoogleFonts.roboto().fontFamily,
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: roseAccent,
    colorScheme: const ColorScheme.dark(
      primary: roseAccent,
      onPrimary: Colors.white,
      secondary: roseAccent,
      onSecondary: Colors.white,
      surface: darkSurface,
      onSurface: darkPrimaryText,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: darkBackground,
      foregroundColor: darkPrimaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: darkPrimaryText,
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: const CardThemeData(
      color: darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(cardRadius),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSecondarySurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(inputRadius),
  borderSide: const BorderSide(
    color: roseAccent,
    width: 1.3,
  ),
),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
        ),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: darkDivider,
      thickness: 1,
      space: 1,
    ),

    iconTheme: const IconThemeData(
      color: darkButtonIcon,
      size: iconSize,
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: darkPrimaryText,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: darkPrimaryText,
        fontSize: 23,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: darkPrimaryText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: darkPrimaryText,
        fontSize: 15,
      ),
      bodyMedium: TextStyle(
        color: darkSecondaryText,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: darkSecondaryText,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        color: darkPrimaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkButtonIcon,
        foregroundColor: darkBackground,
        minimumSize: const Size(48, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: roseAccent,
        minimumSize: const Size(48, 48),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkPrimaryText,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: darkDivider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),

    splashFactory: InkRipple.splashFactory,
  );
}
