import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFFF4F5F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFF111111);
  static const Color secondaryText = Color(0xFF4B5563);
  static const Color dividerColor = Color(0xFFDFE2E6);
  static const Color inputFill = Color(0xFFFFFFFF);

  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF181B20);
  static const Color darkSurfaceContainer = Color(0xFF22262E);
  static const Color darkDividerColor = Color(0xFF2D333D);
  static const Color darkOnSurface = Color(0xFFF1F3F5);
  static const Color darkSecondaryText = Color(0xFF9CA3AF);

  static Color getSecondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSecondaryText
        : secondaryText;
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primaryDark,
      colorScheme: const ColorScheme.light(
        primary: primaryDark,
        secondary: secondaryText,
        surface: surface,
        surfaceContainerHighest: Color(0xFFF1F3F5),
        onSurface: Color(0xFF111111),
        onPrimary: Colors.white,
        outline: dividerColor,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: const Color(0xFF111111),
        displayColor: const Color(0xFF111111),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111111),
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: Colors.white,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: Color(0xFF94A3B8),
        surface: darkSurface,
        surfaceContainerHighest: darkSurfaceContainer,
        onSurface: darkOnSurface,
        onPrimary: darkBackground,
        outline: darkDividerColor,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: darkOnSurface,
        displayColor: darkOnSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: darkOnSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: darkOnSurface),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkDividerColor, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceContainer,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: darkOnSurface, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: darkDividerColor,
        thickness: 1,
      ),
    );
  }

  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = const Color(0xFF111111),
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
    );
  }
}
