import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'package:buildtrack_mobile/screen/project_insights/insights_format.dart';

/// Project insights — light, shadcn "Clean Slate"-style tokens.
///
/// Category hues are the dataviz reference palette's light steps, validated on
/// white (all pass: CVD ΔE ≥ 8.4, normal-vision ΔE ≥ 27, contrast ≥ 3:1).
/// Status colours are reserved for state and always ship with icon + label.
class Ins {
  Ins._();

  // Surfaces
  static const bg = Color(0xFFF8FAFC); // slate-50
  static const card = Colors.white;
  static const muted = Color(0xFFF1F5F9); // slate-100
  static const border = Color(0xFFE2E8F0); // slate-200
  static const borderStrong = Color(0xFFCBD5E1); // slate-300

  // Ink
  static const ink = Color(0xFF0F172A); // slate-900
  static const ink2 = Color(0xFF334155); // slate-700
  static const ink3 = Color(0xFF64748B); // slate-500 (4.8:1 on white)

  // Accent
  static const primary = Color(0xFF4F46E5); // indigo-600
  static const primarySoft = Color(0xFFEEF2FF);

  // Data
  static const material = Color(0xFF2A78D6);
  static const labour = Color(0xFFEB6834);
  static const equipment = Color(0xFF199E70);
  static const plan = Color(0xFFCBD5E1);

  // Status (text-safe steps + soft fills)
  static const good = Color(0xFF15803D);
  static const goodSoft = Color(0xFFDCFCE7);
  static const warn = Color(0xFFB45309);
  static const warnSoft = Color(0xFFFEF3C7);
  static const bad = Color(0xFFDC2626);
  static const badSoft = Color(0xFFFEE2E2);
  static const info = Color(0xFF4F46E5);
  static const infoSoft = Color(0xFFEEF2FF);

  // Diverging (under ↔ over) — blue ↔ red around a neutral grey
  static const under = Color(0xFF2A78D6);

  static Color cat(CostCategory c) => switch (c) {
    CostCategory.material => material,
    CostCategory.labour => labour,
    CostCategory.equipment => equipment,
  };

  static IconData catIcon(CostCategory c) => switch (c) {
    CostCategory.material => Icons.inventory_2_outlined,
    CostCategory.labour => Icons.engineering_outlined,
    CostCategory.equipment => Icons.construction_outlined,
  };

  static String catShort(CostCategory c) => switch (c) {
    CostCategory.material => 'Mat.',
    CostCategory.labour => 'Lab.',
    CostCategory.equipment => 'Equip.',
  };

  static ({Color fg, Color bg, String label, IconData icon}) health(String s) => switch (s) {
    'critical' => (fg: bad, bg: badSoft, label: 'Critical', icon: Icons.error_outline_rounded),
    'at_risk' => (fg: warn, bg: warnSoft, label: 'At risk', icon: Icons.warning_amber_rounded),
    _ => (fg: good, bg: goodSoft, label: 'On track', icon: Icons.check_circle_outline_rounded),
  };

  static ({Color fg, Color bg, String label, IconData icon}) phase(String s) => switch (s) {
    'over' => (fg: bad, bg: badSoft, label: 'Over budget', icon: Icons.north_east_rounded),
    'watch' => (fg: warn, bg: warnSoft, label: 'Watch', icon: Icons.visibility_outlined),
    'not_started' => (fg: ink3, bg: muted, label: 'Not started', icon: Icons.schedule_rounded),
    _ => (fg: good, bg: goodSoft, label: 'On plan', icon: Icons.check_rounded),
  };

  static ({Color fg, Color bg, IconData icon}) severity(String s) => switch (s) {
    'critical' => (fg: bad, bg: badSoft, icon: Icons.error_outline_rounded),
    'warning' => (fg: warn, bg: warnSoft, icon: Icons.warning_amber_rounded),
    _ => (fg: info, bg: infoSoft, icon: Icons.info_outline_rounded),
  };

  /// Diverging tint for "forecast vs plan" (%, positive = over).
  static Color varianceFill(double? pct) {
    if (pct == null) return muted;
    if (pct > 15) return const Color(0xFFFCA5A5); // red-300
    if (pct > 5) return const Color(0xFFFECACA); // red-200
    if (pct < -15) return const Color(0xFFBFDBFE); // blue-200
    if (pct < -5) return const Color(0xFFDBEAFE); // blue-100
    return const Color(0xFFF1F5F9); // neutral
  }

  // Spacing / shape
  static const r = 12.0;
  static const rSm = 8.0;
  static const gutter = 16.0;
  static const tap = 48.0;
  static const motion = Duration(milliseconds: 240);

  // Typography — Fira Sans (UI) with tabular figures for numbers.
  static TextStyle t(double size, {FontWeight w = FontWeight.w400, Color c = ink, double h = 1.35, double ls = 0}) =>
      GoogleFonts.firaSans(
        fontSize: size,
        fontWeight: w,
        color: c,
        height: h,
        letterSpacing: ls,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle num(double size, {FontWeight w = FontWeight.w600, Color c = ink}) => GoogleFonts.firaSans(
    fontSize: size,
    fontWeight: w,
    color: c,
    height: 1.1,
    letterSpacing: -0.4,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle mono(double size, {FontWeight w = FontWeight.w500, Color c = ink}) =>
      GoogleFonts.firaCode(fontSize: size, fontWeight: w, color: c, height: 1.2);

  static TextStyle overline({Color c = ink3}) =>
      GoogleFonts.firaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: c, letterSpacing: 0.6);
}

// ── Primitives (shadcn-style) ───────────────────────────────────────────────

/// Card: white, 1px slate-200 border, 12 radius, soft shadow.
class InsCard extends StatelessWidget {
  const InsCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: Ins.card,
        borderRadius: BorderRadius.circular(Ins.r),
        border: Border.all(color: Ins.border),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Ins.r),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: body),
            ),
    );
  }
}

/// Card header: title + optional description + optional trailing action.
class InsCardHeader extends StatelessWidget {
  const InsCardHeader({super.key, required this.title, this.description, this.action});
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ins.t(16, w: FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(description!, style: Ins.t(13, c: Ins.ink3)),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class InsBadge extends StatelessWidget {
  const InsBadge({super.key, required this.label, required this.fg, required this.bg, this.icon});
  final String label;
  final Color fg, bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: Ins.t(12, w: FontWeight.w600, c: fg, h: 1.2),
          ),
        ],
      ),
    );
  }
}

class InsSwatch extends StatelessWidget {
  const InsSwatch({super.key, required this.color, required this.label, this.line = false, this.dashed = false});
  final Color color;
  final String label;
  final bool line, dashed;

  @override
  Widget build(BuildContext context) {
    Widget mark;
    if (line) {
      mark = SizedBox(
        width: 16,
        height: 2,
        child: dashed
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (_) => Container(width: 4, height: 2, color: color)),
              )
            : Container(color: color),
      );
    } else {
      mark = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(label, style: Ins.t(12.5, c: Ins.ink2)),
      ],
    );
  }
}
