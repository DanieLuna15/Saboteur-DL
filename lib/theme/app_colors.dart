import 'package:flutter/material.dart';

class AppColors {
  // 🟡 Colores principales (branding)
  static const Color primaryGold = Color(0xFFF2A900);
  static const Color brightGold = Color(0xFFFFC857);
  static const Color orangeAccent = Color(0xFFFF8C42);

  // 🌑 Fondos y modo oscuro
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF2C2C2C);
  static const Color blueDark = Color(0xFF2F3E46);

  // 🟤 Tierra / mina (ambientación)
  static const Color brownPrimary = Color(0xFF5A3E2B);
  static const Color brownSoft = Color(0xFF7A5230);

  // ✨ Luz / efectos (linterna, oro, brillo)
  static const Color lightWarm = Color(0xFFFFF3D1);
  static const Color cream = Color(0xFFF5E6C8);
  static const Color glowGold = Color(0xFFFFD166);

  // ⚫ Saboteador (lado oscuro)
  static const Color sabotageDark = Color(0xFF121212);
  static const Color shadow = Color(0xFF000000);

  // Gradients for premium UI
  static const LinearGradient goldGradient = LinearGradient(
    colors: [primaryGold, orangeAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBackground, sabotageDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
