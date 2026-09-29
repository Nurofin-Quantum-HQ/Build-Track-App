import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:flutter/material.dart';
class AppGradients {
  AppGradients._();
  static LinearGradient get primaryButton => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.primary,
      AppColors.primary.withValues(alpha: 0.85),
      AppColors.primary.withValues(alpha: 0.7),
    ],
    stops: [0.0, 0.55, 1.0],
  );
  static LinearGradient get progressBar => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
    stops: [0.0, 1.0],
  );
  static LinearGradient get authBackground => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.authStart, AppColors.authMid, AppColors.authEnd],
    stops: [0.0, 0.5, 1.0],
  );
  static LinearGradient get navActiveItem => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFEAE6F8), Color(0xFFDDD6F5)],
  );
}
