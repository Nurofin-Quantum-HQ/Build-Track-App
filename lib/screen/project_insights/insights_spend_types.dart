import 'dart:math' as math;

import 'package:buildtrack_mobile/common/utils/entry_names.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart' show PaymentStatus;
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// "By type" tab of project insights: where the money went inside each cost
/// category — per labour type (and worker / contractor), per material, per
/// equipment item. Computed on the device from the project's entries
/// (GET /transactions), so it works with the live server as it is.
class InsSpendByTypeView extends StatefulWidget {
  const InsSpendByTypeView({super.key, required this.projectId, this.projectName, this.reloadTick = 0});
  final String projectId;
  final String? projectName;

  /// Bumped by the parent's pull-to-refresh to refetch entries.
  final int reloadTick;

  @override
  State<InsSpendByTypeView> createState() => _InsSpendByTypeViewState();
}

enum _Period { all, month, d90, fy }

extension on _Period {
  String get label => switch (this) {
    _Period.all => 'All time',
    _Period.month => 'This month',
    _Period.d90 => 'Last 90 days',
    _Period.fy => 'This FY',
  };

  DateTime? get from {
    final now = DateTime.now();
    return switch (this) {
      _Period.all => null,
      _Period.month => DateTime(now.year, now.month),
      _Period.d90 => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89)),
      _Period.fy => DateTime(now.month >= 4 ? now.year : now.year - 1, 4),
    };
  }
}

// Remembered for the session so switching projects keeps the same view.
CostCategory _lastCat = CostCategory.labour;
_Period _lastPeriod = _Period.all;

class _InsSpendByTypeViewState extends State<InsSpendByTypeView> {
  List<SpendLine>? _lines;
  SpendBreakdown? _bd;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  CostCategory _cat = _lastCat;
  _Period _period = _lastPeriod;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InsSpendByTypeView old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId || old.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<SpendLine>? lines;
    var offline = false;
    String? error;
    try {
      final raw = await ApiService.fetchMaterials(projectId: widget.projectId);
      lines = _parse(raw);
    } catch (e) {
      // Offline / server error: fall back to the entries the app already
      // has for this project (only the selected project is cached).
      if (!mounted) return;
      final cached = context.read<ProjectProvider>().entriesForProject(widget.projectId);
      if (cached.isNotEmpty) {
        lines = _parse(cached.map((e) => e.rawJson ?? e.toJson()));
        offline = true;
      } else {
        error = '$e'.replaceFirst('Exception: ', '');
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = offline;
      _error = lines == null ? error : null;
      if (lines != null) _lines = lines;
      _recompute();
    });
  }

  List<SpendLine> _parse(Iterable<dynamic> raw) => [
    for (final j in raw)
      if (j is Map)
        ?SpendLine.tryParse(j is Map<String, dynamic> ? j : Map<String, dynamic>.from(j)),
  ];

  /// Runs only when the data or the period changes — never in build.
  void _recompute() {
    final lines = _lines;
    _bd = lines == null ? null : SpendBreakdown.compute(lines, projectId: widget.projectId, from: _period.from);
  }

  void _setPeriod(_Period p) => setState(() {
    _period = _lastPeriod = p;
    _recompute();
  });

  void _setCat(CostCategory c) => setState(() => _cat = _lastCat = c);

  /// Material parents with several children open the child list; a parent
  /// with one child (and every other group) opens the detail page directly.
  void _open(SpendGroup g, String scope) {
    final cat = _cat, period = _period.label;
    if (g.children.length > 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => _ChildrenPage(parent: g, category: cat, period: period)));
      return;
    }
    final target = g.children.length == 1 ? g.children.first : g;
    final sc = g.children.length == 1 ? g.name : scope;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _GroupEntriesPage(group: target, category: cat, scope: sc, period: period)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bd = _bd;
    if (bd == null) {
      if (_loading) {
        return Column(children: [
          for (final h in [44.0, 130.0, 320.0])
            Container(
              height: h,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Ins.muted, borderRadius: BorderRadius.circular(Ins.r)),
            ),
        ]);
      }
      return InsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const InsCardHeader(title: 'Couldn\'t load entries'),
          Text(_error ?? 'Something went wrong.', style: Ins.t(14, c: Ins.ink3)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Ins.primary, minimumSize: const Size(120, Ins.tap)),
            onPressed: _load,
            child: const Text('Try again'),
          ),
        ]),
      );
    }
    final c = bd.byCategory[_cat]!;
    final color = Ins.cat(_cat);
    final nameTitle = switch (_cat) {
      CostCategory.labour => 'By labour type',
      CostCategory.material => 'By material',
      CostCategory.equipment => 'By equipment',
    };
    final nameHint = switch (_cat) {
      CostCategory.labour => 'Painters, masons, tile work… as entered in "Labour type"',
      CostCategory.material => 'Grouped by kind — tap one to see each material inside it',
      CostCategory.equipment => 'Each machine or equipment item',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CatSegment(value: _cat, onChanged: _setCat, totals: {for (final k in CostCategory.values) k: bd.byCategory[k]!.total}),
      const SizedBox(height: 10),
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: _Period.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final p = _Period.values[i];
            return BtChip(label: p.label, selected: p == _period, onTap: () => _setPeriod(p));
          },
        ),
      ),
      if (_offline) ...[
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 15, color: Ins.warn),
          const SizedBox(width: 6),
          Expanded(child: Text('Offline — showing the entries saved on this phone.', style: Ins.t(12.5, c: Ins.warn))),
        ]),
      ],
      const SizedBox(height: 12),
      _SummaryCard(data: c, color: color, period: _period.label),
      const SizedBox(height: 12),
      _GroupsCard(
        title: nameTitle,
        description: nameHint,
        groups: c.byName,
        color: color,
        showQty: _cat != CostCategory.labour,
        emptyText: 'No ${_cat.label.toLowerCase()} entries ${_period == _Period.all ? 'yet' : 'in this period'}.',
        onTap: (g) => _open(g, nameTitle.replaceFirst('By ', '')),
      ),
      if (_cat == CostCategory.labour && c.count > 0) ...[
        const SizedBox(height: 12),
        _GroupsCard(
          title: 'By worker / contractor',
          description: 'Worker on the entry, else the contractor / team',
          groups: c.byPerson,
          color: color,
          showQty: false,
          emptyText: '',
          onTap: (g) => _open(g, 'Worker / contractor'),
        ),
      ],
    ]);
  }
}

// ── Category segment ────────────────────────────────────────────────────────

class _CatSegment extends StatelessWidget {
  const _CatSegment({required this.value, required this.onChanged, required this.totals});
  final CostCategory value;
  final ValueChanged<CostCategory> onChanged;
  final Map<CostCategory, double> totals;
  static const _order = [CostCategory.labour, CostCategory.material, CostCategory.equipment];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Ins.muted, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final c in _order)
          Expanded(
            child: Semantics(
              button: true,
              selected: c == value,
              label: '${c.label}, ${inrCompact(totals[c] ?? 0)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: Ins.motion,
                  alignment: Alignment.center,
                  decoration: c == value
                      ? BoxDecoration(color: Ins.card, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 3, offset: Offset(0, 1))])
                      : null,
                  child: ExcludeSemantics(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: Ins.cat(c), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(c == CostCategory.material ? 'Materials' : c.label,
                              overflow: TextOverflow.ellipsis,
                              style: Ins.t(13.5, w: c == value ? FontWeight.w600 : FontWeight.w500, c: c == value ? Ins.ink : Ins.ink3)),
                        ),
                      ]),
                      Text(inrCompact(totals[c] ?? 0), style: Ins.t(11.5, c: Ins.ink3, h: 1.2)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Summary ─────────────────────────────────────────────────────────────────

class _PaidBar extends StatelessWidget {
  const _PaidBar({required this.paid, required this.pending, required this.color, this.height = 10, this.fraction = 1});
  final double paid, pending, fraction, height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = paid + pending;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final filled = (w * fraction.clamp(0.0, 1.0)).clamp(total > 0 ? 3.0 : 0.0, w);
      final paidW = total > 0 ? filled * paid / total : 0.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: Ins.muted,
          alignment: Alignment.centerLeft,
          child: Row(children: [
            Container(width: paidW, color: color),
            Container(width: filled - paidW, color: color.withValues(alpha: .32)),
          ]),
        ),
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.color, required this.period});
  final SpendCategoryBreakdown data;
  final Color color;
  final String period;

  @override
  Widget build(BuildContext context) {
    final paidPct = data.total > 0 ? (data.paid / data.total * 100).round() : 0;
    return InsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Ins.catIcon(data.category), size: 18, color: color),
          const SizedBox(width: 6),
          Text('${data.category.label.toUpperCase()} SPEND · ${period.toUpperCase()}', style: Ins.overline()),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(inrFull(data.total), style: Ins.num(28))),
          Text('${data.count} ${data.count == 1 ? 'entry' : 'entries'}', style: Ins.t(13, c: Ins.ink3)),
        ]),
        const SizedBox(height: 12),
        _PaidBar(paid: data.paid, pending: data.pending, color: color),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Stat(label: 'Paid', value: inrCompact(data.paid), sub: data.total > 0 ? '$paidPct%' : null, swatch: color)),
          Expanded(child: _Stat(label: 'To pay', value: inrCompact(data.pending), sub: data.total > 0 ? '${100 - paidPct}%' : null, swatch: color.withValues(alpha: .32))),
        ]),
        if (data.awaitingApproval > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.hourglass_empty_rounded, size: 15, color: Ins.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Includes ${data.awaitingApproval} ${data.awaitingApproval == 1 ? 'entry' : 'entries'} awaiting approval. Rejected entries are left out.',
                style: Ins.t(12.5, c: Ins.ink3),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.sub, required this.swatch});
  final String label, value;
  final String? sub;
  final Color swatch;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: Ins.t(12.5, c: Ins.ink2)),
    ]),
    const SizedBox(height: 2),
    Text.rich(TextSpan(children: [
      TextSpan(text: value, style: Ins.num(16)),
      if (sub != null) TextSpan(text: '  $sub', style: Ins.t(12, c: Ins.ink3)),
    ])),
  ]);
}

// ── Group list ──────────────────────────────────────────────────────────────

String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(q.abs() < 10 ? 2 : 1).replaceFirst(RegExp(r'\.?0+$'), '');

class _GroupsCard extends StatefulWidget {
  const _GroupsCard({
    required this.title,
    required this.description,
    required this.groups,
    required this.color,
    required this.showQty,
    required this.emptyText,
    required this.onTap,
  });
  final String title, description, emptyText;
  final List<SpendGroup> groups;
  final Color color;
  final bool showQty;
  final ValueChanged<SpendGroup> onTap;

  @override
  State<_GroupsCard> createState() => _GroupsCardState();
}

class _GroupsCardState extends State<_GroupsCard> {
  static const _collapsed = 8;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final shown = _all || groups.length <= _collapsed + 2 ? groups : groups.take(_collapsed).toList();
    final top = groups.isEmpty ? 1.0 : groups.map((g) => g.amount).reduce(math.max);
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InsCardHeader(title: widget.title, description: widget.description),
        if (groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 14, runSpacing: 6, children: [
              InsSwatch(color: widget.color, label: 'Paid'),
              InsSwatch(color: widget.color.withValues(alpha: .32), label: 'To pay'),
            ]),
          ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.emptyText, style: Ins.t(14, c: Ins.ink3)),
          ),
        for (var i = 0; i < shown.length; i++)
          _GroupRow(rank: i + 1, group: shown[i], color: widget.color, fraction: shown[i].amount / top, showQty: widget.showQty, onTap: () => widget.onTap(shown[i])),
        if (shown.length < groups.length)
          InkWell(
            onTap: () => setState(() => _all = true),
            child: Container(
              constraints: const BoxConstraints(minHeight: Ins.tap),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ins.border))),
              alignment: Alignment.center,
              child: Text('Show all ${groups.length}', style: Ins.t(14, w: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.rank, required this.group, required this.color, required this.fraction, required this.showQty, required this.onTap});
  final int rank;
  final SpendGroup group;
  final Color color;
  final double fraction;
  final bool showQty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final meta = <String>[
      '${(g.share * 100).toStringAsFixed(g.share < .01 && g.share > 0 ? 1 : 0)}% of total',
      if (g.children.length > 1) '${g.children.length} types',
      '${g.count} ${g.count == 1 ? 'entry' : 'entries'}',
      if (showQty && g.quantity != null) '${_qty(g.quantity!)} ${g.unit}',
      if (showQty && g.avgRate != null) 'avg ${inrCompact(g.avgRate!)}/${g.unit}',
    ];
    return Semantics(
      button: true,
      label: '${g.name}, ${inrFull(g.amount)}, ${meta.join(', ')}, ${inrFull(g.pending)} to pay',
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ins.border))),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ExcludeSemantics(
            child: Row(children: [
              SizedBox(width: 22, child: Text('$rank', style: Ins.mono(13, c: Ins.ink3))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(g.name, style: Ins.t(14, w: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text(inrCompact(g.amount), style: Ins.num(14)),
                  ]),
                  const SizedBox(height: 6),
                  _PaidBar(paid: g.paid, pending: g.pending, color: color, height: 6, fraction: fraction),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: Text(meta.join(' · '), style: Ins.t(11.5, c: Ins.ink3), overflow: TextOverflow.ellipsis)),
                    if (g.pending > 0.5) Text('${inrCompact(g.pending)} to pay', style: Ins.t(11.5, c: Ins.warn, w: FontWeight.w600)),
                  ]),
                ]),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Ins.ink3),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Pages: shared chrome ───────────────────────────────────────────────────

PreferredSizeWidget _insAppBar(String title, String subtitle) => AppBar(
  toolbarHeight: 64,
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.white,
  scrolledUnderElevation: 0,
  elevation: 0,
  shape: const Border(bottom: BorderSide(color: Ins.border)),
  foregroundColor: Ins.ink,
  titleSpacing: 0,
  title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Ins.t(17, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
    Text(subtitle, style: Ins.t(12.5, c: Ins.ink3), overflow: TextOverflow.ellipsis),
  ]),
);

/// ₹ with paise only for small fractional rates (₹7.50/kg), else whole rupees.
String _rate(double r) => r < 100 && r != r.roundToDouble() ? '₹${r.toStringAsFixed(2)}' : inrFull(r);

/// Total, paid / to pay, entries, quantity + average rate of one group.
class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.group, required this.category});
  final SpendGroup group;
  final CostCategory category;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final color = Ins.cat(category);
    final paidPct = g.amount > 0 ? (g.paid / g.amount * 100).round() : 0;
    final mixedUnits = g.quantity == null && g.lines.any((l) => l.quantity > 0);
    final units = mixedUnits
        ? (g.lines.map((l) => l.unit.trim()).where((u) => u.isNotEmpty).toSet().toList()..sort()).join(', ')
        : '';
    return InsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TOTAL SPENT', style: Ins.overline()),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(inrFull(g.amount), style: Ins.num(26))),
          Text('${(g.share * 100).toStringAsFixed(g.share < .01 && g.share > 0 ? 1 : 0)}% of ${category.label.toLowerCase()}',
              style: Ins.t(13, c: Ins.ink3)),
        ]),
        const SizedBox(height: 12),
        _PaidBar(paid: g.paid, pending: g.pending, color: color),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(label: 'Paid', value: inrCompact(g.paid), sub: g.amount > 0 ? '$paidPct%' : null, swatch: color)),
          Expanded(
            child: _Stat(
              label: 'To pay',
              value: inrCompact(g.pending),
              sub: g.amount > 0 ? '${100 - paidPct}%' : null,
              swatch: color.withValues(alpha: .32),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: Ins.border),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Fact(label: 'Entries', value: '${g.count}')),
          Expanded(child: _Fact(label: 'Total quantity', value: g.quantity != null ? '${_qty(g.quantity!)} ${g.unit}' : '—')),
          Expanded(child: _Fact(label: 'Average rate', value: g.avgRate != null ? '${_rate(g.avgRate!)}/${g.unit}' : '—')),
        ]),
        if (mixedUnits) ...[
          const SizedBox(height: 8),
          Text('Entries use different units${units.isEmpty ? '' : ' ($units)'}, so quantity isn\'t added up.',
              style: Ins.t(12.5, c: Ins.ink3)),
        ],
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color = Ins.ink});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Ins.t(11.5, c: Ins.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(value, style: Ins.num(14, c: color), maxLines: 1),
    ),
  ]);
}

// ── Children of a material parent (Sand → M-Sand, P-Sand, …) ───────────────

class _ChildrenPage extends StatelessWidget {
  const _ChildrenPage({required this.parent, required this.category, required this.period});
  final SpendGroup parent;
  final CostCategory category;
  final String period;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ins.bg,
      appBar: _insAppBar(parent.name, '${category.label} · $period'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 32),
        children: [
          _GroupHeaderCard(group: parent, category: category),
          const SizedBox(height: 12),
          _GroupsCard(
            title: 'Inside ${parent.name}',
            description: 'Tap one to see its entries',
            groups: parent.children,
            color: Ins.cat(category),
            showQty: true,
            emptyText: '',
            onTap: (c) => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _GroupEntriesPage(group: c, category: category, scope: parent.name, period: period)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail of one group: header + entries (like Reports) ────────────────────

class _GroupEntriesPage extends StatelessWidget {
  const _GroupEntriesPage({required this.group, required this.category, required this.scope, required this.period});
  final SpendGroup group;
  final CostCategory category;
  final String scope;
  final String period;

  @override
  Widget build(BuildContext context) {
    final g = group;
    // Show each entry's own name when the group merges different names
    // (e.g. Sand → "Sand", "Fine sand", or a worker's several labour types).
    final showName = g.lines.map((l) => entryNameKey(l.name)).toSet().length > 1;
    return Scaffold(
      backgroundColor: Ins.bg,
      appBar: _insAppBar(g.name, '${category.label} · $scope · $period'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 32),
        children: [
          _GroupHeaderCard(group: g, category: category),
          const SizedBox(height: 12),
          InsCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InsCardHeader(title: '${g.count} ${g.count == 1 ? 'entry' : 'entries'}', description: 'Newest first · tap an entry to open it'),
              for (final l in g.lines) _EntryRow(line: l, showName: showName),
            ]),
          ),
        ],
      ),
    );
  }
}

/// One entry, Reports columns stacked for a phone: date + amount + status,
/// floor/phase/activity, supplier or worker, then Qty · Rate · Paid · Remaining.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.line, required this.showName});
  final SpendLine line;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final party = l.party;
    final partyLabel = l.category == CostCategory.labour ? 'Worker' : 'Supplier';
    final title = [
      l.date != null ? dateShort.format(l.date!) : 'No date',
      if (showName && l.name.isNotEmpty) entryNameDisplay(l.name),
    ].join(' · ');
    final place = l.place;
    final rate = l.rate;
    final status = l.paid >= l.amount - 0.5
        ? (fg: Ins.good, bg: Ins.goodSoft, label: 'Paid')
        : l.paid > 0
        ? (fg: Ins.warn, bg: Ins.warnSoft, label: 'Partial')
        : (fg: Ins.ink3, bg: Ins.muted, label: 'To pay');
    return Semantics(
      button: l.id.isNotEmpty,
      label: '$title, ${inrFull(l.amount)}, ${status.label}'
          '${place.isNotEmpty ? ', $place' : ''}${party.isNotEmpty ? ', $partyLabel $party' : ''}'
          ', paid ${inrFull(l.paid)}, remaining ${inrFull(l.pending)}',
      child: InkWell(
        onTap: l.id.isEmpty ? null : () => Navigator.pushNamed(context, '/entry-detail', arguments: _entryDetailArgs(l)),
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ins.border))),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ExcludeSemantics(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: Ins.t(14, w: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(place.isEmpty ? 'No floor / phase' : place,
                            style: Ins.t(12.5, c: Ins.ink3), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (party.isNotEmpty)
                          Text('$partyLabel: $party', style: Ins.t(12.5, c: Ins.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(inrFull(l.amount), style: Ins.num(15)),
                      const SizedBox(height: 4),
                      InsBadge(label: status.label, fg: status.fg, bg: status.bg),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _Fact(label: 'Qty', value: l.quantity > 0 ? '${_qty(l.quantity)} ${l.unit}'.trim() : '—')),
                    Expanded(child: _Fact(label: 'Rate', value: rate != null ? _rate(rate) : '—')),
                    Expanded(child: _Fact(label: 'Paid', value: inrFull(l.paid))),
                    Expanded(child: _Fact(label: 'Remaining', value: inrFull(l.pending), color: l.pending > 0.5 ? Ins.warn : Ins.ink)),
                  ]),
                  if (!l.approved) ...[
                    const SizedBox(height: 6),
                    Text('Awaiting approval', style: Ins.t(12, c: Ins.warn)),
                  ],
                ]),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: Ins.ink3),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Transaction JSON → `/entry-detail` arguments (same shape the inbox uses;
/// the detail screen refetches the entry by id).
Map<String, dynamic> _entryDetailArgs(SpendLine l) {
  final tx = l.raw;
  double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  final isPositive = '${tx['subType'] ?? ''}'.toLowerCase() != 'consumption';
  final project = tx['project'];
  final projectName = project is Map ? project['projectName']?.toString() : null;
  final createdBy = tx['createdBy'];
  final approval = '${tx['approvalStatus'] ?? ''}'.toLowerCase();
  final payStatus = l.paid >= l.amount - 0.5
      ? PaymentStatus.paid
      : l.paid > 0
      ? PaymentStatus.partial
      : PaymentStatus.pending;
  final attachments = tx['attachments'];
  final title = l.name.isEmpty ? 'Entry' : l.name;
  return {
    ...tx,
    'id': l.id,
    'title': title,
    'name': title,
    'ref': l.id.length > 4 ? '#${l.id.substring(l.id.length - 4)}' : '#${l.id}',
    'amount': '${isPositive ? '+' : '-'}${tx['quantity'] ?? 0}',
    'date': tx['date']?.toString() ?? '',
    'isPositive': isPositive,
    'type': l.category.key,
    'receipt': (attachments is List && attachments.isNotEmpty) ? attachments.first?.toString() : null,
    'attachment': null,
    'createdBy': createdBy is Map ? '${createdBy['_id'] ?? ''}' : '${createdBy ?? ''}',
    'project': l.projectId,
    'projectId': l.projectId,
    'projectName': ?projectName,
    'status': approval == 'approved' ? 'approved' : (approval == 'rejected' ? 'rejected' : 'pending'),
    'paymentStatus': payStatus,
    'billAmount': l.amount,
    'paidAmount': l.paid,
    'supplier': tx['supplier'] ?? '',
    'paymentMethod': tx['paymentMode'] ?? '',
    'lastUpdated': tx['updatedAt'] ?? tx['date'] ?? '',
    'paymentHistory': tx['paymentHistory'],
    'rate': d(tx['rate'] ?? tx['ratePerUnit']),
    'brand': tx['brand'] ?? '',
    'notes': tx['notes'] ?? '',
    'remarks': tx['remarks'] ?? '',
    'categoryName': tx['category'] ?? '',
    'quantity': l.quantity,
    'overtime': d(tx['overtime']),
    'subType': tx['subType'] ?? '',
    'materialType': tx['materialType'] ?? '',
    'floor': tx['floor']?.toString(),
    'phase': tx['phase']?.toString(),
    'activity': tx['activity']?.toString(),
    'paymentReceipt': tx['paymentReceipt']?.toString(),
  };
}
