import 'package:flutter/material.dart';

/// Neutral tokens. Identical in every theme (DESIGN.md §4.1, §0.5 rule 7).
class Bt {
  Bt._();
  static const ink = Color(0xFF101828);
  static const ink2 = Color(0xFF475467);
  static const ink3 = Color(0xFF667085);
  static const placeholder = Color(0xFF98A2B3);
  static const ground = Color(0xFFF6F7F9);
  static const card = Color(0xFFFFFFFF);
  static const fill = Color(0xFFEEF1F5);
  static const line = Color(0xFFE4E7EC);
  static const inputBorder = Color(0xFFD0D5DD);
  static const green = Color(0xFF067647);
  static const greenSoft = Color(0xFFE7F6EE);
  static const amber = Color(0xFFB54708);
  static const amberSoft = Color(0xFFFEF3E7);
  static const red = Color(0xFFC01048);
  static const redSoft = Color(0xFFFDECEF);
  static const scrim = Color(0x7A101828);

  // spacing / radius / sizes
  static const gutter = 16.0;
  static const rChip = 16.0;
  static const rInput = 12.0;
  static const rButton = 14.0;
  static const rCard = 16.0;
  static const rSheet = 24.0;
  static const rTile = 12.0;
  static const touch = 44.0;
  static const buttonH = 52.0;
  static const fieldH = 52.0;
}

/// The presets offered in Appearance. `custom` = one of the existing accent
/// colours or the colour picker (existing ThemeProvider behaviour).
enum BtPreset { harbor, nurofin, site, custom }

/// Theme-dependent tokens: the tint, the signature element and the heading font.
@immutable
class BtTheme extends ThemeExtension<BtTheme> {
  const BtTheme({
    required this.preset,
    required this.brand,
    required this.brandSoft,
    required this.onAccent,
    required this.signature,
    required this.progressWork,
    required this.series,
    required this.headingFont,
    required this.bodyFont,
  });

  final BtPreset preset;
  final Color brand;
  final Color brandSoft;
  final Color onAccent;

  /// Centre + button, Speak button, voice orb, AI tile, Upgrade CTA.
  final Gradient signature;

  /// Work-progress bars.
  final Gradient progressWork;

  /// Chart series: material, labour, equipment.
  final List<Color> series;
  final String headingFont;
  final String bodyFont;

  static Gradient _solid(Color c) => LinearGradient(colors: [c, c]);

  static const harborBrand = Color(0xFF0B63CE);
  static const nurofinBrand = Color(0xFF173EEA);
  static const siteInk = Color(0xFF0F1B2D);
  static const siteOrange = Color(0xFFF47A1F);

  static BtTheme forPreset(BtPreset preset, {Color? custom}) {
    switch (preset) {
      case BtPreset.harbor:
        return BtTheme(
          preset: preset,
          brand: harborBrand,
          brandSoft: const Color(0xFFE8F1FC),
          onAccent: Colors.white,
          signature: _solid(harborBrand),
          progressWork: _solid(harborBrand),
          series: const [harborBrand, Color(0xFFF59E0B), Color(0xFF98A2B3)],
          headingFont: 'Inter',
          bodyFont: 'Inter',
        );
      case BtPreset.nurofin:
        return const BtTheme(
          preset: BtPreset.nurofin,
          brand: nurofinBrand,
          brandSoft: Color(0xFFEDF1FE),
          onAccent: Colors.white,
          signature: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9D2CF5), nurofinBrand],
          ),
          progressWork: LinearGradient(
            colors: [Color(0xFFB137FF), nurofinBrand, Color(0xFF67C8FF)],
            stops: [0, .55, 1],
          ),
          series: [nurofinBrand, Color(0xFFB137FF), Color(0xFF67C8FF)],
          headingFont: 'Sora',
          bodyFont: 'Inter',
        );
      case BtPreset.site:
        return BtTheme(
          preset: preset,
          brand: siteInk,
          brandSoft: const Color(0xFFFEF0E4),
          onAccent: siteInk,
          signature: _solid(siteOrange),
          progressWork: _solid(siteOrange),
          series: const [siteInk, siteOrange, Color(0xFF98A2B3)],
          headingFont: 'Inter',
          bodyFont: 'Inter',
        );
      case BtPreset.custom:
        final c = ensureContrastOnWhite(custom ?? harborBrand);
        return BtTheme(
          preset: preset,
          brand: c,
          brandSoft: Color.alphaBlend(c.withValues(alpha: .10), Colors.white),
          onAccent: Colors.white,
          signature: _solid(c),
          progressWork: _solid(c),
          series: [c, const Color(0xFFF59E0B), const Color(0xFF98A2B3)],
          headingFont: 'Inter',
          bodyFont: 'Inter',
        );
    }
  }

  /// Darkens a colour until white text on it reaches [ratio] (WCAG).
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
      Theme.of(context).extension<BtTheme>() ?? forPreset(BtPreset.harbor);

  @override
  BtTheme copyWith({Color? brand}) => brand == null ? this : forPreset(BtPreset.custom, custom: brand);

  @override
  BtTheme lerp(BtTheme? other, double t) => t < .5 ? this : (other ?? this);
}

extension BtContext on BuildContext {
  BtTheme get bt => BtTheme.of(this);
}
