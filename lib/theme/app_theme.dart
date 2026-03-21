import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGold,
        secondary: AppColors.orangeAccent,
        surface: AppColors.darkSurface,
        background: AppColors.darkBackground,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sabotageDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.brightGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: AppColors.glowGold.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.blueDark,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.brightGold,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.cream,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Premium Decorations
  static BoxDecoration premiumCardDecoration = BoxDecoration(
    color: AppColors.darkSurface,
    borderRadius: BorderRadius.circular(15),
    border: Border.all(color: AppColors.blueDark, width: 0.5),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadow.withOpacity(0.3),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration goldGlowDecoration = BoxDecoration(
    gradient: AppColors.goldGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppColors.brightGold.withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
