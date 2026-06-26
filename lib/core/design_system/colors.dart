import 'package:flutter/material.dart';

// Existing color constants (kept for backward compatibility)
const black = Colors.black;
const black54 = Colors.black54;
const white = Colors.white;
const blue = Colors.blue;
const orange = Colors.orange;
const green = Colors.green;
const red = Colors.red;
const transparent = Colors.transparent;

/// NigerGram Design System Colors
class NGColors {
  // Backgrounds
  static const Color background = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF2A2A2A);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.grey;

  // Brand / Accent
  static const Color accent = Color(0xFFFF0050); // NigerGram Red/Pink
  static const Color accentGold = Color(0xFFFFD700); // 👈 ADD THIS
  static const Color accentBlue = Color(0xFF0088FF);
  static const Color accentPurple = Color(0xFF8B00FF);
  static const Color accentGreen = Color(0xFF00C853);

  // Borders / Dividers
  static const Color divider = Color(0xFF3A3A3A);
  
  // Status
  static const Color success = Color(0xFF00C853); // 👈 ADD THIS
  static const Color error = Color(0xFFFF1744); // 👈 ADD THIS
  static const Color warning = Color(0xFFFFD600); // 👈 ADD THIS
}
