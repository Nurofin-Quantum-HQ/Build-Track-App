import 'dart:math' as math;

import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

double? _varPct(double planned, double? forecast) =>
    forecast == null || planned <= 0 ? null : (forecast - planned) / planned * 100;

// ═════════════════════════════════════════════════════════════════════════════
// HEAT MATRIX — phase × category: % of plan used, tinted by where it's heading
// ═════════════════════════════════════════════════════════════════════════════

class PhaseMatrixCard extends StatelessWidget {
  const PhaseMatrixCard({super.key, required this.phases, required this.onOpen});
  final List<InsightPhase> phases;
  final void Function(InsightPhase) onOpen;

  @override
  Widget build(BuildContext context) {
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(
            title: 'Phase budgets',
            description: 'Number = % of the phase budget already spent. Colour = where it is heading at completion.',
          ),
          // header
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text('PHASE', style: Ins.overline())),
                for (final c in CostCategory.values) _HeadCell(label: Ins.catShort(c), color: Ins.cat(c)),
                const _HeadCell(label: 'Total'),
              ],
            ),
          ),
          for (final p in phases) _MatrixRow(phase: p, onTap: () => onOpen(p)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Key(color: Ins.varianceFill(-20), label: 'Heading under'),
              _Key(color: Ins.varianceFill(0), label: 'On plan (±5%)'),
              _Key(color: Ins.varianceFill(10), label: '5–15% over'),
              _Key(color: Ins.varianceFill(20), label: '15%+ over'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell({required this.label, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (color != null) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: Ins.t(11.5, w: FontWeight.w600, c: Ins.ink3),
        ),
      ],
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Ins.border),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Ins.t(12, c: Ins.ink2)),
    ],
  );
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({required this.phase, required this.onTap});
  final InsightPhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Ins.phase(phase.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ins.rSm),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Ins.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    phase.name,
                    style: Ins.t(13.5, w: FontWeight.w600, h: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(s.icon, size: 12, color: s.fg),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${s.label} · ${phase.activitiesDone}/${phase.activitiesTotal}',
                          style: Ins.t(11.5, c: s.fg == Ins.ink3 ? Ins.ink3 : s.fg, w: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (final c in CostCategory.values)
              _Cell(planned: phase.planned.of(c), actual: phase.actual.of(c), forecast: phase.forecastByCat[c]),
            _Cell(
              planned: phase.planned.total,
              actual: phase.actual.total,
              forecast: phase.forecast ?? (phase.actual.total == 0 ? phase.planned.total : null),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.planned, required this.actual, required this.forecast, this.bold = false});
  final double planned, actual;
  final double? forecast;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final used = planned > 0 ? actual / planned * 100 : null;
    final vp = _varPct(planned, forecast);
    final over = used != null && used > 100;
    return Container(
      width: 49,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: planned <= 0 && actual <= 0 ? Colors.transparent : Ins.varianceFill(vp),
        borderRadius: BorderRadius.circular(6),
      ),
      child: planned <= 0 && actual <= 0
          ? Center(
              child: Text('—', style: Ins.t(12, c: Ins.ink3)),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  used == null ? inrCompact(actual) : '${used.round()}%',
                  style: Ins.mono(
                    12,
                    w: bold || over ? FontWeight.w700 : FontWeight.w500,
                    c: over ? const Color(0xFF991B1B) : Ins.ink,
                  ),
                ),
                if (vp != null && vp.abs() >= 5 && actual > 0)
                  Text(
                    '${vp > 0 ? '▲' : '▼'}${vp.abs().round()}%',
                    style: Ins.t(
                      10,
                      c: vp > 0 ? const Color(0xFF991B1B) : const Color(0xFF1E40AF),
                      w: FontWeight.w600,
                      h: 1.1,
                    ),
                  ),
              ],
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SPEND vs WORK — dumbbell per phase
// ═════════════════════════════════════════════════════════════════════════════

class SpendVsWorkCard extends StatelessWidget {
  const SpendVsWorkCard({super.key, required this.phases, required this.onOpen});
  final List<InsightPhase> phases;
  final void Function(InsightPhase) onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = phases.where((p) => p.status != 'not_started' && p.spentPct != null).toList();
    return InsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(
            title: 'Spend vs work, by phase',
            description: 'A red link means money is running ahead of the work delivered',
          ),
          const Wrap(
            spacing: 16,
            children: [
              _DotKey(filled: false, color: Ins.good, label: 'Work done'),
              _DotKey(filled: true, color: Ins.primary, label: 'Budget spent'),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty) Text('No phase has spend yet.', style: Ins.t(14, c: Ins.ink3)),
          for (final p in rows)
            InkWell(
              onTap: () => onOpen(p),
              borderRadius: BorderRadius.circular(Ins.rSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Ins.tap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(p.name, style: Ins.t(13.5, w: FontWeight.w500)),
                          ),
                          Text(
                            _gapText(p),
                            style: Ins.t(
                              12.5,
                              w: FontWeight.w600,
                              c: (p.spentPct! - p.earnedPct) > 5 ? Ins.bad : Ins.ink3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 16,
                        child: CustomPaint(
                          painter: _DumbbellPainter(work: p.earnedPct / 100, spent: p.spentPct! / 100),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          // Axis labels positioned exactly where the painter puts each tick.
          LayoutBuilder(
            builder: (_, c) => SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final v in [0.0, 0.5, 1.0])
                    Positioned(
                      left: (v / _DumbbellPainter.max) * (c.maxWidth - 12) + 6 - 20,
                      width: 40,
                      child: Text(
                        '${(v * 100).round()}%',
                        textAlign: TextAlign.center,
                        style: Ins.t(11, c: Ins.ink3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gapText(InsightPhase p) {
    final g = p.spentPct! - p.earnedPct;
    if (g.abs() < 3) return 'In step';
    return g > 0 ? 'Spend ${g.round()} pts ahead' : 'Spend ${(-g).round()} pts behind';
  }
}

class _DotKey extends StatelessWidget {
  const _DotKey({required this.filled, required this.color, required this.label});
  final bool filled;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Ins.t(12.5, c: Ins.ink2)),
    ],
  );
}

class _DumbbellPainter extends CustomPainter {
  _DumbbellPainter({required this.work, required this.spent});
  final double work, spent;
  static const max = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    double x(double v) => (v / max).clamp(0, 1) * (size.width - 12) + 6;
    // grid ticks at 0, 50, 100%
    for (final g in [0.0, 0.5, 1.0]) {
      canvas.drawRect(
        Rect.fromLTWH(x(g) - 0.5, 0, 1, size.height),
        Paint()..color = g == 1.0 ? Ins.borderStrong : Ins.border,
      );
    }
    final ahead = spent - work > 0.05;
    canvas.drawLine(
      Offset(x(work), cy),
      Offset(x(spent), cy),
      Paint()
        ..color = ahead ? Ins.bad : Ins.borderStrong
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x(work), cy), 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(x(work), cy),
      6,
      Paint()
        ..color = Ins.good
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(Offset(x(spent), cy), 6, Paint()..color = Ins.primary);
    canvas.drawCircle(
      Offset(x(spent), cy),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DumbbellPainter o) => o.work != work || o.spent != spent;
}

// ═════════════════════════════════════════════════════════════════════════════
// PHASE DETAIL PAGE
// ═════════════════════════════════════════════════════════════════════════════

class PhaseInsightsPage extends StatelessWidget {
  const PhaseInsightsPage({super.key, required this.phase});
  final InsightPhase phase;

  @override
  Widget build(BuildContext context) {
    final s = Ins.phase(phase.status);
    final fv = phase.forecastVariance;
    return Scaffold(
      backgroundColor: Ins.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Ins.border)),
        foregroundColor: Ins.ink,
        title: Text(phase.name, style: Ins.t(17, w: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 40),
        children: [
          Row(
            children: [
              InsBadge(label: s.label, fg: s.fg, bg: s.bg, icon: s.icon),
              const SizedBox(width: 8),
              Text(
                '${phase.activitiesDone} of ${phase.activitiesTotal} activities done',
                style: Ins.t(13, c: Ins.ink3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Stat('Budget', inrCompact(phase.planned.total))),
                const SizedBox(width: 10),
                Expanded(child: _Stat('Spent', inrCompact(phase.actual.total), sub: pct(phase.spentPct))),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    'Forecast',
                    phase.forecast == null ? '—' : inrCompact(phase.forecast!),
                    sub: fv == null ? null : inrCompact(fv, sign: true),
                    subColor: fv == null ? null : (fv > 0 ? Ins.bad : Ins.good),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InsCardHeader(title: 'Budget vs spent vs forecast', description: 'Per cost category'),
                const Wrap(
                  spacing: 14,
                  children: [
                    InsSwatch(color: Ins.plan, label: 'Budget'),
                    InsSwatch(color: Ins.ink2, label: 'Spent (category colour)'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(height: 220, child: _GroupedBars(phase: phase)),
                const SizedBox(height: 8),
                Text('Outlined bar = forecast at completion', style: Ins.t(12, c: Ins.ink3)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InsCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InsCardHeader(title: 'Activities', description: 'Spent against each activity budget'),
                for (final a in phase.activities) _ActivityRow(activity: a),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.sub, this.subColor});
  final String label, value;
  final String? sub;
  final Color? subColor;
  @override
  Widget build(BuildContext context) => InsCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Ins.t(12.5, c: Ins.ink3)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Ins.num(19, w: FontWeight.w700)),
        ),
        if (sub != null)
          Text(
            sub!,
            style: Ins.t(12.5, c: subColor ?? Ins.ink3, w: FontWeight.w600),
          ),
      ],
    ),
  );
}

class _GroupedBars extends StatelessWidget {
  const _GroupedBars({required this.phase});
  final InsightPhase phase;

  @override
  Widget build(BuildContext context) {
    final cats = CostCategory.values;
    final maxY =
        cats
            .expand((c) => [phase.planned.of(c), phase.actual.of(c), phase.forecastByCat[c] ?? 0])
            .fold<double>(1, math.max) /
        1e5 *
        1.15;
    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: Ins.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Ins.ink,
            tooltipRoundedRadius: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (g, _, rod, i) => BarTooltipItem(
              '${['Budget', 'Spent', 'Forecast'][i]}  ${inrCompact(rod.toY * 1e5)}',
              Ins.t(12.5, c: Colors.white, w: FontWeight.w600),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, m) =>
                  v == m.max ? const SizedBox.shrink() : Text(inrCompact(v * 1e5), style: Ins.t(11, c: Ins.ink3)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, m) => SideTitleWidget(
                axisSide: m.axisSide,
                child: Text(
                  cats[v.toInt()].label,
                  style: Ins.t(12.5, c: Ins.ink2, w: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < cats.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: phase.planned.of(cats[i]) / 1e5,
                  width: 14,
                  color: Ins.plan,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: phase.actual.of(cats[i]) / 1e5,
                  width: 14,
                  color: Ins.cat(cats[i]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: (phase.forecastByCat[cats[i]] ?? 0) / 1e5,
                  width: 14,
                  color: Ins.cat(cats[i]).withValues(alpha: 0.12),
                  borderSide: BorderSide(color: Ins.cat(cats[i]), width: 1.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final InsightActivity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final used = a.planned.total > 0 ? a.actual.total / a.planned.total * 100 : null;
    final over = used != null && used > 100;
    final (icon, color, label) = a.completed
        ? (Icons.check_circle_rounded, Ins.good, 'Done')
        : a.started
        ? (Icons.timelapse_rounded, Ins.primary, 'In progress')
        : (Icons.radio_button_unchecked_rounded, Ins.ink3, 'Not started');
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ins.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(a.name, style: Ins.t(14, w: FontWeight.w500)),
              ),
              if (used != null)
                InsBadge(label: '${used.round()}%', fg: over ? Ins.bad : Ins.ink2, bg: over ? Ins.badSoft : Ins.muted),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${inrCompact(a.actual.total)} of ${inrCompact(a.planned.total)} · $label',
                  style: Ins.t(12.5, c: Ins.ink3),
                ),
                const SizedBox(height: 6),
                _SplitBar(activity: a),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spend split by category, drawn against the activity budget (tick).
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.activity});
  final InsightActivity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final scale = math.max(a.planned.total, a.actual.total);
    if (scale <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: 10,
      child: CustomPaint(
        painter: _SplitPainter(
          parts: [for (final c in CostCategory.values) (a.actual.of(c) / scale, Ins.cat(c))],
          plan: a.planned.total / scale,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SplitPainter extends CustomPainter {
  _SplitPainter({required this.parts, required this.plan});
  final List<(double, Color)> parts;
  final double plan;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 2, size.width * plan, size.height - 4), const Radius.circular(3)),
      Paint()..color = Ins.muted,
    );
    double x = 0;
    for (final (f, c) in parts) {
      if (f <= 0) continue;
      final w = size.width * f;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 2, math.max(w - 2, 1), size.height - 4), const Radius.circular(3)),
        Paint()..color = c,
      );
      x += w;
    }
    final px = size.width * plan;
    canvas.drawRect(Rect.fromLTWH(px - 1, 0, 2, size.height), Paint()..color = Ins.ink);
  }

  @override
  bool shouldRepaint(_SplitPainter o) => true;
}
