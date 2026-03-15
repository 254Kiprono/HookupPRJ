import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hook_app/utils/constants.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppConstants.primaryColor,
      scaffoldBackgroundColor: AppConstants.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppConstants.primaryColor,
        secondary: AppConstants.secondaryColor,
        surface: Colors.white,
        background: AppConstants.lightBackground,
        error: AppConstants.errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme()
          .copyWith(
            displayLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
            displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w700),
            displaySmall: GoogleFonts.sora(fontWeight: FontWeight.w700),
            headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w700),
            headlineMedium: GoogleFonts.sora(fontWeight: FontWeight.w600),
            headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w600),
            titleLarge: GoogleFonts.sora(fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.sora(fontWeight: FontWeight.w600),
            titleSmall: GoogleFonts.sora(fontWeight: FontWeight.w600),
          )
          .apply(
            bodyColor: AppConstants.darkBackground,
            displayColor: AppConstants.primaryColor,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppConstants.darkBackground),
        titleTextStyle: TextStyle(
          color: AppConstants.darkBackground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppConstants.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppConstants.secondaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppConstants.primaryColor,
      scaffoldBackgroundColor: AppConstants.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.primaryColor,
        secondary: AppConstants.secondaryColor,
        surface: AppConstants.cardNavy,
        background: AppConstants.darkBackground,
        error: AppConstants.errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.sora(fontWeight: FontWeight.w700, color: AppConstants.softWhite),
            displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w700, color: AppConstants.softWhite),
            displaySmall: GoogleFonts.sora(fontWeight: FontWeight.w700, color: AppConstants.softWhite),
            headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w700, color: AppConstants.softWhite),
            headlineMedium: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppConstants.softWhite),
            headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppConstants.softWhite),
            titleLarge: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppConstants.softWhite),
            titleMedium: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppConstants.softWhite),
            titleSmall: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppConstants.softWhite),
            bodyLarge: GoogleFonts.inter(color: AppConstants.softWhite),
            bodyMedium: GoogleFonts.inter(color: AppConstants.softWhite),
            bodySmall: GoogleFonts.inter(color: AppConstants.mutedGray),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.darkBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppConstants.softWhite),
        titleTextStyle: TextStyle(
          color: AppConstants.softWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Sora',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.cardNavy,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppConstants.tealLight, width: 1),
        ),
        hintStyle: GoogleFonts.inter(color: AppConstants.mutedGray, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: AppConstants.cardNavy,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
    );
  }
}
