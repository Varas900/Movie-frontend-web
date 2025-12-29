import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primaryColor = Color(0xFF1a1a1a); // Dark background
  static const Color secondaryColor = Color(0xFFff6b6b); // Red accent
  static const Color accentColor = Color(0xFFfeca57); // Yellow accent
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFf8f9fa);
  static const Color lightSurface = Color(0xFFffffff);
  static const Color lightOnPrimary = Color(0xFFffffff);
  static const Color lightOnSurface = Color(0xFF212529);
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0d1117);
  static const Color darkSurface = Color(0xFF161b22);
  static const Color darkOnPrimary = Color(0xFFffffff);
  static const Color darkOnSurface = Color(0xFFf0f6fc);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF2c3e50), Color(0xFF3498db)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Styles
  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
  );
  
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );
  
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      background: lightBackground,
      surface: lightSurface,
      onPrimary: lightOnPrimary,
      onSurface: lightOnSurface,
      error: Color(0xFFd32f2f),
    ),
    textTheme: TextTheme(
      headlineLarge: headlineLarge.copyWith(color: lightOnSurface),
      headlineMedium: headlineMedium.copyWith(color: lightOnSurface),
      titleLarge: titleLarge.copyWith(color: lightOnSurface),
      titleMedium: titleMedium.copyWith(color: lightOnSurface),
      bodyLarge: bodyLarge.copyWith(color: lightOnSurface),
      bodyMedium: bodyMedium.copyWith(color: lightOnSurface),
      labelLarge: labelLarge.copyWith(color: lightOnSurface),
    ),
    cardTheme: const CardTheme(
      elevation: 2,
      margin: EdgeInsets.all(8),
      color: lightSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: lightOnSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: titleLarge.copyWith(color: lightOnSurface),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: lightOnPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFe0e0e0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFe0e0e0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: secondaryColor,
      secondary: accentColor,
      tertiary: Color(0xFF4fc3f7),
      background: darkBackground,
      surface: darkSurface,
      onPrimary: darkOnPrimary,
      onSurface: darkOnSurface,
      error: Color(0xFFef5350),
    ),
    textTheme: TextTheme(
      headlineLarge: headlineLarge.copyWith(color: darkOnSurface),
      headlineMedium: headlineMedium.copyWith(color: darkOnSurface),
      titleLarge: titleLarge.copyWith(color: darkOnSurface),
      titleMedium: titleMedium.copyWith(color: darkOnSurface),
      bodyLarge: bodyLarge.copyWith(color: darkOnSurface),
      bodyMedium: bodyMedium.copyWith(color: darkOnSurface),
      labelLarge: labelLarge.copyWith(color: darkOnSurface),
    ),
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: darkSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkOnSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: titleLarge.copyWith(color: darkOnSurface),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        foregroundColor: darkOnPrimary,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363d)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363d)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: secondaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );

  // Custom Colors for specific use cases
  static const Color successColor = Color(0xFF4caf50);
  static const Color warningColor = Color(0xFFff9800);
  static const Color infoColor = Color(0xFF2196f3);
  
  // Movie Rating Colors
  static Color getRatingColor(double? rating) {
    if (rating == null) return Colors.grey;
    if (rating >= 8.0) return successColor;
    if (rating >= 6.0) return warningColor;
    return const Color(0xFFf44336);
  }
  
  // Subscription plan colors removed
  
  // Genre Colors
  static const List<Color> genreColors = [
    Color(0xFFe74c3c),
    Color(0xFF3498db),
    Color(0xFF2ecc71),
    Color(0xFFf39c12),
    Color(0xFF9b59b6),
    Color(0xFF1abc9c),
    Color(0xFFe67e22),
    Color(0xFF34495e),
  ];
  
  static Color getGenreColor(int index) {
    return genreColors[index % genreColors.length];
  }
}