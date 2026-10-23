import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:flutter/cupertino.dart';
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
    textStyle: GoogleFonts.instrumentSans(fontSize: 17, fontWeight: FontWeight.w600),
  );
  static final ButtonStyle outlineButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    minimumSize: const Size.fromHeight(52),
    side: const BorderSide(color: AppColors.cardBorder, width: 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: GoogleFonts.instrumentSans(fontSize: 16, fontWeight: FontWeight.w600),
  );
  static final TextStyle heading1 = GoogleFonts.bricolageGrotesque(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.56,
    height: 36 / 28,
  );
  static final TextStyle heading2 = GoogleFonts.bricolageGrotesque(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  static final TextStyle heading3 = GoogleFonts.instrumentSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 22 / 17,
  );
  static final TextStyle bodyLarge = GoogleFonts.instrumentSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 22 / 16,
  );
  static final TextStyle body = GoogleFonts.instrumentSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    height: 1.45,
  );
  static final TextStyle caption = GoogleFonts.instrumentSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static final TextStyle label = GoogleFonts.instrumentSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static ThemeData get lightTheme => build(BtTheme.forPreset(BtPreset.brass));

  /// ThemeData for the active design theme (DESIGN.md §5).
  static ThemeData build(BtTheme bt) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Bt.rInput),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      extensions: [bt],
      colorScheme: ColorScheme.fromSeed(seedColor: bt.brand).copyWith(
        primary: bt.brand,
        onPrimary: Bt.bone,
        secondary: bt.accent,
        onSecondary: bt.onAccent,
        surface: Bt.card,
        onSurface: Bt.ink,
        error: Bt.red,
        outline: Bt.inputBorder,
        outlineVariant: Bt.line,
        surfaceTint: Colors.transparent,
      ),
      textTheme: GoogleFonts.instrumentSansTextTheme().apply(bodyColor: Bt.ink, displayColor: Bt.ink),
      fontFamily: GoogleFonts.instrumentSans().fontFamily,
      scaffoldBackgroundColor: Bt.ground,
      canvasColor: Bt.ground,
      appBarTheme: AppBarTheme(
        backgroundColor: Bt.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.instrumentSans(fontSize: 17, fontWeight: FontWeight.w600, color: Bt.ink),
        foregroundColor: Bt.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Bt.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: GoogleFonts.bricolageGrotesque(fontSize: 21, fontWeight: FontWeight.w700, color: Bt.ink, letterSpacing: -.5),
        contentTextStyle: GoogleFonts.instrumentSans(fontSize: 16, color: Bt.ink2, height: 1.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Bt.noir,
        contentTextStyle: GoogleFonts.instrumentSans(color: Bt.bone, fontSize: 15, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Bt.ink,
          foregroundColor: Bt.bone,
          minimumSize: const Size(64, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rButton)),
          textStyle: GoogleFonts.instrumentSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Bt.ink,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: Bt.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rButton)),
          textStyle: GoogleFonts.instrumentSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: bt.brand, textStyle: GoogleFonts.instrumentSans(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Bt.card,
        selectedColor: bt.brand,
        side: const BorderSide(color: Bt.line),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.instrumentSans(fontSize: 14, fontWeight: FontWeight.w500, color: Bt.ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bt.accent : Bt.inputBorder),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bt.brand : Colors.transparent),
        side: const BorderSide(color: Bt.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bt.brand : Bt.inputBorder)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: bt.accent, linearTrackColor: Bt.fill, refreshBackgroundColor: bt.accent),
      tabBarTheme: TabBarThemeData(labelColor: Bt.ink, unselectedLabelColor: Bt.ink2, indicatorColor: bt.accent, dividerColor: Bt.line),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: bt.accent, foregroundColor: bt.onAccent, elevation: 2),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Bt.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: b(Bt.inputBorder),
        enabledBorder: b(Bt.inputBorder),
        focusedBorder: b(Bt.ink, 2),
        errorBorder: b(Bt.red),
        focusedErrorBorder: b(Bt.red, 2),
        hintStyle: GoogleFonts.instrumentSans(color: Bt.placeholder, fontSize: 16, fontWeight: FontWeight.w400),
        labelStyle: GoogleFonts.instrumentSans(color: Bt.ink2, fontSize: 15),
      ),
    );
  }
}
