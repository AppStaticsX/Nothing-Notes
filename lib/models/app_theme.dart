import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final Color backgroundColor;
  final Color primaryColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color cardColor;
  final Color accentColor;
  final List<Color> colorPalette;

  const AppTheme({
    required this.name,
    required this.backgroundColor,
    required this.primaryColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.cardColor,
    required this.accentColor,
    required this.colorPalette,
  });

  static const oledBlack = AppTheme(
    name: 'OLED Black',
    backgroundColor: Color(0xFF000000),
    primaryColor: Color(0xFF5C9EFF),
    textColor: Color(0xFFFFFFFF),
    secondaryTextColor: Color(0xFF9E9E9E),
    cardColor: Color(0xFF1A1A1A),
    accentColor: Color(0xFF5C9EFF),
    colorPalette: [
      Color(0xFF1A1A1A),
      Color(0xFF2D2D2D),
      Color(0xFF5C9EFF),
      Color(0xFF6BB6FF),
      Color(0xFF4ECDC4),
      Color(0xFFFFFFFF),
    ],
  );

  static const light = AppTheme(
    name: 'Light',
    backgroundColor: Color(0xFFFFFFFF),
    primaryColor: Color(0xFF5C9EFF),
    textColor: Color(0xFF000000),
    secondaryTextColor: Color(0xFF757575),
    cardColor: Color(0xFFF5F5F5),
    accentColor: Color(0xFF5C9EFF),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFF5F5F5),
      Color(0xFF5C9EFF),
      Color(0xFF6BB6FF),
      Color(0xFF4ECDC4),
      Color(0xFF000000),
    ],
  );

  static const dark = AppTheme(
    name: 'Dark',
    backgroundColor: Color(0xFF121212),
    primaryColor: Color(0xFF5C9EFF),
    textColor: Color(0xFFFFFFFF),
    secondaryTextColor: Color(0xFFB0B0B0),
    cardColor: Color(0xFF1E1E1E),
    accentColor: Color(0xFF5C9EFF),
    colorPalette: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
      Color(0xFF5C9EFF),
      Color(0xFF6BB6FF),
      Color(0xFF4ECDC4),
      Color(0xFFFFFFFF),
    ],
  );

  static const sepia = AppTheme(
    name: 'Sepia',
    backgroundColor: Color(0xFFF4ECD8),
    primaryColor: Color(0xFFD97706),
    textColor: Color(0xFF3E2723),
    secondaryTextColor: Color(0xFF8D6E63),
    cardColor: Color(0xFFE8DCC4),
    accentColor: Color(0xFFD97706),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFF4ECD8),
      Color(0xFFFBBF24),
      Color(0xFFD97706),
      Color(0xFF4ECDC4),
      Color(0xFF78350F),
    ],
  );

  static const highContrast = AppTheme(
    name: 'High Contrast',
    backgroundColor: Color(0xFF000000),
    primaryColor: Color(0xFF0000FF),
    textColor: Color(0xFFFFFFFF),
    secondaryTextColor: Color(0xFFCCCCCC),
    cardColor: Color(0xFF0A0A0A),
    accentColor: Color(0xFF00FF00),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFEEEEEE),
      Color(0xFF0000FF),
      Color(0xFF4169E1),
      Color(0xFF00FF00),
      Color(0xFF000000),
    ],
  );

  static const forest = AppTheme(
    name: 'Forest',
    backgroundColor: Color(0xFF1B2A1E),
    primaryColor: Color(0xFF4ADE80),
    textColor: Color(0xFFE0F2E9),
    secondaryTextColor: Color(0xFF94A89C),
    cardColor: Color(0xFF2A3B2E),
    accentColor: Color(0xFF4ADE80),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFE0F2E9),
      Color(0xFF4ADE80),
      Color(0xFF22C55E),
      Color(0xFF10B981),
      Color(0xFF064E3B),
    ],
  );

  static const ocean = AppTheme(
    name: 'Ocean',
    backgroundColor: Color(0xFF0C1821),
    primaryColor: Color(0xFF06B6D4),
    textColor: Color(0xFFE0F2FE),
    secondaryTextColor: Color(0xFF7DD3FC),
    cardColor: Color(0xFF1E3A47),
    accentColor: Color(0xFF06B6D4),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFBFDBFE),
      Color(0xFF0EA5E9),
      Color(0xFF06B6D4),
      Color(0xFF14B8A6),
      Color(0xFF134E4A),
    ],
  );

  static const dusk = AppTheme(
    name: 'Dusk',
    backgroundColor: Color(0xFF1E1428),
    primaryColor: Color(0xFFC084FC),
    textColor: Color(0xFFF3E8FF),
    secondaryTextColor: Color(0xFFD8B4FE),
    cardColor: Color(0xFF2E1F3E),
    accentColor: Color(0xFFC084FC),
    colorPalette: [
      Color(0xFF4C1D95),
      Color(0xFF6B21A8),
      Color(0xFFA855F7),
      Color(0xFFC084FC),
      Color(0xFF4ECDC4),
      Color(0xFFFFFFFF),
    ],
  );

  static const solar = AppTheme(
    name: 'Solar',
    backgroundColor: Color(0xFFFEF3C7),
    primaryColor: Color(0xFFF59E0B),
    textColor: Color(0xFF78350F),
    secondaryTextColor: Color(0xFFA16207),
    cardColor: Color(0xFFFEF9E7),
    accentColor: Color(0xFFF59E0B),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFFEF3C7),
      Color(0xFFFBBF24),
      Color(0xFFF59E0B),
      Color(0xFF4ECDC4),
      Color(0xFFB45309),
    ],
  );

  static const graphite = AppTheme(
    name: 'Graphite',
    backgroundColor: Color(0xFF2C2C2E),
    primaryColor: Color(0xFF8E8E93),
    textColor: Color(0xFFE5E5E7),
    secondaryTextColor: Color(0xFF98989D),
    cardColor: Color(0xFF3A3A3C),
    accentColor: Color(0xFF4ECDC4),
    colorPalette: [
      Color(0xFFFFFFFF),
      Color(0xFFE5E5E7),
      Color(0xFF8E8E93),
      Color(0xFF636366),
      Color(0xFF4ECDC4),
      Color(0xFF1C1C1E),
    ],
  );

  static const nothingLight = AppTheme(
    name: 'Nothing-Light',
    backgroundColor: Color(0xFFFFFFFF),
    primaryColor: Color(0xFFFF0000),
    textColor: Color(0xFF000000),
    secondaryTextColor: Color(0xFF666666),
    cardColor: Color(0xFFF5F5F5),
    accentColor: Color(0xFFFF0000),
    colorPalette: [
      Color(0xFFFFFFFF),  // Pure white
      Color(0xFFF5F5F5),  // Off-white/light gray
      Color(0xFF000000),  // Pure black
      Color(0xFF333333),  // Dark gray
      Color(0xFFFF0000),  // Nothing red accent
      Color(0xFFE0E0E0),  // Light gray
    ],
  );

  static const nothingDark = AppTheme(
    name: 'Nothing-Dark',
    backgroundColor: Color(0xFF121212),
    primaryColor: Color(0xFFFF0000),
    textColor: Color(0xFFFFFFFF),
    secondaryTextColor: Color(0xFF999999),
    cardColor: Color(0xFF1A1A1A),
    accentColor: Color(0xFFFF0000),
    colorPalette: [
      Color(0xFF121212),  // Pure black
      Color(0xFF1A1A1A),  // Dark gray
      Color(0xFFFFFFFF),  // Pure white
      Color(0xFFCCCCCC),  // Light gray
      Color(0xFFFF0000),  // Nothing red accent
      Color(0xFF2A2A2A),  // Medium dark gray
    ],
  );

  static List<AppTheme> get allThemes => [
    oledBlack,
    light,
    dark,
    sepia,
    highContrast,
    forest,
    ocean,
    dusk,
    solar,
    graphite,
    nothingLight,
    nothingDark
  ];

  ThemeData toThemeData() {
    return ThemeData(
      brightness: backgroundColor.computeLuminance() > 0.5
          ? Brightness.light
          : Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme(
        brightness: backgroundColor.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark,
        primary: primaryColor,
        onPrimary: textColor,
        secondary: accentColor,
        onSecondary: textColor,
        error: Colors.red,
        onError: Colors.white,
        surface: cardColor,
        onSurface: textColor,
      ),
      cardColor: cardColor,
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textColor, fontSize: 16),
        bodyMedium: TextStyle(color: secondaryTextColor, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: secondaryTextColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
    );
  }
}