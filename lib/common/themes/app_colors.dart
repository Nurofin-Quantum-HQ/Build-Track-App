import 'package:flutter/material.dart';

/// Legacy colour names, remapped to the redesign tokens (DESIGN.md §4).
/// New code should use `lib/design` (Bt / context.bt) instead.
/// `primary` is set at runtime by ThemeProvider to the active theme's tint.
class AppColors {
  AppColors._();
  static const Color primaryBlue = Color(0xFF0B63CE);
  static const Color primaryPurple = Color(0xFF0B63CE);
  static const Color primaryLightBlue = Color(0xFF0B63CE);
  static const Color bgBase1 = Color(0xFFF6F7F9);
  static const Color bgBase2 = Color(0xFFF6F7F9);
  static const Color bgBase3 = Color(0xFFF6F7F9);
  static const Color bgBase4 = Color(0xFFF6F7F9);
  static const Color bgGlow1 = Color(0xFFF6F7F9);
  static const Color bgGlow2 = Color(0xFFF6F7F9);
  static const Color bgGlow3 = Color(0xFFF6F7F9);
  static const Color authStart = Color(0xFFF6F7F9);
  static const Color authMid = Color(0xFFF6F7F9);
  static const Color authEnd = Color(0xFFF6F7F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE4E7EC);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textBlue = Color(0xFF0B63CE);
  static const Color textAmount = Color(0xFF101828);
  static const Color badgeWarningBg = Color(0xFFFEF3E7);
  static const Color badgeWarningText = Color(0xFFB54708);
  static const Color badgeSuccessBg = Color(0xFFE7F6EE);
  static const Color badgeSuccessText = Color(0xFF067647);
  static const Color badgePendingBg = Color(0xFFFEF3E7);
  static const Color badgePendingText = Color(0xFFB54708);
  static const Color badgeInfoBg = Color(0xFFE8F1FC);
  static const Color badgeInfoText = Color(0xFF0B63CE);
  static const Color navActiveItemBg = Color(0xFFEEF1F5);
  static const Color navActiveBorder = Color(0xFF0B63CE);
  static const Color navText = Color(0xFF475467);
  static const Color navActiveText = Color(0xFF0B63CE);
  static const Color divider = Color(0xFFE4E7EC);
  static const Color inputBorder = Color(0xFFD0D5DD);
  static const Color iconBg = Color(0xFFEEF1F5);
  static const Color success = Color(0xFF067647);
  static const Color warning = Color(0xFFB54708);
  static const Color error = Color(0xFFC01048);
  static const Color info = Color(0xFF0B63CE);
  static Color primary = primaryBlue;
  static Color primaryLight = primaryLightBlue;
  static const Color primarySurface = iconBg;
  static const Color sidebarBg = cardBg;
  static const Color sidebarActive = navActiveItemBg;
  static const Color textDark = textPrimary;
  static const Color textMedium = Color(0xFF475467);
  static const Color textLight = textSecondary;
  static const Color border = cardBorder;
  static const Color gradientStart = bgBase1;
  static const Color gradientMid = bgBase3;
  static const Color gradientEnd = bgBase4;
}
