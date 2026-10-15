import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buildtrack_mobile/design/bt_theme.dart';
class AppTheme {
  AppTheme._();
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static Color primary = AppColors.primaryBlue;
  static Color primaryLight = AppColors.primaryLightBlue;
  static Color secondary = AppColors.primaryPurple;
  static const Color surface = AppColors.cardBg;
  static const Color background = AppColors.bgBase1;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;
  static const Color info = AppColors.info;
  static const Color textDark = AppColors.textPrimary;
  static const Color textMedium = AppColors.textMedium;
  static const Color textLight = AppColors.textSecondary;
  static const Color border = AppColors.cardBorder;
  static const Color divider = AppColors.divider;
  // Redesign: flat surfaces — separation by hairline border, not shadow.
  static final List<BoxShadow> premiumShadow = [];
  static const List<BoxShadow> cardShadows = [];
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.bgBase1, AppColors.bgBase3, AppColors.bgBase4],
  );
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.cardBorder, width: 1),
    boxShadow: premiumShadow,
  );
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
  );
  static final ButtonStyle outlineButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    minimumSize: const Size.fromHeight(52),
    side: const BorderSide(color: AppColors.cardBorder, width: 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
  );
  static final TextStyle heading1 = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.56,
    height: 36 / 28,
  );
  static final TextStyle heading2 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  static final TextStyle heading3 = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 22 / 17,
  );
  static final TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 22 / 16,
  );
  static final TextStyle body = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.45,
  );
  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static final TextStyle label = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static ThemeData get lightTheme => build(BtTheme.forPreset(BtPreset.harbor));

  /// ThemeData for the active design theme (DESIGN.md §5).
  static ThemeData build(BtTheme bt) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      extensions: [bt],
      colorScheme: ColorScheme.fromSeed(seedColor: bt.brand).copyWith(
        primary: bt.brand,
        onPrimary: Colors.white,
        secondary: bt.brand,
        surface: Bt.card,
        onSurface: Bt.ink,
        error: Bt.red,
        outline: Bt.inputBorder,
        outlineVariant: Bt.line,
        surfaceTint: Colors.transparent,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(bodyColor: Bt.ink, displayColor: Bt.ink),
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: Bt.ground,
      canvasColor: Bt.ground,
      appBarTheme: AppBarTheme(
        backgroundColor: Bt.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: Bt.ink),
        foregroundColor: Bt.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Bt.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard), side: const BorderSide(color: Bt.line)),
      ),
      dividerTheme: const DividerThemeData(color: Bt.line, thickness: 1, space: 0),
      dividerColor: Bt.line,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Bt.card,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Bt.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Bt.card,
        surfaceTintColor: Colors.transparent,
        barrierColor: Bt.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Bt.ink),
        contentTextStyle: GoogleFonts.inter(fontSize: 16, color: Bt.ink2, height: 1.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Bt.ink,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bt.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rButton)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Bt.ink,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: Bt.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rButton)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: bt.brand, textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Bt.card,
        selectedColor: bt.brand,
        side: const BorderSide(color: Bt.line),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Bt.ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bt.brand : Bt.inputBorder),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bt.brand : Colors.transparent),
        side: const BorderSide(color: Bt.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bt.brand : Bt.inputBorder)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: bt.brand, linearTrackColor: Bt.fill),
      tabBarTheme: TabBarThemeData(labelColor: Bt.ink, unselectedLabelColor: Bt.ink2, indicatorColor: bt.brand, dividerColor: Bt.line),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: bt.brand, foregroundColor: Colors.white, elevation: 2),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Bt.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: b(Bt.inputBorder),
        enabledBorder: b(Bt.inputBorder),
        focusedBorder: b(bt.brand, 2),
        errorBorder: b(Bt.red),
        focusedErrorBorder: b(Bt.red, 2),
        hintStyle: GoogleFonts.inter(color: Bt.placeholder, fontSize: 16, fontWeight: FontWeight.w400),
        labelStyle: GoogleFonts.inter(color: Bt.ink2, fontSize: 15),
      ),
    );
  }
}
