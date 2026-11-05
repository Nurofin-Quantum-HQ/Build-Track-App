import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/screen/reports/report_ledger_data.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'save_helper_stub.dart'
    if (dart.library.html) 'save_helper_web.dart'
    if (dart.library.io) 'save_helper_mobile.dart';

enum MoneyDirection { all, moneyIn, moneyOut }

extension MoneyDirectionX on MoneyDirection {
  static MoneyDirection of({required bool moneyIn, required bool moneyOut}) =>
      moneyIn && moneyOut ? MoneyDirection.all : (moneyIn ? MoneyDirection.moneyIn : MoneyDirection.moneyOut);
}

/// Two fixed rows, nothing scrolls sideways: All · Money in · Money out, then
/// a Type picker (a sheet with each type's total) and Record payment.
class MoneyQuickFilters extends StatelessWidget {
  const MoneyQuickFilters({
    super.key,
    required this.direction,
    required this.type,
    required this.typeTotals,
    required this.onDirection,
    required this.onType,
    this.onRecordPayment,
  });
  final MoneyDirection direction;
  final MoneyType type;
  final Map<MoneyType, double> Function() typeTotals;
  final ValueChanged<MoneyDirection> onDirection;
  final ValueChanged<MoneyType> onType;
  final VoidCallback? onRecordPayment;

  Future<void> _pickType(BuildContext context) async {
    final totals = typeTotals();
    final picked = await showBtSheet<MoneyType>(
      context,
      title: 'Type',
      subtitle: 'Totals follow the project, dates and search you have on.',
      builder: (sheetCtx) => BtGroup(
        children: [
          for (final t in MoneyType.values)
            BtRow(
              title: t == MoneyType.all ? 'All types' : t.label,
              minHeight: 48,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatInr(totals[t] ?? 0), style: BtText.subhead(sheetCtx)),
                SizedBox(
                  width: 28,
                  child: t == type ? Icon(Icons.check_rounded, color: sheetCtx.bt.accentInk, size: 20) : null,
                ),
              ]),
              onTap: () => Navigator.pop(sheetCtx, t),
            ),
        ],
      ),
    );
    if (picked != null) onType(picked);
  }

  @override
  Widget build(BuildContext context) {
    final typeOn = type != MoneyType.all;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BtSegmented<MoneyDirection>(
        segments: const {
          MoneyDirection.all: 'All',
          MoneyDirection.moneyIn: 'Money in',
          MoneyDirection.moneyOut: 'Money out',
        },
        value: direction,
        onChanged: onDirection,
      ),
      const SizedBox(height: 10),
      Row(children: [
        Semantics(
          button: true,
          label: 'Type: ${type.label}',
          child: BtChip(
            label: 'Type: ${type.label}',
            icon: Icons.expand_more_rounded,
            selected: typeOn,
            onTap: () => _pickType(context),
          ),
        ),
        if (typeOn) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Clear type',
            icon: Icon(Icons.close_rounded, size: 18, color: Bt.ink2),
            onPressed: () => onType(MoneyType.all),
          ),
        ],
        const Spacer(),
        if (onRecordPayment != null)
          BtChip(label: 'Payment', icon: Icons.add_rounded, selected: true, onTap: onRecordPayment),
      ]),
    ]);
  }
}

/// Details of a money row that is not a spending entry (client payment, loan,
/// other money out), with "Change category". [onChanged] runs after the
/// category was saved, so the table can reload.
void showMoneyRowDetails(BuildContext context, MoneyRow row, {required Future<void> Function() onChanged}) {
  final r = row.ledger;
  showBtSheet(
    context,
    title: row.description,
    subtitle: row.categoryLabel,
    builder: (sheetCtx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtGroup(
          children: [
            BtValueRow(
              label: r.isIn ? 'Money in' : 'Money out',
              value: '${r.isIn ? '+' : '−'}${formatInr(r.amount)}',
              valueColor: r.isIn ? Bt.green : Bt.ink,
            ),
            BtValueRow(label: 'Date', value: formatDate(r.date)),
            if (r.projectName.isNotEmpty) BtValueRow(label: 'Project', value: r.projectName),
            if (r.payee.isNotEmpty) BtValueRow(label: 'Payee', value: r.payee),
            if (r.notes.isNotEmpty) BtValueRow(label: 'Notes', value: r.notes),
            if (r.runningBalance != null) BtValueRow(label: 'Balance after', value: formatInr(r.runningBalance)),
          ],
        ),
        const SizedBox(height: 16),
        BtButton(
          label: 'Change category',
          icon: Icons.sell_outlined,
          onPressed: () {
            Navigator.pop(sheetCtx);
            _changeCategory(context, row, onChanged);
          },
        ),
      ],
    ),
  );
}

Future<void> _changeCategory(BuildContext context, MoneyRow row, Future<void> Function() onChanged) async {
  final r = row.ledger;
  final picked = await showBtSheet<String>(
    context,
    title: 'Change category',
    subtitle: 'Only the category changes. The amount and entry stay as they are.',
    builder: (sheetCtx) => BtGroup(
      children: [
        for (final k in LedgerCategories.forRow(isIn: r.isIn))
          BtRow(
            title: LedgerCategories.label(k),
            minHeight: 48,
            trailing: k == r.category ? Icon(Icons.check_rounded, color: sheetCtx.bt.accentInk, size: 20) : null,
            onTap: () => Navigator.pop(sheetCtx, k),
          ),
      ],
    ),
  );
  if (picked == null || picked == r.category || !context.mounted) return;
  try {
    await LedgerApi.setCategory(r.id, picked);
    if (!context.mounted) return;
    btToast(context, 'Moved to ${LedgerCategories.label(picked)}.');
    await onChanged();
  } on LedgerForbidden {
    if (context.mounted) btToast(context, "You don't have access to change this.", error: true);
  } on LedgerFailure catch (e) {
    if (context.mounted) btToast(context, e.message, error: true);
  }
}

/// CSV (Excel) and PDF of exactly the finance table on screen: the filtered
/// rows in the table's order, then In / Out / Net totals.
class MoneyExport {
  MoneyExport._();

  static const headers = ['Date', 'Description', 'Project', 'Type', 'In', 'Out', 'Balance', 'Paid', 'Remaining', 'Status'];

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

  /// The table's cells for one row; [money] formats the amounts.
  static List<String> _cells(MoneyRow m, String Function(EntryModel) statusOf, String Function(double) money, {bool plain = false}) {
    final l = m.ledger;
    final e = m.entry;
    String text(String s) => plain ? s : _safe(s);
    return [
      _dmy(l.date),
      text(m.description),
      text(l.projectName),
      m.categoryLabel,
      m.isIn ? money(l.amount) : '',
      m.isIn ? '' : money(l.amount),
      l.runningBalance == null ? '' : money(l.runningBalance!),
      e == null ? '' : money(e.paidAmount),
      e == null ? '' : money(e.remainingAmount),
      m.statusLabel(statusOf),
    ];
  }


  /// The totals under the rows: In and Out of the shown rows, then their Net
  /// (in the Balance column, which is where the money left over reads).
  static List<List<String>> _totalRows(({double moneyIn, double moneyOut, double net}) t, String Function(double) money) => [
        ['', 'Total', '', '', money(t.moneyIn), money(t.moneyOut), '', '', '', ''],
        ['', 'Net (In - Out)', '', '', '', '', money(t.net), '', '', ''],
      ];

  static String toCsv(List<MoneyRow> rows, String Function(EntryModel) statusOf) {
    final t = MoneyTable.totals(rows);
    final b = StringBuffer('﻿'); // BOM so Excel reads the rupee/UTF-8 text right
    b.writeln(headers.map(_cell).join(','));
    for (final m in rows) {
      b.writeln(_cells(m, statusOf, _money).map(_cell).join(','));
    }
    b.writeln(_totalRows(t, _money).expand((r) => [r.map(_cell).join(',')]).join('\n'));
    return b.toString();
  }

  static Future<void> shareCsv(List<MoneyRow> rows, String Function(EntryModel) statusOf) async {
    await saveAndShareCsv(
      csvContent: toCsv(rows, statusOf),
      filename: 'BuildTrack_Report_${DateTime.now().millisecondsSinceEpoch}.csv',
      shareText: 'BuildTrack report (${rows.length} rows)',
    );
  }

  static Future<void> sharePdf(List<MoneyRow> rows, String Function(EntryModel) statusOf, {required String title, required String filterSummary}) async {
    final t = MoneyTable.totals(rows);
    final pdf = pw.Document();
    final data = [
      for (final m in rows) _cells(m, statusOf, _rs, plain: true),
      ..._totalRows(t, _rs),
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
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
              9: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(44),
              1: const pw.FlexColumnWidth(2.6),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FixedColumnWidth(62),
              4: const pw.FixedColumnWidth(62),
              5: const pw.FixedColumnWidth(62),
              6: const pw.FixedColumnWidth(66),
              7: const pw.FixedColumnWidth(58),
              8: const pw.FixedColumnWidth(58),
              9: const pw.FixedColumnWidth(44),
            },
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name: 'BuildTrack_Report_${_dmy(DateTime.now())}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
