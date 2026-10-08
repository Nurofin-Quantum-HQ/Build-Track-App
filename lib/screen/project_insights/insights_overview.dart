import 'dart:math' as math;

import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// VERDICT — one sentence + health meter
// ═════════════════════════════════════════════════════════════════════════════

class VerdictCard extends StatelessWidget {
  const VerdictCard({super.key, required this.data});
  final ProjectInsights data;

  @override
  Widget build(BuildContext context) {
    final h = Ins.health(data.healthStatus);
    final b = data.bridge;
    final forecast = b?.forecast ?? data.eac;
    final delta = forecast == null ? null : forecast - data.budgetTotal;
    final deltaPct = delta == null || data.budgetTotal <= 0 ? null : delta / data.budgetTotal * 100;

    final headline = forecast == null
        ? 'Not enough approved spend yet to forecast the final cost.'
        : delta!.abs() < data.budgetTotal * 0.01
        ? 'Forecast to finish on budget at ${inrCompact(forecast)}.'
        : delta > 0
        ? 'Forecast to finish at ${inrCompact(forecast)} — ${inrCompact(delta)} over budget.'
        : 'Forecast to finish at ${inrCompact(forecast)} — ${inrCompact(-delta)} under budget.';

    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InsBadge(label: h.label, fg: h.fg, bg: h.bg, icon: h.icon),
              const Spacer(),
              Text('Health ', style: Ins.t(13, c: Ins.ink3)),
              Text('${data.healthScore}', style: Ins.num(15)),
              Text(' /100', style: Ins.t(13, c: Ins.ink3)),
            ],
          ),
          const SizedBox(height: 14),
          Text(headline, style: Ins.t(20, w: FontWeight.w600, h: 1.3, ls: -0.2)),
          if (deltaPct != null && deltaPct.abs() >= 1) ...[
            const SizedBox(height: 6),
            Text(
              '${deltaPct > 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}% vs the ${inrCompact(data.budgetTotal)} budget',
              style: Ins.t(14, c: delta! > 0 ? Ins.bad : Ins.good, w: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 18),
          HealthMeter(score: data.healthScore),
          if (data.healthDrivers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Ins.border),
            const SizedBox(height: 12),
            Text('WHY', style: Ins.overline()),
            const SizedBox(height: 8),
            for (final d in data.healthDrivers.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: h.fg),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d, style: Ins.t(14, c: Ins.ink2)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A 0–100 track split into Critical / At risk / On track zones with a marker.
class HealthMeter extends StatelessWidget {
  const HealthMeter({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) => SizedBox(
            height: 22,
            child: CustomPaint(painter: _MeterPainter(t), size: Size.infinite),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 55,
              child: Text('Critical', style: Ins.t(11.5, c: Ins.ink3)),
            ),
            Expanded(
              flex: 25,
              child: Text('At risk', style: Ins.t(11.5, c: Ins.ink3)),
            ),
            Expanded(
              flex: 20,
              child: Text(
                'On track',
                textAlign: TextAlign.right,
                style: Ins.t(11.5, c: Ins.ink3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 8.0;
    final y = (size.height - h) / 2;
    final zones = [
      (0.0, 0.55, const Color(0xFFFECACA)),
      (0.55, 0.80, const Color(0xFFFDE68A)),
      (0.80, 1.0, const Color(0xFFBBF7D0)),
    ];
    for (final (a, b, c) in zones) {
      final l = size.width * a + (a == 0 ? 0 : 1);
      final r = size.width * b - (b == 1 ? 0 : 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(l, y, r, y + h), const Radius.circular(4)),
        Paint()..color = c,
      );
    }
    final x = (size.width * t).clamp(6.0, size.width - 6);
    canvas.drawCircle(Offset(x, size.height / 2), 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(x, size.height / 2),
      9,
      Paint()
        ..color = Ins.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(Offset(x, size.height / 2), 3.5, Paint()..color = Ins.ink);
  }

  @override
  bool shouldRepaint(_MeterPainter o) => o.t != t;
}

// ═════════════════════════════════════════════════════════════════════════════
// PROGRESS LINE — time vs money vs work on one shared 0–100% axis
// ═════════════════════════════════════════════════════════════════════════════

class ProgressLineCard extends StatelessWidget {
  const ProgressLineCard({super.key, required this.data});
  final ProjectInsights data;

  @override
  Widget build(BuildContext context) {
    final spent = data.spentPct ?? 0;
    final work = data.workDonePct;
    final time = data.timeElapsedPct;
    final gap = spent - work;
    final note = gap > 3
        ? 'Money is ${gap.toStringAsFixed(0)} pts ahead of work — paying for work not yet delivered.'
        : gap < -3
        ? 'Work is ${(-gap).toStringAsFixed(0)} pts ahead of money — good cost control.'
        : 'Money and work are moving together.';
    final items = [
      ('Work done', work, Ins.good),
      ('Money spent', spent, Ins.primary),
      if (time != null) ('Time used', time, Ins.ink3),
    ];
    return InsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(
            title: 'Are we getting what we pay for?',
            description: 'Each marker is a % of the whole project',
          ),
          for (final (label, v, c) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(label, style: Ins.t(13.5, c: Ins.ink2)),
                  ),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (v / 100).clamp(0, 1).toDouble()),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, _) => SizedBox(
                        height: 16,
                        child: CustomPaint(painter: _LollipopPainter(f, c), size: Size.infinite),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(pct(v), textAlign: TextAlign.right, style: Ins.num(14)),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gap > 3 ? Ins.warnSoft : Ins.muted,
              borderRadius: BorderRadius.circular(Ins.rSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  gap > 3 ? Icons.warning_amber_rounded : Icons.insights_rounded,
                  size: 18,
                  color: gap > 3 ? Ins.warn : Ins.ink3,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(note, style: Ins.t(13.5, c: Ins.ink2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LollipopPainter extends CustomPainter {
  _LollipopPainter(this.f, this.color);
  final double f;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - 2, size.width, 4), const Radius.circular(2)),
      Paint()..color = Ins.muted,
    );
    final x = size.width * f;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - 2, x, 4), const Radius.circular(2)),
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(Offset(x.clamp(6, size.width - 6), cy), 6, Paint()..color = color);
    canvas.drawCircle(
      Offset(x.clamp(6, size.width - 6), cy),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_LollipopPainter o) => o.f != f || o.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
// KPI GRID
// ═════════════════════════════════════════════════════════════════════════════

class InsKpiGrid extends StatelessWidget {
  const InsKpiGrid({super.key, required this.data, this.columns});
  final ProjectInsights data;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final cpi = data.cpi;
    final tiles = <Widget>[
      _Kpi(
        label: 'Spent',
        value: inrCompact(data.actual),
        sub: '${pct(data.spentPct)} of ${inrCompact(data.budgetTotal)}',
        icon: Icons.payments_outlined,
      ),
      _Kpi(
        label: 'Value of work done',
        value: inrCompact(data.earnedValue),
        sub: '${pct(data.workDonePct)} earned',
        icon: Icons.foundation_outlined,
      ),
      _Kpi(
        label: 'Cost efficiency',
        value: cpi == null ? '—' : '₹${cpi.toStringAsFixed(2)}',
        sub: cpi == null ? 'Needs approved spend' : 'of work per ₹1 spent',
        icon: Icons.speed_outlined,
        tone: cpi == null
            ? null
            : (cpi >= 1
                  ? Ins.good
                  : cpi >= 0.9
                  ? Ins.warn
                  : Ins.bad),
        toneLabel: cpi == null
            ? null
            : (cpi >= 1
                  ? 'Efficient'
                  : cpi >= 0.9
                  ? 'Slight leak'
                  : 'Leaking'),
      ),
      _Kpi(
        label: 'Days left',
        value: data.daysLeft == null ? '—' : '${math.max(0, data.daysLeft!)}',
        sub: data.endDate == null
            ? 'No end date set'
            : data.daysLeft! < 0
            ? '${-data.daysLeft!} days overdue'
            : 'Due ${dateShort.format(data.endDate!)}',
        icon: Icons.event_outlined,
        tone: data.daysLeft != null && data.daysLeft! < 0 ? Ins.bad : null,
        toneLabel: data.daysLeft != null && data.daysLeft! < 0 ? 'Overdue' : null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = columns ?? (c.maxWidth >= 640 ? 4 : 2);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    this.tone,
    this.toneLabel,
  });
  final String label, value, sub;
  final IconData icon;
  final Color? tone;
  final String? toneLabel;

  @override
  Widget build(BuildContext context) {
    return InsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Ins.t(13, c: Ins.ink3, w: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: Ins.ink3),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Ins.num(24, w: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: Ins.t(12.5, c: Ins.ink3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (tone != null && toneLabel != null) ...[
            const SizedBox(height: 8),
            InsBadge(label: toneLabel!, fg: tone!, bg: tone!.withValues(alpha: 0.1)),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BUDGET BRIDGE — variance waterfall: 0 → reserve → phase deltas → untagged → net
// ═════════════════════════════════════════════════════════════════════════════

class BudgetBridgeCard extends StatelessWidget {
  const BudgetBridgeCard({super.key, required this.data, this.onTapPhase});
  final ProjectInsights data;
  final void Function(String phaseId)? onTapPhase;

  @override
  Widget build(BuildContext context) {
    final b = data.bridge;
    if (b == null) return const SizedBox.shrink();
    final rows = <_BridgeRow>[];
    double run = 0;
    void add(String label, double delta, {String? phaseId, String? hint}) {
      rows.add(_BridgeRow(label, run, run + delta, phaseId: phaseId, hint: hint));
      run += delta;
    }

    if (b.reserve.abs() >= 1) add('Unassigned reserve', b.reserve, hint: 'Budget not given to any phase');
    final steps = [...b.steps]..sort((x, y) => y.delta.compareTo(x.delta));
    for (final s in steps) {
      add(s.name, s.delta, phaseId: s.phaseId);
    }
    if (b.untagged.abs() >= 1) add('Untagged spend', b.untagged, hint: 'Entries without a phase');

    final lo = rows.map((r) => math.min(r.from, r.to)).fold<double>(0, math.min);
    final hi = rows.map((r) => math.max(r.from, r.to)).fold<double>(0, math.max);
    final net = b.variance;
    final span = math.max(hi - lo, net.abs()).toDouble();

    return InsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InsCardHeader(
            title: 'Budget bridge',
            description: 'How each phase moves the final cost away from budget',
          ),
          Row(
            children: [
              Text('Budget', style: Ins.t(13.5, c: Ins.ink3)),
              const Spacer(),
              Text(inrCompact(b.budget), style: Ins.num(16)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Ins.border),
          const SizedBox(height: 6),
          for (final r in rows)
            _BridgeTile(
              row: r,
              lo: lo,
              span: span <= 0 ? 1 : span,
              onTap: r.phaseId != null && onTapPhase != null ? () => onTapPhase!(r.phaseId!) : null,
            ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Ins.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Forecast final cost', style: Ins.t(14, w: FontWeight.w600)),
              const Spacer(),
              Text(inrCompact(b.forecast), style: Ins.num(18, w: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                net > 0 ? Icons.north_east_rounded : Icons.south_east_rounded,
                size: 15,
                color: net > 0 ? Ins.bad : Ins.good,
              ),
              const SizedBox(width: 4),
              Text(
                '${inrCompact(net.abs())} ${net > 0 ? 'over' : 'under'} budget',
                style: Ins.t(13, c: net > 0 ? Ins.bad : Ins.good, w: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            children: const [
              InsSwatch(color: Ins.bad, label: 'Adds cost'),
              InsSwatch(color: Ins.under, label: 'Saves cost'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BridgeRow {
  _BridgeRow(this.label, this.from, this.to, {this.phaseId, this.hint});
  final String label;
  final double from, to;
  final String? phaseId, hint;
  double get delta => to - from;
}

class _BridgeTile extends StatelessWidget {
  const _BridgeTile({required this.row, required this.lo, required this.span, this.onTap});
  final _BridgeRow row;
  final double lo, span;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final up = row.delta > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ins.rSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Ins.tap),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.label,
                      style: Ins.t(13.5, w: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (row.hint != null) Text(row.hint!, style: Ins.t(11.5, c: Ins.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 10,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, _) => SizedBox(
                    height: 18,
                    child: CustomPaint(
                      painter: _WaterfallPainter(
                        from: (row.from - lo) / span,
                        to: (row.from + row.delta * t - lo) / span,
                        zero: -lo / span,
                        color: up ? Ins.bad : Ins.under,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  inrCompact(row.delta, sign: true),
                  textAlign: TextAlign.right,
                  style: Ins.num(13.5, c: up ? Ins.bad : Ins.under),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  _WaterfallPainter({required this.from, required this.to, required this.zero, required this.color});
  final double from, to, zero;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // zero baseline
    final zx = size.width * zero;
    canvas.drawRect(Rect.fromLTWH(zx - 0.5, 0, 1, size.height), Paint()..color = Ins.borderStrong);
    final l = size.width * math.min(from, to);
    final r = size.width * math.max(from, to);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(l, 3, math.max(r, l + 2), size.height - 3), const Radius.circular(3)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_WaterfallPainter o) => o.from != from || o.to != to || o.zero != zero;
}

// ═════════════════════════════════════════════════════════════════════════════
// ATTENTION
// ═════════════════════════════════════════════════════════════════════════════

class AttentionCard extends StatefulWidget {
  const AttentionCard({super.key, required this.alerts, this.onTapPhase, this.initial = 3});
  final List<InsightAlert> alerts;
  final void Function(String phaseId)? onTapPhase;
  final int initial;

  @override
  State<AttentionCard> createState() => _AttentionCardState();
}

class _AttentionCardState extends State<AttentionCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final list = _all ? widget.alerts : widget.alerts.take(widget.initial).toList();
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsCardHeader(
            title: 'Needs attention',
            description: widget.alerts.isEmpty
                ? 'Nothing flagged right now'
                : '${widget.alerts.length} items, most urgent first',
          ),
          if (widget.alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Ins.good, size: 20),
                  const SizedBox(width: 8),
                  Text('All phases are within plan.', style: Ins.t(14, c: Ins.ink2)),
                ],
              ),
            ),
          for (final a in list)
            _AlertTile(
              alert: a,
              onTap: a.phaseId != null && widget.onTapPhase != null ? () => widget.onTapPhase!(a.phaseId!) : null,
            ),
          if (widget.alerts.length > widget.initial)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(Ins.tap, Ins.tap), foregroundColor: Ins.primary),
                onPressed: () => setState(() => _all = !_all),
                child: Text(
                  _all ? 'Show less' : 'Show all ${widget.alerts.length}',
                  style: Ins.t(14, w: FontWeight.w600, c: Ins.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, this.onTap});
  final InsightAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Ins.severity(alert.severity);
    final detail = alert.date != null
        ? 'Around ${dateShort.format(alert.date!)} at the current spend rate'
        : alert.amount != null
        ? switch (alert.kind) {
            'pending' => '${inrCompact(alert.amount!)} waiting for approval',
            'unallocated' => '${inrCompact(alert.amount!)} not linked to a phase',
            _ => '${inrCompact(alert.amount!, sign: true)} vs plan',
          }
        : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ins.rSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(Ins.rSm)),
                child: Icon(s.icon, size: 19, color: s.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: Ins.t(14, w: FontWeight.w500)),
                    if (detail != null) Text(detail, style: Ins.t(12.5, c: Ins.ink3)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Ins.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
