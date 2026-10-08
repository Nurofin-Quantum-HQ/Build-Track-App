import 'dart:math' as math;

import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

double _niceStep(double raw) {
  if (raw <= 0) return 1;
  final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / exp;
  final nice = f <= 1
      ? 1
      : f <= 2
      ? 2
      : f <= 2.5
      ? 2.5
      : f <= 5
      ? 5
      : 10;
  return nice * exp;
}

String _monYY(DateTime d) => "${DateFormat('MMM').format(d)} '${(d.year % 100).toString().padLeft(2, '0')}";

// ═════════════════════════════════════════════════════════════════════════════
// SPEND CURVE
// ═════════════════════════════════════════════════════════════════════════════

class InsSpendCurveCard extends StatelessWidget {
  const InsSpendCurveCard({super.key, required this.data, this.height = 240});
  final ProjectInsights data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pts = data.cumulative;
    if (pts.length < 2) {
      return InsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InsCardHeader(title: 'Spend curve'),
            Text(
              'Add a start and end date to the project to see planned vs actual spend.',
              style: Ins.t(14, c: Ins.ink3),
            ),
          ],
        ),
      );
    }
    final t0 = pts.first.date.millisecondsSinceEpoch.toDouble();
    double dx(DateTime d) => (d.millisecondsSinceEpoch - t0) / 86400000;
    final planned = [
      for (final p in pts)
        if (p.planned != null) FlSpot(dx(p.date), p.planned! / 1e5),
    ];
    final actual = [
      for (final p in pts)
        if (p.actual != null) FlSpot(dx(p.date), p.actual! / 1e5),
    ];
    final last = actual.isNotEmpty ? actual.last : null;
    final fcEnd = data.bridge?.forecast ?? data.eac;
    final fc = <FlSpot>[
      if (last != null && fcEnd != null && data.endDate != null && data.endDate!.isAfter(DateTime.now())) ...[
        last,
        FlSpot(dx(data.endDate!), fcEnd / 1e5),
      ],
    ];
    final maxX = [...planned, ...actual, ...fc].map((s) => s.x).fold<double>(1, math.max);
    final maxY =
        [...planned, ...actual, ...fc, FlSpot(0, data.budgetTotal / 1e5)].map((s) => s.y).fold<double>(1, math.max) *
        1.1;
    final step = _niceStep(maxY / 4);
    final behind = last != null && planned.isNotEmpty
        ? () {
            final pv = planned.lastWhere((s) => s.x <= last.x, orElse: () => planned.first).y;
            return (last.y - pv) * 1e5;
          }()
        : null;

    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsCardHeader(
            title: 'Spend curve',
            description: behind == null
                ? 'Cumulative spend vs the planned S-curve'
                : 'Spend is ${inrCompact(behind.abs())} ${behind >= 0 ? 'ahead of' : 'behind'} the plan to date',
          ),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              InsSwatch(color: Ins.primary, label: 'Actual', line: true),
              InsSwatch(color: Ins.ink3, label: 'Planned', line: true, dashed: true),
              InsSwatch(color: Ins.bad, label: 'Forecast', line: true, dashed: true),
              InsSwatch(color: Color(0xFFD97706), label: 'Budget', line: true, dashed: true),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Ins.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: step,
                      getTitlesWidget: (v, m) => v == m.max
                          ? const SizedBox.shrink()
                          : Text(inrCompact(v * 1e5), style: Ins.t(11, c: Ins.ink3)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: maxX / 3,
                      getTitlesWidget: (v, m) {
                        if (v == m.max && v != 0) return const SizedBox.shrink();
                        final d = DateTime.fromMillisecondsSinceEpoch((t0 + v * 86400000).round());
                        return SideTitleWidget(
                          axisSide: m.axisSide,
                          child: Text(_monYY(d), style: Ins.t(11, c: Ins.ink3)),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: data.budgetTotal / 1e5,
                      color: const Color(0xFFD97706),
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        style: Ins.t(11, c: const Color(0xFFB45309), w: FontWeight.w600),
                        labelResolver: (_) => 'Budget',
                      ),
                    ),
                  ],
                  verticalLines: [
                    if (last != null)
                      VerticalLine(
                        x: last.x,
                        color: Ins.borderStrong,
                        strokeWidth: 1,
                        dashArray: [3, 3],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          style: Ins.t(11, c: Ins.ink3, w: FontWeight.w600),
                          labelResolver: (_) => 'Today',
                        ),
                      ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Ins.ink,
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => spots.map((s) {
                      final name = switch (s.barIndex) {
                        0 => 'Planned',
                        1 => 'Actual',
                        _ => 'Forecast',
                      };
                      final d = DateTime.fromMillisecondsSinceEpoch((t0 + s.x * 86400000).round());
                      return LineTooltipItem(
                        '${s == spots.first ? '${dateShort.format(d)}\n' : ''}$name ${inrCompact(s.y * 1e5)}',
                        Ins.t(12, c: Colors.white, w: FontWeight.w500),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: planned,
                    isCurved: true,
                    color: Ins.ink3,
                    barWidth: 2,
                    dashArray: [5, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: actual,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: Ins.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (s, b) => s == b.spots.last,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 4.5,
                        color: Ins.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Ins.primary.withValues(alpha: 0.16), Ins.primary.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                  if (fc.length == 2)
                    LineChartBarData(
                      spots: fc,
                      color: Ins.bad,
                      barWidth: 2,
                      dashArray: [5, 4],
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (s, b) => s == b.spots.last,
                        getDotPainter: (_, _, _, _) =>
                            FlDotCirclePainter(radius: 4, color: Ins.bad, strokeWidth: 2, strokeColor: Colors.white),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// MONTHLY BURN
// ═════════════════════════════════════════════════════════════════════════════

class InsMonthlyCard extends StatelessWidget {
  const InsMonthlyCard({super.key, required this.data, this.height = 200});
  final ProjectInsights data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final months = data.monthly;
    if (months.isEmpty) {
      return InsCard(
        child: Text('No approved spend yet.', style: Ins.t(14, c: Ins.ink3)),
      );
    }
    final maxY = months.map((m) => m.spend.total / 1e5).fold<double>(1, math.max) * 1.15;
    final step = _niceStep(maxY / 4);
    final avg = months.length >= 3
        ? months.sublist(months.length - 3).fold<double>(0, (s, m) => s + m.spend.total) / 3
        : null;
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsCardHeader(
            title: 'Monthly spend',
            description: avg == null ? 'Approved spend by month' : 'Last 3 months average ${inrCompact(avg)} / month',
          ),
          Wrap(
            spacing: 14,
            children: [for (final c in CostCategory.values) InsSwatch(color: Ins.cat(c), label: c.label)],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Ins.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: step,
                      getTitlesWidget: (v, m) => v == m.max
                          ? const SizedBox.shrink()
                          : Text(inrCompact(v * 1e5), style: Ins.t(11, c: Ins.ink3)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: m.axisSide,
                          child: Text(DateFormat('MMM').format(months[i].month), style: Ins.t(11, c: Ins.ink3)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Ins.ink,
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (g, _, _, _) {
                      final m = months[g.x];
                      return BarTooltipItem(
                        '${_monYY(m.month)} · ${inrCompact(m.spend.total)}\n',
                        Ins.t(12.5, c: Colors.white, w: FontWeight.w600),
                        children: [
                          for (final c in CostCategory.values)
                            TextSpan(
                              text: '${c.label} ${inrCompact(m.spend.of(c))}${c == CostCategory.equipment ? '' : '\n'}',
                              style: Ins.t(11.5, c: const Color(0xFFCBD5E1)),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < months.length; i++)
                    BarChartGroupData(x: i, barRods: [_rod(months[i].spend, maxY)]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartRodData _rod(Buckets b, double maxY) {
    final gap = maxY * 0.006; // ≈2px surface gap between stacked segments
    final items = <BarChartRodStackItem>[];
    double y = 0;
    for (final c in CostCategory.values) {
      final v = b.of(c) / 1e5;
      if (v <= 0) continue;
      items.add(BarChartRodStackItem(y, y + v, Ins.cat(c)));
      y += v + gap;
    }
    return BarChartRodData(
      toY: y,
      width: 16,
      rodStackItems: items,
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PLAN vs ACTUAL MIX — 100% stacked bars + table
// ═════════════════════════════════════════════════════════════════════════════

class InsMixCard extends StatelessWidget {
  const InsMixCard({super.key, required this.data});
  final ProjectInsights data;

  @override
  Widget build(BuildContext context) {
    final plannedTotal = data.byCategory.values.fold<double>(0, (s, e) => s + e.planned);
    final actualTotal = data.byCategory.values.fold<double>(0, (s, e) => s + e.actual);
    return InsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(title: 'Cost mix', description: 'Is money going where the plan said it would?'),
          _MixBar(
            label: 'Plan',
            total: plannedTotal,
            values: {for (final c in CostCategory.values) c: data.byCategory[c]!.planned},
          ),
          const SizedBox(height: 10),
          _MixBar(
            label: 'Actual',
            total: actualTotal,
            values: {for (final c in CostCategory.values) c: data.byCategory[c]!.actual},
          ),
          const SizedBox(height: 14),
          // table
          Row(
            children: [
              Expanded(flex: 4, child: Text('CATEGORY', style: Ins.overline())),
              Expanded(
                flex: 3,
                child: Text('SPENT', textAlign: TextAlign.right, style: Ins.overline()),
              ),
              Expanded(
                flex: 3,
                child: Text('BUDGET', textAlign: TextAlign.right, style: Ins.overline()),
              ),
              Expanded(
                flex: 2,
                child: Text('USED', textAlign: TextAlign.right, style: Ins.overline()),
              ),
            ],
          ),
          for (final c in CostCategory.values)
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Ins.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: Ins.cat(c), borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 8),
                        Text(c.label, style: Ins.t(14, w: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      inrCompact(data.byCategory[c]!.actual),
                      textAlign: TextAlign.right,
                      style: Ins.num(14, w: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      inrCompact(data.byCategory[c]!.planned),
                      textAlign: TextAlign.right,
                      style: Ins.t(14, c: Ins.ink3),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      data.byCategory[c]!.planned > 0
                          ? pct(data.byCategory[c]!.actual / data.byCategory[c]!.planned * 100)
                          : '—',
                      textAlign: TextAlign.right,
                      style: Ins.num(14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MixBar extends StatelessWidget {
  const _MixBar({required this.label, required this.total, required this.values});
  final String label;
  final double total;
  final Map<CostCategory, double> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: Ins.t(13, c: Ins.ink2, w: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 28,
              child: total <= 0
                  ? Container(color: Ins.muted)
                  : Row(
                      children: [
                        for (final c in CostCategory.values)
                          if (values[c]! > 0)
                            Expanded(
                              flex: (values[c]! / total * 1000).round().clamp(1, 1000),
                              child: Container(
                                margin: const EdgeInsets.only(right: 2),
                                color: Ins.cat(c),
                                alignment: Alignment.center,
                                child: values[c]! / total >= 0.12
                                    ? Text(
                                        '${(values[c]! / total * 100).round()}%',
                                        style: Ins.t(12, c: Colors.white, w: FontWeight.w700),
                                      )
                                    : null,
                              ),
                            ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CASH + SUPPLIERS
// ═════════════════════════════════════════════════════════════════════════════

class InsCashCard extends StatelessWidget {
  const InsCashCard({super.key, required this.data});
  final ProjectInsights data;

  @override
  Widget build(BuildContext context) {
    final net = data.income - data.paid;
    final owed = data.paid + data.outstanding;
    Widget row(String label, String value, {String? sub, Color? c, IconData? icon}) => Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ins.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: c ?? Ins.ink3), const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Ins.t(14, c: Ins.ink2)),
                if (sub != null) Text(sub, style: Ins.t(12, c: Ins.ink3)),
              ],
            ),
          ),
          Text(value, style: Ins.num(16, c: c ?? Ins.ink)),
        ],
      ),
    );
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(title: 'Cash position', description: 'Approved entries only'),
          if (owed > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: (data.paid / owed * 1000).round().clamp(1, 1000),
                      child: Container(color: Ins.good),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: (data.outstanding / owed * 1000).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('${(data.paid / owed * 100).round()}% of approved bills paid', style: Ins.t(12.5, c: Ins.ink3)),
            const SizedBox(height: 10),
          ],
          row('Paid out', inrCompact(data.paid), icon: Icons.check_circle_outline_rounded, c: Ins.good),
          row('Still owed to vendors', inrCompact(data.outstanding), icon: Icons.schedule_rounded, c: Ins.warn),
          row(
            'Awaiting approval',
            inrCompact(data.pendingApproval),
            sub: '${data.pendingCount} entries',
            icon: Icons.hourglass_empty_rounded,
          ),
          row('Received from client', inrCompact(data.income), icon: Icons.south_west_rounded),
          row(
            net >= 0 ? 'Cash in hand' : 'Funding gap',
            inrCompact(net.abs()),
            sub: 'Received minus paid out',
            icon: net >= 0 ? Icons.account_balance_wallet_outlined : Icons.report_gmailerrorred_rounded,
            c: net >= 0 ? Ins.good : Ins.bad,
          ),
        ],
      ),
    );
  }
}

class InsSuppliersCard extends StatelessWidget {
  const InsSuppliersCard({super.key, required this.suppliers});
  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    final top = suppliers.isEmpty ? 1.0 : suppliers.first.amount;
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(title: 'Top suppliers', description: 'By approved spend'),
          if (suppliers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Add supplier names to entries to see this.', style: Ins.t(14, c: Ins.ink3)),
            ),
          for (var i = 0; i < suppliers.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Ins.border)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}', style: Ins.mono(13, c: Ins.ink3)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                suppliers[i].name,
                                style: Ins.t(14, w: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(inrCompact(suppliers[i].amount), style: Ins.num(14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: suppliers[i].amount / top,
                            minHeight: 6,
                            backgroundColor: Ins.muted,
                            color: Ins.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('${suppliers[i].count} entries', style: Ins.t(11.5, c: Ins.ink3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
