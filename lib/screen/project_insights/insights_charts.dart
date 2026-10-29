import 'dart:math' as math;

import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Graphs for Insights — read-only views of numbers the models already compute.
// Nothing here adds, rounds or re-derives an amount.
// ═════════════════════════════════════════════════════════════════════════════

/// One place for chart motion: bars grow in over ~700ms with the app's expo-out
/// curve, and not at all unless the Motion setting is Full.
Duration insChartDuration(BuildContext context) =>
    Bt.reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700);

const Curve insChartCurve = Bt.ease;

/// A "nice" axis step (1, 2, 2.5, 5 × 10ⁿ) at or above [raw].
double insNiceStep(double raw) {
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

TextStyle _axis() => Ins.t(12, c: Ins.ink3);

// ═════════════════════════════════════════════════════════════════════════════
// HORIZONTAL BARS — names left, values right
// ═════════════════════════════════════════════════════════════════════════════

class InsBarItem {
  const InsBarItem({required this.label, required this.value, this.share, this.onTap, this.muted = false});
  final String label;
  final double value;

  /// 0..1 of the whole the bars belong to (shown next to the value).
  final double? share;
  final VoidCallback? onTap;

  /// The "Others" bar: grey instead of the category colour.
  final bool muted;
}

/// Horizontal bar chart: one row per item (name left, value right, bar
/// underneath), all on one scale. Bars grow in once.
class InsHBarChart extends StatelessWidget {
  const InsHBarChart({super.key, required this.items, required this.color});
  final List<InsBarItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = items.fold<double>(0, (m, i) => math.max(m, i.value));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: insChartDuration(context),
      curve: insChartCurve,
      builder: (context, t, _) => Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _BarRow(
              item: items[i],
              fraction: max > 0 ? items[i].value / max * t : 0,
              color: color,
              last: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.item, required this.fraction, required this.color, required this.last});
  final InsBarItem item;
  final double fraction;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final fill = item.muted ? Ins.borderStrong : color;
    final share = item.share;
    final row = Padding(
      padding: EdgeInsets.fromLTRB(0, 6, 0, last ? 0 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: Ins.t(12, c: Ins.ink2, w: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(inrCompact(item.value), style: Ins.num(12.5)),
              if (share != null)
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(share * 100).toStringAsFixed(share < .01 && share > 0 ? 1 : 0)}%',
                    textAlign: TextAlign.right,
                    style: Ins.t(12, c: Ins.ink3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth * fraction.clamp(0.0, 1.0);
              return Container(
                height: 10,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Ins.border.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Container(
                  width: item.value > 0 ? math.max(w, fraction > 0 ? 3.0 : 0.0) : 0,
                  decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(5)),
                ),
              );
            },
          ),
        ],
      ),
    );
    if (item.onTap == null) {
      return Semantics(
        label: '${item.label}, ${inrFull(item.value)}',
        child: ExcludeSemantics(child: row),
      );
    }
    return Semantics(
      button: true,
      label: '${item.label}, ${inrFull(item.value)}',
      child: InkWell(
        onTap: item.onTap,
        child: ExcludeSemantics(child: row),
      ),
    );
  }
}

/// What to show instead of a one-bar chart: the single item as a summary.
class InsSingleSummary extends StatelessWidget {
  const InsSingleSummary({super.key, required this.group, required this.color, this.onTap});
  final SpendGroup group;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final body = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(Ins.rSm)),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.name,
                  style: Ins.t(14, w: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${g.count} ${g.count == 1 ? 'entry' : 'entries'}',
                  style: Ins.t(12, c: Ins.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(inrFull(g.amount), style: Ins.num(16)),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '${g.name}, ${inrFull(g.amount)}',
      child: ExcludeSemantics(
        child: onTap == null ? body : InkWell(borderRadius: BorderRadius.circular(Ins.rSm), onTap: onTap, child: body),
      ),
    );
  }
}

/// Top items of a list of groups (the SAME groups the list below shows):
/// at most [maxBars] rows in all, everything after that rolled into "Others".
/// One group → a summary instead of a one-bar chart. Nothing for none.
class InsTopGroupsChart extends StatelessWidget {
  const InsTopGroupsChart({
    super.key,
    required this.title,
    required this.description,
    required this.groups,
    required this.color,
    this.onTap,
    this.maxBars = 8,
  });
  final String title, description;
  final List<SpendGroup> groups;
  final Color color;
  final ValueChanged<SpendGroup>? onTap;
  final int maxBars;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final total = groups.fold<double>(0, (s, g) => s + g.amount);
    final Widget chart;
    if (groups.length == 1) {
      final g = groups.first;
      chart = InsSingleSummary(group: g, color: color, onTap: onTap == null ? null : () => onTap!(g));
    } else {
      final head = groups.length <= maxBars ? groups : groups.take(maxBars - 1).toList();
      final rest = groups.length <= maxBars ? const <SpendGroup>[] : groups.skip(maxBars - 1).toList();
      final others = rest.fold<double>(0, (s, g) => s + g.amount);
      chart = InsHBarChart(
        color: color,
        items: [
          for (final g in head)
            InsBarItem(
              label: g.name,
              value: g.amount,
              share: total > 0 ? g.amount / total : null,
              onTap: onTap == null ? null : () => onTap!(g),
            ),
          if (rest.isNotEmpty)
            InsBarItem(
              label: 'Others (${rest.length})',
              value: others,
              share: total > 0 ? others / total : null,
              muted: true,
            ),
        ],
      );
    }
    return InsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsCardHeader(title: title, description: description),
          chart,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MONEY TAB — monthly stacked bars
// ═════════════════════════════════════════════════════════════════════════════

enum _Range { m3, m6, m12, all }

extension on _Range {
  String get label => switch (this) {
    _Range.m3 => '3M',
    _Range.m6 => '6M',
    _Range.m12 => '12M',
    _Range.all => 'All',
  };
  int? get months => switch (this) {
    _Range.m3 => 3,
    _Range.m6 => 6,
    _Range.m12 => 12,
    _Range.all => null,
  };
}

_Range _lastRange = _Range.m6; // kept for the session

int _monthKey(DateTime d) => d.year * 12 + d.month - 1;
DateTime _fromKey(int k) => DateTime(k ~/ 12, k % 12 + 1);

class InsMonthlyStackedCard extends StatefulWidget {
  const InsMonthlyStackedCard({super.key, required this.data, this.height = 240});
  final ProjectInsights data;
  final double height;

  @override
  State<InsMonthlyStackedCard> createState() => _InsMonthlyStackedCardState();
}

class _InsMonthlyStackedCardState extends State<InsMonthlyStackedCard> {
  _Range _range = _lastRange;
  int? _sel;

  /// The months in the chosen range, oldest first. Months with no spend are
  /// zero bars. Ends at this month (or the latest month with data).
  List<MonthSpend> _window() {
    final src = widget.data.monthly;
    final byKey = {for (final m in src) _monthKey(m.month): m};
    final keys = byKey.keys.toList()..sort();
    final end = math.max(_monthKey(DateTime.now()), keys.last);
    final n = _range.months;
    final start = n == null ? keys.first : end - n + 1;
    return [for (var k = start; k <= end; k++) byKey[k] ?? MonthSpend(_fromKey(k), const Buckets(0, 0, 0, 0))];
  }

  static double _stackSum(Buckets b) => b.material + b.labour + b.equipment;

  @override
  Widget build(BuildContext context) {
    if (widget.data.monthly.isEmpty) {
      return InsCard(
        child: Text('No approved spend yet.', style: Ins.t(14, c: Ins.ink3)),
      );
    }
    final months = _window();
    final sum = months.fold<double>(0, (s, m) => s + m.spend.total);
    final shownMax = months.fold<double>(0, (m, e) => math.max(m, math.max(e.spend.total, _stackSum(e.spend))));
    final step = shownMax > 0 ? insNiceStep(shownMax * 1.05 / 4) : 1e5;
    final maxY = shownMax > 0 ? step * (shownMax * 1.05 / step).ceil() : 4e5;
    final sel = (_sel != null && _sel! < months.length) ? _sel : null;
    final desc = sum > 0
        ? '${inrCompact(sum)} over ${months.length} ${months.length == 1 ? 'month' : 'months'} · avg ${inrCompact(sum / months.length)} / month'
        : 'No spend in this period';

    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InsCardHeader(title: 'Monthly spend', description: desc),
          ),
          Row(
            children: [
              for (final r in _Range.values) ...[
                BtChip(
                  label: r.label,
                  selected: r == _range,
                  onTap: () => setState(() {
                    _range = _lastRange = r;
                    _sel = null;
                  }),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [for (final c in CostCategory.values) InsSwatch(color: Ins.cat(c), label: c.label)],
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label:
                'Monthly spend chart, ${months.length} months, ${inrFull(sum)} in total. Tap a bar for the month\'s figures.',
            child: ExcludeSemantics(
              child: SizedBox(
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final slot = (box.maxWidth - 52) / months.length;
                    final barW = (slot * .6).clamp(4.0, 36.0);
                    // New range → new key → the grow-in plays again.
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('${_range.name}-${months.length}'),
                      tween: Tween(begin: 0, end: 1),
                      duration: insChartDuration(context),
                      curve: insChartCurve,
                      builder: (context, t, _) => BarChart(
                        duration: Duration.zero,
                        _chartData(months, t: t, maxY: maxY, step: step, barW: barW, sel: sel),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartData _chartData(
    List<MonthSpend> months, {
    required double t,
    required double maxY,
    required double step,
    required double barW,
    required int? sel,
  }) {
    final labelEvery = months.length <= 7 ? 1 : (months.length / 6).ceil();
    return BarChartData(
      maxY: maxY,
      minY: 0,
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
            reservedSize: 52,
            interval: step,
            getTitlesWidget: (v, m) => v == m.max
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(inrCompact(v), textAlign: TextAlign.right, style: _axis()),
                  ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, m) {
              final i = v.toInt();
              if (i < 0 || i >= months.length || i % labelEvery != 0) return const SizedBox.shrink();
              final d = months[i].month;
              final showYear = i == 0 || d.month == 1;
              return SideTitleWidget(
                axisSide: m.axisSide,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('MMM').format(d), style: _axis()),
                    if (showYear) Text("'${(d.year % 100).toString().padLeft(2, '0')}", style: _axis()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        allowTouchBarBackDraw: true,
        touchExtraThreshold: const EdgeInsets.symmetric(horizontal: 6),
        touchCallback: (event, response) {
          if (event is! FlTapUpEvent) return;
          final i = response?.spot?.touchedBarGroupIndex;
          setState(() => _sel = (i == null || i == _sel) ? null : i);
        },
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Ins.ink,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItem: (g, _, _, _) {
            final m = months[g.x];
            final lineStyle = Ins.t(12, c: const Color(0xFFE2E8F0));
            return BarTooltipItem(
              '${DateFormat('MMMM yyyy').format(m.month)}\n',
              Ins.t(12, c: Colors.white, w: FontWeight.w600),
              textAlign: TextAlign.left,
              children: [
                for (final c in CostCategory.values) ...[
                  TextSpan(
                    text: '● ',
                    style: Ins.t(12, c: Ins.cat(c)),
                  ),
                  TextSpan(text: '${c.label}  ${inrFull(m.spend.of(c))}\n', style: lineStyle),
                ],
                TextSpan(
                  text: 'Total  ${inrFull(m.spend.total)}',
                  style: Ins.t(12, c: Colors.white, w: FontWeight.w600),
                ),
              ],
            );
          },
        ),
      ),
      barGroups: [
        for (var i = 0; i < months.length; i++)
          BarChartGroupData(
            x: i,
            showingTooltipIndicators: sel == i ? const [0] : const [],
            barRods: [_rod(months[i].spend, t, barW, maxY)],
          ),
      ],
    );
  }

  /// Stacked rod, scaled by [t] (the grow-in). Segments keep their true size;
  /// a hairline of white separates them.
  BarChartRodData _rod(Buckets b, double t, double w, double maxY) {
    final items = <BarChartRodStackItem>[];
    var y = 0.0;
    for (final c in CostCategory.values) {
      final v = b.of(c) * t;
      if (v <= 0) continue;
      items.add(
        BarChartRodStackItem(y, y + v, Ins.cat(c), const BorderSide(color: Colors.white, width: .75)),
      );
      y += v;
    }
    return BarChartRodData(
      toY: y,
      width: w,
      rodStackItems: items,
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      // Invisible full-height column so empty / tiny months can be tapped too.
      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: Colors.transparent),
    );
  }
}
