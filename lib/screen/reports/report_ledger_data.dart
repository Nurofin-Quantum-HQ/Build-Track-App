import 'dart:convert';

import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';

/// The seven ledger categories the backend derives (and lets you change).
class LedgerCategories {
  LedgerCategories._();
  static const keys = <String>[
    'client_payment',
    'loan_received',
    'loan_repayment',
    'material',
    'labour',
    'equipment',
    'other',
  ];
  static const _labels = <String, String>{
    'client_payment': 'Client payment',
    'loan_received': 'Loan received',
    'loan_repayment': 'Loan repayment',
    'material': 'Material',
    'labour': 'Labour',
    'equipment': 'Equipment',
    'other': 'Other',
  };
  static const _inbound = {'client_payment', 'loan_received', 'other'};
  static const _outbound = {'loan_repayment', 'material', 'labour', 'equipment', 'other'};

  static String label(String key) => _labels[key] ?? (key.isEmpty ? 'Other' : key);

  /// Categories that make sense for a money-in or a money-out row.
  static List<String> forRow({required bool isIn}) => keys.where((isIn ? _inbound : _outbound).contains).toList();
}

/// The type chips of the finance table. "Loan" covers loan received and
/// loan repayment.
enum MoneyType { all, material, labour, equipment, clientPayment, loan, other }

extension MoneyTypeX on MoneyType {
  String get label => switch (this) {
        MoneyType.all => 'All',
        MoneyType.material => 'Material',
        MoneyType.labour => 'Labour',
        MoneyType.equipment => 'Equipment',
        MoneyType.clientPayment => 'Client payment',
        MoneyType.loan => 'Loan',
        MoneyType.other => 'Other',
      };

  bool matches(String category) => switch (this) {
        MoneyType.all => true,
        MoneyType.material => category == 'material',
        MoneyType.labour => category == 'labour',
        MoneyType.equipment => category == 'equipment',
        MoneyType.clientPayment => category == 'client_payment',
        MoneyType.loan => category == 'loan_received' || category == 'loan_repayment',
        MoneyType.other => category == 'other',
      };
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

String _str(dynamic v) => v?.toString().trim() ?? '';

/// Calendar day of an API date; "2026-10-05" or an ISO stamp. The day is read
/// from the text (not shifted by the phone's time zone).
DateTime? _day(dynamic v) {
  final s = _str(v);
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m != null) {
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }
  final d = DateTime.tryParse(s)?.toLocal();
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// One money movement from `GET /reports/ledger`. [id] is the transaction id.
class LedgerRow {
  LedgerRow({
    required this.id,
    required this.date,
    required this.projectId,
    required this.projectName,
    required this.isIn,
    required this.category,
    required this.title,
    required this.payee,
    required this.notes,
    required this.amount,
    required this.paymentStatus,
    required this.runningBalance,
    required this.type,
    required this.approvalStatus,
  });

  final String id;
  final DateTime? date;
  final String projectId;
  final String projectName;
  final bool isIn;
  final String category;
  final String title;
  final String payee;
  final String notes;
  final double amount;
  final String paymentStatus;
  final double? runningBalance;
  final String type;
  final String approvalStatus;

  factory LedgerRow.fromJson(Map<String, dynamic> j) => LedgerRow(
        id: _str(j['id'] ?? j['_id']),
        date: _day(j['date']),
        projectId: _str(j['projectId']),
        projectName: _str(j['projectName']),
        isIn: _str(j['direction']).toLowerCase() == 'in',
        category: _str(j['category']),
        title: _str(j['title']),
        payee: _str(j['payee']),
        notes: _str(j['notes']),
        amount: _num(j['amount']).abs(),
        paymentStatus: _str(j['paymentStatus']),
        runningBalance: j['runningBalance'] == null ? null : _num(j['runningBalance']),
        type: _str(j['type']),
        approvalStatus: _str(j['approvalStatus']),
      );
}

class LedgerResult {
  LedgerResult({required this.moneyIn, required this.moneyOut, required this.net, required this.count, required this.rows, required this.truncated});
  final double moneyIn;
  final double moneyOut;
  final double net;
  final int count;
  final List<LedgerRow> rows;

  /// The server cut the row list at its cap (newest rows kept). The summary
  /// still covers every matching entry.
  final bool truncated;

  factory LedgerResult.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] is Map) ? Map<String, dynamic>.from(j['summary'] as Map) : <String, dynamic>{};
    return LedgerResult(
      moneyIn: _num(s['moneyIn']),
      moneyOut: _num(s['moneyOut']),
      net: _num(s['net']),
      count: _num(s['count']).round(),
      rows: [
        for (final r in (j['rows'] as List? ?? const []))
          if (r is Map) LedgerRow.fromJson(Map<String, dynamic>.from(r)),
      ],
      truncated: j['truncated'] == true,
    );
  }
}

/// The signed-in user may not see finances (HTTP 403).
class LedgerForbidden implements Exception {
  const LedgerForbidden();
}

/// Any other failure; [message] is safe to show.
class LedgerFailure implements Exception {
  const LedgerFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Which ledger to fetch: project and period only. Direction, type and search
/// are applied on the phone (the server cannot search category labels), so the
/// running balance of every row always stays the true one.
class LedgerQuery {
  const LedgerQuery({required this.projectId, this.from, this.to});
  final String projectId; // id or 'all'
  final DateTime? from;
  final DateTime? to;

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Same value for the same project + period (used to know when to reload).
  String get key => '${projectId.isEmpty ? 'all' : projectId}|${from == null ? '' : ymd(from!)}|${to == null ? '' : ymd(to!)}';

  String toEndpoint() {
    final params = <String, String>{
      'projectId': projectId.isEmpty ? 'all' : projectId,
      if (from != null) 'from': ymd(from!),
      if (to != null) 'to': ymd(to!),
      'direction': 'all',
      'groupBy': 'none',
    };
    return '/reports/ledger?${Uri(queryParameters: params).query}';
  }
}

class LedgerApi {
  LedgerApi._();

  static Future<LedgerResult> fetch(LedgerQuery query) async {
    try {
      final res = await ApiService.get(query.toEndpoint());
      if (res.statusCode == 403) throw const LedgerForbidden();
      if (res.statusCode != 200) {
        throw LedgerFailure("Couldn't load the money entries (${res.statusCode}).");
      }
      final decoded = json.decode(res.body);
      if (decoded is! Map) throw const LedgerFailure("Couldn't read the money entries.");
      return LedgerResult.fromJson(Map<String, dynamic>.from(decoded));
    } on LedgerForbidden {
      rethrow;
    } on LedgerFailure {
      rethrow;
    } catch (_) {
      throw const LedgerFailure("Couldn't load the money entries. Check your connection and try again.");
    }
  }

  /// Changes only the ledger category of a transaction.
  static Future<void> setCategory(String transactionId, String category) async {
    try {
      final res = await ApiService.patch('/transactions/$transactionId/ledger-category', {'ledgerCategory': category});
      if (res.statusCode == 403) throw const LedgerForbidden();
      if (res.statusCode != 200) {
        throw LedgerFailure("Couldn't change the category (${res.statusCode}).");
      }
    } on LedgerForbidden {
      rethrow;
    } on LedgerFailure {
      rethrow;
    } catch (_) {
      throw const LedgerFailure("Couldn't change the category. Check your connection and try again.");
    }
  }
}

/// One row of the finance table: a ledger row, plus the spending entry with
/// the same id when it is one (ledger row id == transaction id == entry id).
/// Only spending rows have Paid / Remaining and the Add More / Record
/// Payment / Edit Entry actions.
class MoneyRow {
  const MoneyRow({required this.ledger, required this.seq, this.entry});
  final LedgerRow ledger;
  final EntryModel? entry;

  /// Position in the server's newest-first order (breaks ties between rows of
  /// the same day, so the running balance still reads top to bottom).
  final int seq;

  String get id => ledger.id;
  bool get isIn => ledger.isIn;
  bool get isSpending => entry != null;
  String get categoryLabel => LedgerCategories.label(ledger.category);

  /// A money row that is not a spending entry and still waits for approval.
  bool get waitsForApproval => !isSpending && ledger.approvalStatus.toLowerCase() == 'pending';

  /// The Status column's wording (what the pill says, and what exports write).
  /// [statusOf] gives a spending entry's 'Fully Paid' / 'Partial' / 'Not Paid'.
  /// Other money was simply received / paid, unless it waits for approval.
  String statusLabel(String Function(EntryModel) statusOf) {
    final e = entry;
    if (e != null) {
      return switch (statusOf(e)) {
        'Fully Paid' => 'Paid',
        'Partial' => 'Part paid',
        _ => 'Not paid',
      };
    }
    if (waitsForApproval) return 'Pending';
    return isIn ? 'Received' : 'Paid';
  }

  /// What the Description column shows.
  String get description {
    final e = entry;
    if (e != null && e.description.trim().isNotEmpty) return e.description.trim();
    if (ledger.title.isNotEmpty) return ledger.title;
    return categoryLabel;
  }
}

/// Everything the finance table does with rows, without any widgets:
/// join, filter, search, sort and totals.
class MoneyTable {
  MoneyTable._();

  /// Ledger rows, each joined to its spending entry (by id) when there is one.
  static List<MoneyRow> join(LedgerResult ledger, Map<String, EntryModel> entriesById) => [
        for (var i = 0; i < ledger.rows.length; i++)
          MoneyRow(ledger: ledger.rows[i], seq: i, entry: entriesById[ledger.rows[i].id]),
      ];

  static final Expando<String> _haystacks = Expando<String>();

  /// Lower-cased searchable text of a ledger row: title, payee, notes, the
  /// category label, project, amount and dates.
  static String _haystack(LedgerRow r) {
    final cached = _haystacks[r];
    if (cached != null) return cached;
    final parts = <String>[
      r.title,
      r.payee,
      r.notes,
      LedgerCategories.label(r.category),
      r.projectName,
      r.amount.toStringAsFixed(2),
      r.amount.round().toString(),
      formatInr(r.amount),
      if (r.date != null) formatShortDate(r.date),
      if (r.date != null) formatDate(r.date),
    ];
    return _haystacks[r] = parts.where((p) => p.trim().isNotEmpty).join('\u0001').toLowerCase();
  }

  /// Every word typed must be found in the row (the whole phrase also counts):
  /// "loan repayment" finds loan repayments, "ravi cement" finds Ravi's cement.
  /// Spending rows can also match on everything the entries search covers
  /// ([entryMatches]).
  static bool matches(MoneyRow row, String rawQuery, {bool Function(EntryModel entry, String token)? entryMatches}) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return true;
    final hay = _haystack(row.ledger);
    bool token(String t) {
      if (hay.contains(t)) return true;
      final e = row.entry;
      return e != null && entryMatches != null && entryMatches(e, t);
    }

    if (token(query)) return true;
    final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length > 1 && words.every(token);
  }

  /// Rows that pass the Money in / Money out toggles, the type chip and the
  /// search. [inScope] applies the project / floor / phase / status filters.
  /// Both toggles off counts as both on.
  static List<MoneyRow> filter(
    List<MoneyRow> rows, {
    required bool moneyIn,
    required bool moneyOut,
    required MoneyType type,
    String query = '',
    bool Function(MoneyRow row)? inScope,
    bool Function(EntryModel entry, String token)? entryMatches,
  }) {
    final both = moneyIn == moneyOut;
    return [
      for (final r in rows)
        if ((both || (r.isIn ? moneyIn : moneyOut)) &&
            type.matches(r.ledger.category) &&
            (inScope == null || inScope(r)) &&
            matches(r, query, entryMatches: entryMatches))
          r,
    ];
  }

  /// Sorts [rows] in place. Keys: 'date' (default), 'title', 'project',
  /// 'type', 'in', 'out', 'amount'. Same-day rows keep the server's order, so
  /// the running balance reads top to bottom either way.
  static void sort(List<MoneyRow> rows, String column, bool ascending) {
    int byDate(MoneyRow a, MoneyRow b) {
      final da = a.ledger.date;
      final db = b.ledger.date;
      var c = (da == null || db == null) ? (da == null ? (db == null ? 0 : -1) : 1) : da.compareTo(db);
      if (c == 0) c = b.seq.compareTo(a.seq); // older rows have the higher seq
      return c;
    }

    int newestFirst(MoneyRow a, MoneyRow b) => byDate(b, a);

    int compare(MoneyRow a, MoneyRow b) {
      switch (column) {
        case 'title':
          final c = a.description.toLowerCase().compareTo(b.description.toLowerCase());
          return c != 0 ? (ascending ? c : -c) : newestFirst(a, b);
        case 'project':
          final c = a.ledger.projectName.toLowerCase().compareTo(b.ledger.projectName.toLowerCase());
          return c != 0 ? (ascending ? c : -c) : newestFirst(a, b);
        case 'type':
          final c = a.categoryLabel.compareTo(b.categoryLabel);
          return c != 0 ? (ascending ? c : -c) : newestFirst(a, b);
        case 'in':
        case 'out':
          final side = column == 'in';
          final aHas = a.isIn == side;
          final bHas = b.isIn == side;
          // Rows of the other side have no value in this column: always last.
          if (aHas != bHas) return aHas ? -1 : 1;
          if (!aHas) return newestFirst(a, b);
          final c = a.ledger.amount.compareTo(b.ledger.amount);
          return c != 0 ? (ascending ? c : -c) : newestFirst(a, b);
        case 'amount':
          final c = a.ledger.amount.compareTo(b.ledger.amount);
          return c != 0 ? (ascending ? c : -c) : newestFirst(a, b);
        default:
          return ascending ? byDate(a, b) : newestFirst(a, b);
      }
    }

    rows.sort(compare);
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// In, Out and Net of exactly [rows].
  static ({double moneyIn, double moneyOut, double net}) totals(Iterable<MoneyRow> rows) {
    var inn = 0.0;
    var out = 0.0;
    for (final r in rows) {
      if (r.isIn) {
        inn += r.ledger.amount;
      } else {
        out += r.ledger.amount;
      }
    }
    return (moneyIn: _round2(inn), moneyOut: _round2(out), net: _round2(inn - out));
  }
}
