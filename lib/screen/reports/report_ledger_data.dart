import 'dart:convert';

import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'save_helper_stub.dart'
    if (dart.library.html) 'save_helper_web.dart'
    if (dart.library.io) 'save_helper_mobile.dart';

/// Which side of the money the ledger shows.
enum LedgerDirection { inbound, outbound, all }

extension LedgerDirectionX on LedgerDirection {
  String get query => switch (this) {
        LedgerDirection.inbound => 'in',
        LedgerDirection.outbound => 'out',
        LedgerDirection.all => 'all',
      };
}

/// How rows are grouped (server `groupBy`).
enum LedgerGroupBy { none, category, project, month, payee }

extension LedgerGroupByX on LedgerGroupBy {
  String get query => name;
  String get label => switch (this) {
        LedgerGroupBy.none => 'None',
        LedgerGroupBy.category => 'Category',
        LedgerGroupBy.project => 'Project',
        LedgerGroupBy.month => 'Month',
        LedgerGroupBy.payee => 'Payee',
      };
}

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

  /// Categories that make sense for a view (Money in / Money out / All).
  static List<String> forDirection(LedgerDirection d) => switch (d) {
        LedgerDirection.inbound => keys.where(_inbound.contains).toList(),
        LedgerDirection.outbound => keys.where(_outbound.contains).toList(),
        LedgerDirection.all => keys,
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

  LedgerRow copyWith({String? category}) => LedgerRow(
        id: id,
        date: date,
        projectId: projectId,
        projectName: projectName,
        isIn: isIn,
        category: category ?? this.category,
        title: title,
        payee: payee,
        notes: notes,
        amount: amount,
        paymentStatus: paymentStatus,
        runningBalance: runningBalance,
        type: type,
        approvalStatus: approvalStatus,
      );

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

class LedgerGroup {
  LedgerGroup({required this.key, required this.label, required this.moneyIn, required this.moneyOut, required this.net, required this.count});
  final String key;
  final String label;
  final double moneyIn;
  final double moneyOut;
  final double net;
  final int count;

  factory LedgerGroup.fromJson(Map<String, dynamic> j) => LedgerGroup(
        key: _str(j['key']),
        label: _str(j['label']),
        moneyIn: _num(j['moneyIn']),
        moneyOut: _num(j['moneyOut']),
        net: _num(j['net']),
        count: _num(j['count']).round(),
      );
}

class LedgerResult {
  LedgerResult({required this.moneyIn, required this.moneyOut, required this.net, required this.count, required this.rows, required this.groups, required this.truncated});
  final double moneyIn;
  final double moneyOut;
  final double net;
  final int count;
  final List<LedgerRow> rows;
  final List<LedgerGroup> groups;
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
      groups: [
        for (final g in (j['groups'] as List? ?? const []))
          if (g is Map) LedgerGroup.fromJson(Map<String, dynamic>.from(g)),
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

/// Everything that picks which ledger rows are shown (also what exports use).
class LedgerQuery {
  const LedgerQuery({
    required this.projectId,
    this.from,
    this.to,
    this.direction = LedgerDirection.all,
    this.categories = const {},
    this.q = '',
    this.groupBy = LedgerGroupBy.none,
  });
  final String projectId; // id or 'all'
  final DateTime? from;
  final DateTime? to;
  final LedgerDirection direction;
  final Set<String> categories;
  final String q;
  final LedgerGroupBy groupBy;

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String toEndpoint() {
    final params = <String, String>{
      'projectId': projectId.isEmpty ? 'all' : projectId,
      if (from != null) 'from': ymd(from!),
      if (to != null) 'to': ymd(to!),
      'direction': direction.query,
      if (categories.isNotEmpty) 'category': (categories.toList()..sort()).join(','),
      if (q.trim().isNotEmpty) 'q': q.trim(),
      'groupBy': groupBy.query,
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
        throw LedgerFailure("Couldn't load the ledger (${res.statusCode}).");
      }
      final decoded = json.decode(res.body);
      if (decoded is! Map) throw const LedgerFailure("Couldn't read the ledger.");
      return LedgerResult.fromJson(Map<String, dynamic>.from(decoded));
    } on LedgerForbidden {
      rethrow;
    } on LedgerFailure {
      rethrow;
    } catch (_) {
      throw const LedgerFailure("Couldn't load the ledger. Check your connection and try again.");
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

/// Excel (CSV) and PDF of exactly the ledger on screen.
class LedgerExport {
  LedgerExport._();

  static const headers = ['Date', 'Project', 'Direction', 'Category', 'Title', 'Payee', 'Notes', 'Amount', 'Running balance'];

  static String _dmy(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _money(double v) => v.toStringAsFixed(2);

  /// Indian digit grouping for PDF text (the PDF font has no rupee sign).
  static String _rs(double v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final whole = parts[0];
    String grouped;
    if (whole.length <= 3) {
      grouped = whole;
    } else {
      final last3 = whole.substring(whole.length - 3);
      var rest = whole.substring(0, whole.length - 3);
      final chunks = <String>[];
      while (rest.length > 2) {
        chunks.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) chunks.insert(0, rest);
      grouped = '${chunks.join(',')},$last3';
    }
    return '${neg ? '-' : ''}Rs. $grouped.${parts[1]}';
  }

  /// Text cell safe from spreadsheet formula injection.
  static String _safe(String s) {
    if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) return "'$s";
    return s;
  }

  static String _cell(String s) => '"${s.replaceAll('"', '""')}"';

  static String toCsv(LedgerResult r) {
    final b = StringBuffer('﻿'); // BOM so Excel reads the rupee/UTF-8 text right
    b.writeln(headers.map(_cell).join(','));
    for (final row in r.rows) {
      b.writeln([
        _dmy(row.date),
        _safe(row.projectName),
        row.isIn ? 'In' : 'Out',
        LedgerCategories.label(row.category),
        _safe(row.title),
        _safe(row.payee),
        _safe(row.notes),
        _money(row.amount),
        row.runningBalance == null ? '' : _money(row.runningBalance!),
      ].map(_cell).join(','));
    }
    List<String> total(String label, double v) => ['', '', '', '', label, '', '', _money(v), ''];
    b.writeln(total('Total money in', r.moneyIn).map(_cell).join(','));
    b.writeln(total('Total money out', r.moneyOut).map(_cell).join(','));
    b.writeln(total('Net', r.net).map(_cell).join(','));
    return b.toString();
  }

  static Future<void> shareExcel(LedgerResult r) async {
    await saveAndShareCsv(
      csvContent: toCsv(r),
      filename: 'BuildTrack_Ledger_${DateTime.now().millisecondsSinceEpoch}.csv',
      shareText: 'BuildTrack money in / money out (${r.rows.length} entries)',
    );
  }

  static Future<void> sharePdf(LedgerResult r, {required String title, required String filterSummary}) async {
    final pdf = pw.Document();
    final data = [
      for (final row in r.rows)
        [
          _dmy(row.date),
          row.projectName,
          row.isIn ? 'In' : 'Out',
          LedgerCategories.label(row.category),
          row.title,
          row.payee,
          row.notes,
          _rs(row.amount),
          row.runningBalance == null ? '' : _rs(row.runningBalance!),
        ],
      ['', '', '', '', 'Total money in', '', '', _rs(r.moneyIn), ''],
      ['', '', '', '', 'Total money out', '', '', _rs(r.moneyOut), ''],
      ['', '', '', '', 'Net', '', '', _rs(r.net), ''],
    ];
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(filterSummary, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: headers,
            data: data,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF111317)),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.centerLeft,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(48),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FixedColumnWidth(30),
              3: const pw.FixedColumnWidth(62),
              4: const pw.FlexColumnWidth(2.4),
              5: const pw.FlexColumnWidth(1.6),
              6: const pw.FlexColumnWidth(2.2),
              7: const pw.FixedColumnWidth(70),
              8: const pw.FixedColumnWidth(70),
            },
          ),
        ],
      ),
    );
    final now = DateTime.now();
    await Printing.layoutPdf(
      name: 'BuildTrack_Ledger_${_dmy(now)}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
