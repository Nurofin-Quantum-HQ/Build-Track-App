import 'dart:math' as math;

import 'package:buildtrack_mobile/common/utils/date_parse.dart';
// Typed view of GET /api/projects/:id/insights (project insights screen).
// Mirrors core/backend/services/projectInsights.js.

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(dynamic v) => v == null ? null : _d(v);
DateTime? _dt(dynamic v) => parseFlexibleDate(v);
Map<String, dynamic> _m(dynamic v) => v is Map<String, dynamic> ? v : const {};
List<dynamic> _l(dynamic v) => v is List ? v : const [];

enum CostCategory { material, labour, equipment }

extension CostCategoryX on CostCategory {
  String get key => name;
  String get label => switch (this) {
    CostCategory.material => 'Material',
    CostCategory.labour => 'Labour',
    CostCategory.equipment => 'Equipment',
  };
}

class Buckets {
  final double material, labour, equipment, total;
  const Buckets(this.material, this.labour, this.equipment, this.total);
  factory Buckets.fromJson(dynamic j) {
    final m = _m(j);
    return Buckets(_d(m['material']), _d(m['labour']), _d(m['equipment']), _d(m['total']));
  }
  double of(CostCategory c) => switch (c) {
    CostCategory.material => material,
    CostCategory.labour => labour,
    CostCategory.equipment => equipment,
  };
}

class InsightActivity {
  final String id, name;
  final bool completed;
  final Buckets planned, actual;
  InsightActivity.fromJson(Map<String, dynamic> j)
    : id = '${j['id'] ?? ''}',
      name = '${j['name'] ?? ''}',
      completed = j['completed'] == true,
      planned = Buckets.fromJson(j['planned']),
      actual = Buckets.fromJson(j['actual']);
  bool get started => actual.total > 0;
}

class InsightPhase {
  final String id, name, status;
  final int activitiesDone, activitiesTotal;
  final double workDonePct, earnedPct;
  final double? spentPct, variancePct, forecast;
  final Buckets planned, actual;
  final Map<CostCategory, double> earnedByCat;
  final Map<CostCategory, double?> forecastByCat;
  final List<String> overCategories;
  final List<InsightActivity> activities;
  InsightPhase.fromJson(Map<String, dynamic> j)
    : id = '${j['id'] ?? ''}',
      name = '${j['name'] ?? ''}',
      status = '${j['status'] ?? 'ok'}',
      activitiesDone = _d(j['activitiesDone']).toInt(),
      activitiesTotal = _d(j['activitiesTotal']).toInt(),
      workDonePct = _d(j['workDonePct']),
      earnedPct = _d(j['earnedPct']),
      spentPct = _dn(j['spentPct']),
      variancePct = _dn(j['variancePct']),
      forecast = _dn(j['forecast']),
      planned = Buckets.fromJson(j['planned']),
      actual = Buckets.fromJson(j['actual']),
      earnedByCat = {for (final c in CostCategory.values) c: _d(_m(j['earnedByCat'])[c.key])},
      forecastByCat = {for (final c in CostCategory.values) c: _dn(_m(j['forecastByCat'])[c.key])},
      overCategories = _l(j['overCategories']).map((e) => '$e').toList(),
      activities = _l(j['activities']).whereType<Map<String, dynamic>>().map(InsightActivity.fromJson).toList();

  /// Forecast minus plan; positive = heading over budget.
  double? get forecastVariance => forecast == null ? null : forecast! - planned.total;
}

class BridgeStep {
  final String? phaseId;
  final String name;
  final double delta;
  BridgeStep(this.phaseId, this.name, this.delta);
}

/// Budget → forecast, every rupee traceable: budget + reserve + Σ phase deltas + untagged = forecast.
class BudgetBridge {
  final double budget, reserve, untagged, forecast;
  final List<BridgeStep> steps;
  BudgetBridge.fromJson(Map<String, dynamic> j)
    : budget = _d(j['budget']),
      reserve = _d(j['reserve']),
      untagged = _d(j['untagged']),
      forecast = _d(j['forecast']),
      steps = _l(j['steps'])
          .whereType<Map<String, dynamic>>()
          .map((s) => BridgeStep(s['phaseId']?.toString(), '${s['name'] ?? ''}', _d(s['delta'])))
          .toList();
  double get variance => forecast - budget;
}

class InsightAlert {
  final String severity, kind, title;
  final String? phaseId;
  final double? amount;
  final DateTime? date;
  InsightAlert.fromJson(Map<String, dynamic> j)
    : severity = '${j['severity'] ?? 'info'}',
      kind = '${j['kind'] ?? ''}',
      title = '${j['title'] ?? ''}',
      phaseId = j['phaseId']?.toString(),
      amount = _dn(j['amount']),
      date = _dt(j['date']);
}

class CumulativePoint {
  final DateTime date;
  final double? planned, actual;
  CumulativePoint(this.date, this.planned, this.actual);
}

class MonthSpend {
  final DateTime month;
  final Buckets spend;
  MonthSpend(this.month, this.spend);
}

class Supplier {
  final String name;
  final double amount;
  final int count;
  Supplier(this.name, this.amount, this.count);
}

class ProjectInsights {
  final String projectId, name, code, clientName, location, status;
  final DateTime? startDate, endDate;
  final int? totalDays, elapsedDays, daysLeft;
  final double? timeElapsedPct;
  final int activitiesDone, activitiesTotal;
  final double workDonePct;
  final double budgetTotal;
  final Map<CostCategory, ({double planned, double actual})> byCategory;
  final double actual, remaining, pendingApproval, paid, outstanding, income, dailyBurn;
  final double? spentPct;
  final int pendingCount;
  final double earnedValue;
  final double? plannedValue, cpi, spi, eac, vac;
  final int healthScore;
  final String healthStatus;
  final List<String> healthDrivers;
  final List<InsightPhase> phases;
  final Buckets unallocated;
  final List<MonthSpend> monthly;
  final List<CumulativePoint> cumulative;
  final List<CumulativePoint> forecast; // `actual` holds the forecast value
  final List<Supplier> suppliers;
  final List<InsightAlert> alerts;
  final BudgetBridge? bridge;

  ProjectInsights._({
    required this.projectId,
    required this.name,
    required this.code,
    required this.clientName,
    required this.location,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.elapsedDays,
    required this.daysLeft,
    required this.timeElapsedPct,
    required this.activitiesDone,
    required this.activitiesTotal,
    required this.workDonePct,
    required this.budgetTotal,
    required this.byCategory,
    required this.actual,
    required this.remaining,
    required this.pendingApproval,
    required this.paid,
    required this.outstanding,
    required this.income,
    required this.dailyBurn,
    required this.spentPct,
    required this.pendingCount,
    required this.earnedValue,
    required this.plannedValue,
    required this.cpi,
    required this.spi,
    required this.eac,
    required this.vac,
    required this.healthScore,
    required this.healthStatus,
    required this.healthDrivers,
    required this.phases,
    required this.unallocated,
    required this.monthly,
    required this.cumulative,
    required this.forecast,
    required this.suppliers,
    required this.alerts,
    required this.bridge,
  });

  factory ProjectInsights.fromJson(Map<String, dynamic> j) {
    final p = _m(j['project']);
    final s = _m(j['schedule']);
    final pr = _m(j['progress']);
    final b = _m(j['budget']);
    final sp = _m(j['spend']);
    final pf = _m(j['performance']);
    final h = _m(j['health']);
    final tl = _m(j['timeline']);
    final cats = _m(b['byCategory']);
    int? i(dynamic v) => v == null ? null : _d(v).toInt();
    return ProjectInsights._(
      projectId: '${p['id'] ?? ''}',
      name: '${p['name'] ?? ''}',
      code: '${p['code'] ?? ''}',
      clientName: '${p['clientName'] ?? ''}',
      location: '${p['location'] ?? ''}',
      status: '${p['status'] ?? ''}',
      startDate: _dt(s['startDate']),
      endDate: _dt(s['endDate']),
      totalDays: i(s['totalDays']),
      elapsedDays: i(s['elapsedDays']),
      daysLeft: i(s['daysLeft']),
      timeElapsedPct: _dn(s['timeElapsedPct']),
      activitiesDone: _d(pr['activitiesDone']).toInt(),
      activitiesTotal: _d(pr['activitiesTotal']).toInt(),
      workDonePct: _d(pr['workDonePct']),
      budgetTotal: _d(b['total']),
      byCategory: {
        for (final c in CostCategory.values)
          c: (planned: _d(_m(cats[c.key])['planned']), actual: _d(_m(cats[c.key])['actual'])),
      },
      actual: _d(sp['actual']),
      remaining: _d(sp['remaining']),
      pendingApproval: _d(sp['pendingApproval']),
      paid: _d(sp['paid']),
      outstanding: _d(sp['outstanding']),
      income: _d(sp['income']),
      dailyBurn: _d(sp['dailyBurn']),
      spentPct: _dn(sp['spentPct']),
      pendingCount: _d(sp['pendingCount']).toInt(),
      earnedValue: _d(pf['earnedValue']),
      plannedValue: _dn(pf['plannedValue']),
      cpi: _dn(pf['cpi']),
      spi: _dn(pf['spi']),
      eac: _dn(pf['eac']),
      vac: _dn(pf['vac']),
      healthScore: _d(h['score']).toInt(),
      healthStatus: '${h['status'] ?? 'on_track'}',
      healthDrivers: _l(h['drivers']).map((e) => '$e').toList(),
      phases: _l(j['phases']).whereType<Map<String, dynamic>>().map(InsightPhase.fromJson).toList(),
      unallocated: Buckets.fromJson(j['unallocated']),
      monthly: _l(tl['monthly']).whereType<Map<String, dynamic>>().map((m) {
        final parts = '${m['month']}'.split('-');
        final month = DateTime(int.tryParse(parts.first) ?? 2000, int.tryParse(parts.last) ?? 1);
        return MonthSpend(month, Buckets.fromJson(m));
      }).toList(),
      cumulative: _l(tl['cumulative'])
          .whereType<Map<String, dynamic>>()
          .where((c) => _dt(c['date']) != null)
          .map((c) => CumulativePoint(_dt(c['date'])!, _dn(c['planned']), _dn(c['actual'])))
          .toList(),
      forecast: _l(tl['forecast'])
          .whereType<Map<String, dynamic>>()
          .where((c) => _dt(c['date']) != null)
          .map((c) => CumulativePoint(_dt(c['date'])!, null, _dn(c['value'])))
          .toList(),
      suppliers: _l(j['suppliers'])
          .whereType<Map<String, dynamic>>()
          .map((x) => Supplier('${x['name']}', _d(x['amount']), _d(x['count']).toInt()))
          .toList(),
      alerts: _l(j['alerts']).whereType<Map<String, dynamic>>().map(InsightAlert.fromJson).toList(),
      bridge: j['bridge'] is Map<String, dynamic> ? BudgetBridge.fromJson(j['bridge']) : null,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SPEND BY TYPE — computed on the device from GET /transactions (works with
// the live server, which has no breakdown endpoint).
// ═════════════════════════════════════════════════════════════════════════════

/// One expense entry, reduced to what the breakdown needs. Parses both the
/// server's transaction JSON and the app's cached `EntryModel.toJson()` shape.
class SpendLine {
  final String id, projectId, name, unit, worker, contractor;
  final CostCategory category;
  final double amount, paid, quantity;
  final DateTime? date;
  final bool approved;
  final Map<String, dynamic> raw;

  const SpendLine({
    required this.id,
    required this.projectId,
    required this.name,
    required this.unit,
    required this.worker,
    required this.contractor,
    required this.category,
    required this.amount,
    required this.paid,
    required this.quantity,
    required this.date,
    required this.approved,
    required this.raw,
  });

  double get pending => math.max(0, amount - paid);

  static String _s(dynamic v) => v == null ? '' : '$v'.trim();

  /// Null for entries the breakdown ignores (income, rejected, no amount).
  static SpendLine? tryParse(Map<String, dynamic> j) {
    final type = _s(j['type']).toLowerCase();
    if (type == 'income' || type == 'revenue') return null;
    if (type == 'expense' && _s(j['category']) == 'Money Out') return null; // Home money-out record
    final approval = _s(j['approvalStatus']).toLowerCase();
    if (approval == 'rejected') return null;
    // Same type mapping as ProjectProvider (unknown types count as material).
    final cat = (type == 'labour' || type == 'wages')
        ? CostCategory.labour
        : (type == 'equipment' || type == 'expense')
        ? CostCategory.equipment
        : CostCategory.material;
    final qty = _d(j['quantity']);
    var amount = _d(j['amount']);
    if (amount <= 0) {
      final rate = _d(j['rate'] ?? j['ratePerUnit']);
      if (qty > 0 && rate > 0) amount = qty * rate;
    }
    if (amount <= 0) return null;
    final p = j['project'] ?? j['projectId'];
    final projectId = p is Map ? _s(p['_id'] ?? p['id']) : _s(p);
    final w = j['worker'];
    final worker = w is Map ? _s(w['name']) : _s(j['workerName']);
    var contractor = _s(j['contractor'] ?? j['contractorName']);
    if (contractor.isEmpty) contractor = cat == CostCategory.labour ? _s(j['category']) : _s(j['supplier']);
    if (contractor.isEmpty && cat == CostCategory.labour) contractor = _s(j['supplier']);
    var name = _s(j['title']);
    if (name.isEmpty) name = _s(j['materialName']);
    if (name.isEmpty) name = _s(j['description']);
    if (name.isEmpty) name = _s(j['name']);
    return SpendLine(
      id: _s(j['_id'] ?? j['id']),
      projectId: projectId,
      name: name,
      unit: _s(j['unit']),
      worker: worker,
      contractor: contractor,
      category: cat,
      amount: amount,
      paid: _d(j['paidAmount']).clamp(0, amount).toDouble(),
      quantity: qty,
      date: _dt(j['date']) ?? _dt(j['createdAt']),
      approved: approval == 'approved',
      raw: j,
    );
  }
}

/// A group of entries sharing a (normalised) name.
class SpendGroup {
  final String name;
  final List<SpendLine> lines;
  final double amount, paid, share;

  /// Total quantity + unit, only when every entry uses the same unit.
  final double? quantity;
  final String? unit;

  const SpendGroup({
    required this.name,
    required this.lines,
    required this.amount,
    required this.paid,
    required this.share,
    this.quantity,
    this.unit,
  });

  double get pending => math.max(0, amount - paid);
  int get count => lines.length;
  double? get avgRate => (quantity != null && quantity! > 0) ? amount / quantity! : null;
}

class SpendCategoryBreakdown {
  final CostCategory category;
  final double total, paid;
  final int count, awaitingApproval;

  /// By item name (labour type / material / equipment), largest first.
  final List<SpendGroup> byName;

  /// Labour only: by worker, else contractor / team.
  final List<SpendGroup> byPerson;

  const SpendCategoryBreakdown({
    required this.category,
    required this.total,
    required this.paid,
    required this.count,
    required this.awaitingApproval,
    required this.byName,
    required this.byPerson,
  });

  double get pending => math.max(0, total - paid);
}

class SpendBreakdown {
  final Map<CostCategory, SpendCategoryBreakdown> byCategory;
  const SpendBreakdown(this.byCategory);

  static String _key(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<SpendGroup> _group(List<SpendLine> lines, String Function(SpendLine) nameOf, double total, String fallback) {
    final buckets = <String, List<SpendLine>>{};
    final spellings = <String, Map<String, int>>{};
    for (final l in lines) {
      final raw = nameOf(l).trim().replaceAll(RegExp(r'\s+'), ' ');
      final k = raw.isEmpty ? '' : _key(raw);
      (buckets[k] ??= []).add(l);
      if (raw.isNotEmpty) {
        final m = spellings[k] ??= {};
        m[raw] = (m[raw] ?? 0) + 1;
      }
    }
    final out = <SpendGroup>[];
    buckets.forEach((k, ls) {
      var name = fallback;
      final sp = spellings[k];
      if (sp != null && sp.isNotEmpty) {
        name = sp.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      }
      var amount = 0.0, paid = 0.0, qty = 0.0;
      final units = <String>{};
      for (final l in ls) {
        amount += l.amount;
        paid += l.paid;
        qty += l.quantity;
        units.add(l.unit.toLowerCase());
      }
      final oneUnit = units.length == 1 && units.first.isNotEmpty && qty > 0;
      ls.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      out.add(SpendGroup(
        name: name,
        lines: ls,
        amount: amount,
        paid: paid,
        share: total > 0 ? amount / total : 0,
        quantity: oneUnit ? qty : null,
        unit: oneUnit ? ls.first.unit : null,
      ));
    });
    out.sort((a, b) => b.amount.compareTo(a.amount));
    return out;
  }

  /// [from] inclusive, [to] exclusive; null = open-ended.
  static SpendBreakdown compute(Iterable<SpendLine> all, {String? projectId, DateTime? from, DateTime? to}) {
    final per = {for (final c in CostCategory.values) c: <SpendLine>[]};
    for (final l in all) {
      if (projectId != null && l.projectId.isNotEmpty && l.projectId != projectId) continue;
      if (from != null || to != null) {
        final d = l.date;
        if (d == null) continue;
        if (from != null && d.isBefore(from)) continue;
        if (to != null && !d.isBefore(to)) continue;
      }
      per[l.category]!.add(l);
    }
    return SpendBreakdown({
      for (final c in CostCategory.values)
        c: () {
          final ls = per[c]!;
          var total = 0.0, paid = 0.0;
          var awaiting = 0;
          for (final l in ls) {
            total += l.amount;
            paid += l.paid;
            if (!l.approved) awaiting++;
          }
          return SpendCategoryBreakdown(
            category: c,
            total: total,
            paid: paid,
            count: ls.length,
            awaitingApproval: awaiting,
            byName: _group(ls, (l) => l.name, total, 'Unnamed'),
            byPerson: c == CostCategory.labour
                ? _group(ls, (l) => l.worker.isNotEmpty ? l.worker : l.contractor, total, 'Not recorded')
                : const [],
          );
        }(),
    });
  }
}
