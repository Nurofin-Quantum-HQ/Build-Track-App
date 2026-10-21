import 'package:flutter/material.dart';

/// Neutral tokens — "Blueprint Noir" (Design V2). Identical in every theme;
/// only the accent changes with the user's App Theme colour.
class Bt {
  Bt._();

  // Text & ink
  static const ink = Color(0xFF111317); // primary text, primary buttons
  static const ink2 = Color(0xFF525864); // secondary text
  static const ink3 = Color(0xFF6F7582); // tertiary text (4.6:1 on white)
  static const placeholder = Color(0xFF9AA0AB);

  // Surfaces
  static const ground = Color(0xFFF2F0EB); // bone
  static const card = Color(0xFFFFFFFF);
  static const fill = Color(0xFFEFEDE8); // ink at ~6% over white
  static const line = Color(0xFFE6E3DC);
  static const inputBorder = Color(0xFFD8D4CB);

  // Noir (hero / dock / ink cards)
  static const noir = Color(0xFF0C0E12);
  static const noir2 = Color(0xFF14171D);
  static const noir3 = Color(0xFF1F242D);
  static const bone = Color(0xFFF2F0EB);
  static const onNoir2 = Color(0xA3F2F0EB); // 64% bone — secondary text on noir
  static const onNoir3 = Color(0x80F2F0EB); // 50% bone
  static const noirLine = Color(0x1AFFFFFF);

  // Status (text-safe) + soft fills + bright (for fills/bars)
  static const green = Color(0xFF067A52);
  static const greenSoft = Color(0xFFDDF3EA);
  static const greenBright = Color(0xFF12A574);
  static const amber = Color(0xFF935600);
  static const amberSoft = Color(0xFFFCEFD9);
  static const amberBright = Color(0xFFF2A33A);
  static const red = Color(0xFFBE2A30);
  static const redSoft = Color(0xFFFCE7E7);
  static const redBright = Color(0xFFE5484D);

  // Data series companions
  static const steel = Color(0xFF6E8BFF);
  static const slate = Color(0xFF9AA3B2);

  static const scrim = Color(0x940A0B0E);

  // Elevation — layered, soft (cards float on bone instead of hairlines)
  static const shadow = [
    BoxShadow(color: Color(0x0A0C0E12), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1F0C0E12), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 12)),
  ];
  static const shadowLg = [
    BoxShadow(color: Color(0x0D0C0E12), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x380C0E12), blurRadius: 56, spreadRadius: -24, offset: Offset(0, 28)),
  ];

  // spacing / radius / sizes
  static const gutter = 16.0;
  static const rChip = 12.0;
  static const rInput = 16.0;
  static const rButton = 18.0;
  static const rCard = 22.0;
  static const rSheet = 28.0;
  static const rTile = 14.0;
  static const touch = 44.0;
  static const buttonH = 54.0;
  static const fieldH = 54.0;

  // motion
  static const ease = Cubic(.16, 1, .3, 1); // expo-out
  static const spring = Cubic(.34, 1.56, .64, 1); // gentle overshoot
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 450);
  static const slow = Duration(milliseconds: 800);

  /// True when the OS asks for reduced motion — every looping/entrance
  /// animation checks this and renders its final state instead.
  static bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// The colours offered in Appearance. `custom` = the colour picker
/// (existing ThemeProvider behaviour; the colour is what `themePreference` stores).
enum BtPreset { brass, ember, cobalt, jade, custom }

/// Theme-dependent tokens. In V2 `brand` is the primary ink (buttons, links,
/// selection) and `accent` is the user's theme colour (+ button, progress,
/// highlights). `accentInk` is the accent darkened until it is readable as text.
@immutable
class BtTheme extends ThemeExtension<BtTheme> {
  const BtTheme({
    required this.preset,
    required this.brand,
    required this.brandSoft,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.onAccent,
    required this.signature,
    required this.progressWork,
    required this.series,
    required this.headingFont,
    required this.bodyFont,
  });

  final BtPreset preset;

  /// Primary ink (primary buttons, links, selected chips, focus).
  final Color brand;
  final Color brandSoft;

  /// The theme colour.
  final Color accent;

  /// Accent that passes 4.5:1 on white — use for accent-coloured text/icons on light.
  final Color accentInk;
  final Color accentSoft;

  /// Text/icon colour on top of [accent].
  final Color onAccent;

  /// Centre + button, Speak button, voice orb, AI tile, Upgrade CTA.
  final Gradient signature;

  /// Work-progress bars.
  final Gradient progressWork;

  /// Chart series: material, labour, equipment.
  final List<Color> series;
  final String headingFont;
  final String bodyFont;

  static const brass = Color(0xFFE0A93B);
  static const ember = Color(0xFFFF7A2F);
  static const cobalt = Color(0xFF4F6BFF);
  static const jade = Color(0xFF16B981);

  static const presetColors = {
    BtPreset.brass: brass,
    BtPreset.ember: ember,
    BtPreset.cobalt: cobalt,
    BtPreset.jade: jade,
  };

  static BtTheme forPreset(BtPreset preset, {Color? custom}) {
    final a = preset == BtPreset.custom ? (custom ?? brass) : presetColors[preset]!;
    return fromAccent(a, preset: preset);
  }

  static BtTheme fromAccent(Color a, {BtPreset preset = BtPreset.custom}) {
    final grad = LinearGradient(colors: [a, a]);
    return BtTheme(
      preset: preset,
      brand: Bt.ink,
      brandSoft: const Color(0xFFE9E6DF),
      accent: a,
      accentInk: ensureContrastOnWhite(a),
      accentSoft: Color.alphaBlend(a.withValues(alpha: .16), Colors.white),
      onAccent: a.computeLuminance() > .33 ? Bt.noir : Colors.white,
      signature: grad,
      progressWork: grad,
      series: [a, Bt.steel, Bt.slate],
      headingFont: 'Bricolage Grotesque',
      bodyFont: 'Instrument Sans',
    );
  }

  /// Darkens a colour until white text on it (or it as text on white) reaches [ratio] (WCAG).
  static Color ensureContrastOnWhite(Color c, [double ratio = 4.5]) {
    var hsl = HSLColor.fromColor(c);
    var out = c;
    var guard = 0;
    while (_contrast(Colors.white, out) < ratio && guard < 60) {
      hsl = hsl.withLightness((hsl.lightness - .02).clamp(0.0, 1.0));
      out = hsl.toColor();
      guard++;
    }
    return out;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + .05) / (lo + .05);
  }

  static BtTheme of(BuildContext context) =>
      Theme.of(context).extension<BtTheme>() ?? forPreset(BtPreset.brass);

  @override
  BtTheme copyWith({Color? accent}) => accent == null ? this : fromAccent(accent);

  @override
  BtTheme lerp(BtTheme? other, double t) => t < .5 ? this : (other ?? this);
}

extension BtContext on BuildContext {
  BtTheme get bt => BtTheme.of(this);
}
