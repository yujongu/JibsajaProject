import 'package:flutter/material.dart';

abstract final class AppColors {
  // --- Primary Blue (Toss-style deep blue) ---
  static const primary = Color(0xFF0055B2);
  static const primaryLight = Color(0xFF006DE0); // primary-container
  static const primaryDark = Color(0xFF004491);
  static const primaryMuted = Color(0xFFACC7FF); // inverse-primary
  static const secondaryFallback = Color(0xFF0891B2); // cyan-600, USD accent

  // --- Light Theme Surfaces (Material Design 3 tokens) ---
  static const background = Color(0xFFF8F9FB);
  static const surface = Color(0xFFF8F9FB);
  static const surfaceCard = Color(0xFFFFFFFF); // surface-container-lowest
  static const surfaceContainerLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const surfaceContainerHigh = Color(0xFFE6E8EA);
  static const surfaceContainerHighest = Color(0xFFE0E3E5);
  static const lightBorder = Color(0xFFC2C6D8); // outline-variant

  // --- Dark Theme Surfaces ---
  static const darkBackground = Color(0xFF080D1A);
  static const darkSurface = Color(0xFF0E1525);
  static const darkCard = Color(0xFF131D30);
  static const darkBorder = Color(0xFF1E2D47);
  static const darkDivider = Color(0xFF1A2540);

  // --- Text (light mode) ---
  static const textPrimaryLight = Color(0xFF191C1E); // on-surface
  static const textSecondaryLight = Color(0xFF424656); // on-surface-variant
  static const textTertiaryLight = Color(0xFF737687); // outline

  // --- Text (dark mode) ---
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF4B5E7A);

  // --- Semantic Colors ---
  static const positive = Color(0xFF059669); // emerald-600
  static const positiveSubtle = Color(0xFFECFDF5); // emerald-50
  static const negative = Color(0xFFBA1A1A); // error
  static const negativeSubtle = Color(0xFFFFDAD6); // error-container
  static const warning = Color(0xFFF59E0B);

  // --- Card Shadow ---
  static const cardShadow = Color(0x0A0055B2); // rgba(0,85,178,0.04)

  // --- Legacy gradient aliases (used by dark mode gradient background) ---
  static const darkGradientStart = Color(0xFF080D1A);
  static const darkGradientMid = Color(0xFF0B1528);
  static const darkGradientEnd = Color(0xFF080D1A);

  // --- Primary gradient (for account cards, FAB) ---
  static const primaryGradientStart = Color(0xFF0055B2);
  static const primaryGradientEnd = Color(0xFF006DE0);
}
