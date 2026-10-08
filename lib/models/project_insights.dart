// Typed view of GET /api/projects/:id/insights (project insights screen).
// Mirrors core/backend/services/projectInsights.js.

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double? _dn(dynamic v) => v == null ? null : _d(v);
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
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
