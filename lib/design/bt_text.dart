import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bt_theme.dart';

/// Type scale (DESIGN.md §4.3). Heading font follows the active theme.
class BtText {
  BtText._();
  static const tnum = [FontFeature.tabularFigures()];

  static TextStyle _font(String family, TextStyle s) {
    switch (family) {
      case 'Sora':
        return GoogleFonts.sora(textStyle: s);
      default:
        return GoogleFonts.inter(textStyle: s);
    }
  }

  static TextStyle _head(BuildContext c, TextStyle s) => _font(c.bt.headingFont, s);
  static TextStyle _body(BuildContext c, TextStyle s) => _font(c.bt.bodyFont, s);

  static TextStyle largeTitle(BuildContext c) => _head(c, const TextStyle(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.56, color: Bt.ink));
  static TextStyle amount(BuildContext c, {double size = 32}) => _head(c, TextStyle(fontSize: size, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.02 * size, color: Bt.ink, fontFeatures: tnum));
  static TextStyle title(BuildContext c, {double size = 20}) => _head(c, TextStyle(fontSize: size, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.01 * size, color: Bt.ink));
  static TextStyle navTitle(BuildContext c) => _body(c, const TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, color: Bt.ink));
  static TextStyle headline(BuildContext c) => _body(c, const TextStyle(fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600, color: Bt.ink));
  static TextStyle body(BuildContext c, {FontWeight weight = FontWeight.w400, Color color = Bt.ink}) => _body(c, TextStyle(fontSize: 16, height: 22 / 16, fontWeight: weight, color: color));
  static TextStyle subhead(BuildContext c, {FontWeight weight = FontWeight.w400, Color color = Bt.ink2}) => _body(c, TextStyle(fontSize: 14, height: 20 / 14, fontWeight: weight, color: color));
  static TextStyle caption(BuildContext c, {Color color = Bt.ink3, FontWeight weight = FontWeight.w400}) => _body(c, TextStyle(fontSize: 13, height: 18 / 13, fontWeight: weight, color: color));
  static TextStyle tabLabel(BuildContext c, Color color) => _body(c, TextStyle(fontSize: 11, height: 13 / 11, fontWeight: FontWeight.w500, color: color));
  static TextStyle button(BuildContext c, {double size = 17, Color? color}) => _body(c, TextStyle(fontSize: size, height: 22 / 17, fontWeight: FontWeight.w600, color: color));

  /// Same style with tabular figures (any number that can change).
  static TextStyle num(TextStyle s) => s.copyWith(fontFeatures: tnum);
}
