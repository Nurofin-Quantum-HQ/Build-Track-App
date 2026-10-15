import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:flutter/material.dart';

/// Legacy gradient names. The redesign has no decorative gradients:
/// these are solid fills of the active theme tint (DESIGN.md §2, §4).
class AppGradients {
  AppGradients._();
  static LinearGradient get primaryButton => LinearGradient(colors: [AppColors.primary, AppColors.primary]);
  static LinearGradient get progressBar => LinearGradient(colors: [AppColors.primary, AppColors.primary]);
  static const LinearGradient authBackground = LinearGradient(colors: [AppColors.bgBase1, AppColors.bgBase1]);
  static const LinearGradient navActiveItem = LinearGradient(colors: [AppColors.navActiveItemBg, AppColors.navActiveItemBg]);
}
