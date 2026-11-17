import 'package:flutter/material.dart';

/// Adaptive palette — Stripe/Apple light by default, dark premium optional.
class AppColors {
  AppColors._();

  static bool _isLight = true;

  static bool get isLight => _isLight;

  static void setLight(bool value) {
    _isLight = value;
  }

  // —— Surfaces ——
  static Color get background =>
      _isLight ? const Color(0xFFF7F7F5) : const Color(0xFF0A0A0A);
  static Color get surface =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF161616);
  static Color get surfaceElevated =>
      _isLight ? const Color(0xFFF0F0EE) : const Color(0xFF1C1C1C);

  static Color get primary =>
      _isLight ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  static Color get primaryMuted =>
      _isLight ? const Color(0xFFE8E8E4) : const Color(0xFF2A2A2A);

  static Color get textPrimary =>
      _isLight ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  static Color get textSecondary =>
      _isLight ? const Color(0xFF5C5C5C) : const Color(0xFFA3A3A3);
  static Color get textTertiary =>
      _isLight ? const Color(0xFF8A8A8A) : const Color(0xFF6B6B6B);

  static Color get border =>
      _isLight ? const Color(0xFFE4E4E0) : const Color(0xFF2A2A2A);
  static Color get borderStrong =>
      _isLight ? const Color(0xFFD0D0CA) : const Color(0xFF3A3A3A);

  // —— Money ——
  static Color get income =>
      _isLight ? const Color(0xFF0F9F6E) : const Color(0xFF34D399);
  static Color get incomeSoft =>
      _isLight ? const Color(0xFFE3F7EF) : const Color(0xFF0F2E22);
  static Color get expense =>
      _isLight ? const Color(0xFFE5484D) : const Color(0xFFFF6B6B);
  static Color get expenseSoft =>
      _isLight ? const Color(0xFFFDECEC) : const Color(0xFF3A1518);
  static Color get warning =>
      _isLight ? const Color(0xFFC98400) : const Color(0xFFF0B429);
  static Color get warningSoft =>
      _isLight ? const Color(0xFFFFF4DE) : const Color(0xFF33280A);

  // —— Accents ——
  static Color get accent =>
      _isLight ? const Color(0xFF3B82F6) : const Color(0xFF5B9FFF);
  static Color get accentSoft =>
      _isLight ? const Color(0xFFEAF2FF) : const Color(0xFF122033);
  static Color get teal =>
      _isLight ? const Color(0xFF0D9488) : const Color(0xFF2DD4BF);

  static List<Color> get chartPalette => _isLight
      ? const [
          Color(0xFF3B82F6),
          Color(0xFF0F9F6E),
          Color(0xFFC98400),
          Color(0xFFE5484D),
          Color(0xFF0D9488),
          Color(0xFFEA580C),
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
        ]
      : const [
          Color(0xFF5B9FFF),
          Color(0xFF34D399),
          Color(0xFFF0B429),
          Color(0xFFFF6B6B),
          Color(0xFF2DD4BF),
          Color(0xFFFB923C),
          Color(0xFFA78BFA),
          Color(0xFFF472B6),
        ];

  static Color get navBar =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF121212);
  static Color get fab =>
      _isLight ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  static Color get fabIcon =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0A0A0A);

  static Color get shadow =>
      _isLight ? const Color(0x14000000) : const Color(0x73000000);

  static Color chartColor(int index) =>
      chartPalette[index % chartPalette.length];
}
