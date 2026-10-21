import 'package:flutter/material.dart';

/// Legacy colour names, remapped to the Design V2 "Blueprint Noir" tokens.
/// New code should use `lib/design` (Bt / context.bt) instead.
/// `primary` is set at runtime by ThemeProvider to the active theme's tint.
class AppColors {
  AppColors._();
  static const Color primaryBlue = Color(0xFF111317);
  static const Color primaryPurple = Color(0xFF111317);
  static const Color primaryLightBlue = Color(0xFF111317);
  static const Color bgBase1 = Color(0xFFF2F0EB);
  static const Color bgBase2 = Color(0xFFF2F0EB);
  static const Color bgBase3 = Color(0xFFF2F0EB);
  static const Color bgBase4 = Color(0xFFF2F0EB);
  static const Color bgGlow1 = Color(0xFFF2F0EB);
  static const Color bgGlow2 = Color(0xFFF2F0EB);
  static const Color bgGlow3 = Color(0xFFF2F0EB);
  static const Color authStart = Color(0xFFF2F0EB);
  static const Color authMid = Color(0xFFF2F0EB);
  static const Color authEnd = Color(0xFFF2F0EB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE6E3DC);
  static const Color textPrimary = Color(0xFF111317);
  static const Color textSecondary = Color(0xFF6F7582);
  static const Color textBlue = Color(0xFF111317);
  static const Color textAmount = Color(0xFF111317);
  static const Color badgeWarningBg = Color(0xFFFCEFD9);
  static const Color badgeWarningText = Color(0xFF935600);
  static const Color badgeSuccessBg = Color(0xFFDDF3EA);
  static const Color badgeSuccessText = Color(0xFF067A52);
  static const Color badgePendingBg = Color(0xFFFCEFD9);
  static const Color badgePendingText = Color(0xFF935600);
  static const Color badgeInfoBg = Color(0xFFEFEDE8);
  static const Color badgeInfoText = Color(0xFF111317);
  static const Color navActiveItemBg = Color(0xFFEFEDE8);
  static const Color navActiveBorder = Color(0xFF111317);
  static const Color navText = Color(0xFF525864);
  static const Color navActiveText = Color(0xFF111317);
  static const Color divider = Color(0xFFE6E3DC);
  static const Color inputBorder = Color(0xFFD8D4CB);
  static const Color iconBg = Color(0xFFEFEDE8);
  static const Color success = Color(0xFF067A52);
  static const Color warning = Color(0xFF935600);
  static const Color error = Color(0xFFBE2A30);
  static const Color info = Color(0xFF111317);
  static Color primary = primaryBlue;
  static Color primaryLight = primaryLightBlue;
  static const Color primarySurface = iconBg;
  static const Color sidebarBg = cardBg;
  static const Color sidebarActive = navActiveItemBg;
  static const Color textDark = textPrimary;
  static const Color textMedium = Color(0xFF525864);
  static const Color textLight = textSecondary;
  static const Color border = cardBorder;
  static const Color gradientStart = bgBase1;
  static const Color gradientMid = bgBase3;
  static const Color gradientEnd = bgBase4;
}
