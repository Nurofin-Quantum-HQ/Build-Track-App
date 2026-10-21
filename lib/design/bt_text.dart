import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bt_theme.dart';

/// Type scale (Design V2 "Blueprint Noir").
///  • Bricolage Grotesque — display, titles, money
///  • Instrument Sans — UI text
///  • JetBrains Mono — small uppercase annotation labels
class BtText {
  BtText._();
  static const tnum = [FontFeature.tabularFigures()];

  static TextStyle display(TextStyle s) => GoogleFonts.bricolageGrotesque(textStyle: s);
  static TextStyle ui(TextStyle s) => GoogleFonts.instrumentSans(textStyle: s);
  static TextStyle monoFont(TextStyle s) => GoogleFonts.jetBrainsMono(textStyle: s);

  // Kept for API compatibility: headings always use the display face, body the UI face.
  static TextStyle _head(BuildContext c, TextStyle s) => display(s);
  static TextStyle _body(BuildContext c, TextStyle s) => ui(s);

  /// Hero numbers / big display (56 → 30).
  static TextStyle d0(BuildContext c, {Color color = Bt.ink}) => display(TextStyle(fontSize: 52, height: 1.0, fontWeight: FontWeight.w700, letterSpacing: -2.2, color: color, fontFeatures: tnum));
  static TextStyle d1(BuildContext c, {Color color = Bt.ink}) => display(TextStyle(fontSize: 38, height: 1.04, fontWeight: FontWeight.w700, letterSpacing: -1.5, color: color));
  static TextStyle d2(BuildContext c, {Color color = Bt.ink}) => display(TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -.9, color: color));
  static TextStyle d3(BuildContext c, {Color color = Bt.ink}) => display(TextStyle(fontSize: 21, height: 1.18, fontWeight: FontWeight.w600, letterSpacing: -.5, color: color));

  /// Uppercase mono annotation label ("TOTAL COST", "STEP 1 OF 2").
  static TextStyle mono(BuildContext c, {Color color = Bt.ink3, double size = 10.5}) => monoFont(TextStyle(fontSize: size, height: 1.3, fontWeight: FontWeight.w500, letterSpacing: size * .09, color: color));

  static TextStyle largeTitle(BuildContext c) => _head(c, const TextStyle(fontSize: 32, height: 1.06, fontWeight: FontWeight.w700, letterSpacing: -1.1, color: Bt.ink));
  static TextStyle amount(BuildContext c, {double size = 32}) => _head(c, TextStyle(fontSize: size, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.035 * size, color: Bt.ink, fontFeatures: tnum));
  static TextStyle title(BuildContext c, {double size = 20}) => _head(c, TextStyle(fontSize: size, height: 1.22, fontWeight: FontWeight.w700, letterSpacing: -0.025 * size, color: Bt.ink));
  static TextStyle navTitle(BuildContext c) => _body(c, const TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, letterSpacing: -.15, color: Bt.ink));
  static TextStyle headline(BuildContext c) => _body(c, const TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, letterSpacing: -.15, color: Bt.ink));
  static TextStyle body(BuildContext c, {FontWeight weight = FontWeight.w400, Color color = Bt.ink}) => _body(c, TextStyle(fontSize: 16, height: 22 / 16, fontWeight: weight, color: color));
  static TextStyle subhead(BuildContext c, {FontWeight weight = FontWeight.w400, Color color = Bt.ink2}) => _body(c, TextStyle(fontSize: 14, height: 20 / 14, fontWeight: weight, color: color));
  static TextStyle caption(BuildContext c, {Color color = Bt.ink3, FontWeight weight = FontWeight.w400}) => _body(c, TextStyle(fontSize: 13, height: 18 / 13, fontWeight: weight, color: color));
  static TextStyle tabLabel(BuildContext c, Color color) => _body(c, TextStyle(fontSize: 11, height: 13 / 11, fontWeight: FontWeight.w500, color: color));
  static TextStyle button(BuildContext c, {double size = 16, Color? color}) => _body(c, TextStyle(fontSize: size, height: 22 / 17, fontWeight: FontWeight.w600, letterSpacing: -.15, color: color));

  /// Same style with tabular figures (any number that can change).
  static TextStyle num(TextStyle s) => s.copyWith(fontFeatures: tnum);
}
