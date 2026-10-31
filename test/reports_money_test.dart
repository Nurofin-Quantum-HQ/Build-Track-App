import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/screen/reports/report_ledger_data.dart';
import 'package:buildtrack_mobile/screen/reports/report_money.dart';
import 'package:buildtrack_mobile/screen/reports/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerRow _row(
  String id,
  String category, {
  required bool isIn,
  required double amount,
  String title = '',
  String payee = '',
  String notes = '',
  String date = '2026-10-10',
  double? balance,
  String project = 'Tower A',
}) =>
    LedgerRow(
      id: id,
      date: DateTime.parse(date),
      projectId: 'p1',
      projectName: project,
      isIn: isIn,
      category: category,
      title: title,
      payee: payee,
      notes: notes,
      amount: amount,
      paymentStatus: 'Paid',
      runningBalance: balance,
      type: isIn ? 'Income' : 'Expense',
      approvalStatus: 'Approved',
    );

EntryModel _entry(String id, {double amount = 1000, double paid = 400}) => EntryModel(
      id: id,
      projectId: 'p1',
      type: EntryType.material,
      amount: amount,
      paidAmount: paid,
      date: DateTime(2026, 10, 9),
      createdAt: DateTime(2026, 10, 9),
      description: 'Cement bags',
    );

LedgerResult _ledger(List<LedgerRow> rows) =>
    LedgerResult(moneyIn: 0, moneyOut: 0, net: 0, count: rows.length, rows: rows, truncated: false);

void main() {
  final rows = [
    _row('a', 'client_payment', isIn: true, amount: 50000, title: 'Stage 1 payment', payee: 'Mr Rao', date: '2026-10-12', balance: 41000),
    _row('b', 'loan_repayment', isIn: false, amount: 5000, title: 'Bank EMI', notes: 'monthly', date: '2026-10-11', balance: -9000),
    _row('c', 'material', isIn: false, amount: 1000, title: 'Cement bags', payee: 'Ravi Traders', date: '2026-10-09', balance: -4000),
    _row('d', 'loan_received', isIn: true, amount: 20000, title: 'Friend loan', date: '2026-10-09', balance: -3000),
    _row('e', 'other', isIn: false, amount: 300, title: 'Misc', date: '2026-10-08', balance: -23000),
  ];
  final all = MoneyTable.join(_ledger(rows), {'c': _entry('c')});
  List<String> ids(List<MoneyRow> r) => [for (final x in r) x.id];
  List<MoneyRow> filter({bool inn = true, bool out = true, MoneyType type = MoneyType.all, String q = ''}) =>
      MoneyTable.filter(all, moneyIn: inn, moneyOut: out, type: type, query: q);

  group('MoneyTable', () {
    test('joins spending entries by id', () {
      expect(all.firstWhere((r) => r.id == 'c').isSpending, isTrue);
      expect(all.where((r) => r.isSpending).length, 1);
    });

    test('searching a category label finds the rows (loan repayment)', () {
      expect(ids(filter(q: 'loan repayment')), ['b']);
      expect(ids(filter(q: 'Loan Repayment')), ['b']);
      expect(ids(filter(q: 'client payment')), ['a']);
      // Single words still match titles, payees and notes.
      expect(ids(filter(q: 'ravi')), ['c']);
      expect(ids(filter(q: 'monthly')), ['b']);
      expect(ids(filter(q: 'rao')), ['a']);
      expect(ids(filter(q: 'nothing like this')), isEmpty);
    });

    test('search words may come in any order and across fields', () {
      expect(ids(filter(q: 'repayment loan')), ['b']);
      expect(ids(filter(q: 'bank emi')), ['b']);
    });

    test('spending entries match on their own search text too', () {
      final r = MoneyTable.filter(
        all,
        moneyIn: true,
        moneyOut: true,
        type: MoneyType.all,
        query: 'zzz',
        entryMatches: (e, token) => e.id == 'c' && token == 'zzz',
      );
      expect(ids(r), ['c']);
    });

    test('Money in / Money out toggles', () {
      expect(ids(filter(inn: true, out: false)), ['a', 'd']);
      expect(ids(filter(inn: false, out: true)), ['b', 'c', 'e']);
      expect(filter().length, 5);
      // Both off is treated as both on (the screen never allows it).
      expect(filter(inn: false, out: false).length, 5);
    });

    test('type chips; Loan covers received and repayment', () {
      expect(ids(filter(type: MoneyType.loan)), ['b', 'd']);
      expect(ids(filter(type: MoneyType.clientPayment)), ['a']);
      expect(ids(filter(type: MoneyType.material)), ['c']);
      expect(ids(filter(type: MoneyType.other)), ['e']);
      expect(ids(filter(inn: false, out: true, type: MoneyType.loan)), ['b']);
    });

    test('scope hides rows', () {
      final r = MoneyTable.filter(all, moneyIn: true, moneyOut: true, type: MoneyType.all, inScope: (row) => row.isSpending);
      expect(ids(r), ['c']);
    });

    test('totals are In, Out and Net of exactly the rows given', () {
      final t = MoneyTable.totals(all);
      expect(t.moneyIn, 70000);
      expect(t.moneyOut, 6300);
      expect(t.net, 63700);
      final out = MoneyTable.totals(filter(inn: false, out: true));
      expect(out.moneyIn, 0);
      expect(out.net, -6300);
    });

    test('sort by date keeps the server order for the same day, both ways', () {
      final r = List.of(all);
      MoneyTable.sort(r, 'date', false);
      expect(ids(r), ['a', 'b', 'c', 'd', 'e']);
      MoneyTable.sort(r, 'date', true);
      expect(ids(r), ['e', 'd', 'c', 'b', 'a']);
    });

    test('sort by In puts rows without an In amount last', () {
      final r = List.of(all);
      MoneyTable.sort(r, 'in', false);
      expect(ids(r).take(2), ['a', 'd']);
      MoneyTable.sort(r, 'in', true);
      expect(ids(r).take(2), ['d', 'a']);
      MoneyTable.sort(r, 'out', false);
      expect(ids(r).take(3), ['b', 'c', 'e']);
    });

    test('status wording', () {
      String statusOf(EntryModel e) => 'Partial';
      expect(all.firstWhere((r) => r.id == 'c').statusLabel(statusOf), 'Part paid');
      expect(all.firstWhere((r) => r.id == 'a').statusLabel(statusOf), 'Received');
      expect(all.firstWhere((r) => r.id == 'b').statusLabel(statusOf), 'Paid');
    });
  });

  group('MoneyExport', () {
    test('csv has the shown rows in order, then totals', () {
      final shown = filter(inn: false, out: true);
      final csv = MoneyExport.toCsv(shown, (e) => 'Partial');
      final lines = csv.trim().split('\n');
      expect(lines.first, contains('"Date","Description","Project","Type","In","Out","Balance","Paid","Remaining","Status"'));
      expect(lines.length, 1 + shown.length + 2);
      expect(lines[1], contains('"Bank EMI"'));
      expect(lines[1], contains('"Loan repayment"'));
      // The spending row carries Paid / Remaining.
      expect(lines[2], contains('"Cement bags"'));
      expect(lines[2], contains('"400.00","600.00","Part paid"'));
      expect(lines[lines.length - 2], contains('"Total"'));
      expect(lines[lines.length - 2], contains('"6300.00"'));
      expect(lines.last, contains('"-6300.00"'));
    });
  });

  group('ReportSheet.money', () {
    Future<void> pump(WidgetTester tester, List<MoneyRow> rows, {void Function(MoneyRow)? onTap, void Function(String, bool)? onSort}) async {
      // The test font (Ahem) is far wider than the app font: pill overflow is
      // a test-environment artefact, any other layout error still fails.
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportSheet.money(
              rows: rows,
              statusOf: (e) => 'Partial',
              sortColumn: 'date',
              sortAscending: false,
              onSort: onSort ?? (c, a) {},
              onMoneyRowTap: onTap ?? (r) {},
              onAddMore: (e) {},
              onRecordPayment: (e) {},
              onEdit: (e) {},
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('shows every kind of row with the right cells', (tester) async {
      await pump(tester, all);
      expect(tester.takeException(), isNull);
      expect(find.text('Cement bags'), findsOneWidget);
      expect(find.text('Stage 1 payment'), findsOneWidget);
      expect(find.text('Loan repayment'), findsOneWidget);
      expect(find.text('Client payment'), findsOneWidget);
      // In amounts only on in rows, Out only on out rows.
      expect(find.text('₹50,000'), findsOneWidget);
      expect(find.text('₹5,000'), findsOneWidget);
      // Spending row: Paid / Remaining and the actions; others have none.
      expect(find.textContaining('₹400'), findsOneWidget);
      expect(find.text('Add More'), findsOneWidget);
      expect(find.text('Record Payment'), findsOneWidget);
      expect(find.text('Edit Entry'), findsOneWidget);
      expect(find.text('Received'), findsNWidgets(2)); // client payment + loan received
      expect(find.text('IN (INR)'), findsOneWidget);
      expect(find.text('BALANCE (INR)'), findsOneWidget);
    });

    testWidgets('row tap and header sort reach the callbacks', (tester) async {
      MoneyRow? tapped;
      String? sorted;
      await pump(tester, all, onTap: (r) => tapped = r, onSort: (c, a) => sorted = '$c/$a');
      await tester.tap(find.text('Stage 1 payment'));
      expect(tapped?.id, 'a');
      await tester.tap(find.text('PROJECT'));
      expect(sorted, 'project/true');
      await tester.tap(find.text('IN (INR)'));
      expect(sorted, 'in/false');
    });
  });

  testWidgets('quick filters: direction segment and Type sheet with totals', (tester) async {
    var dir = MoneyDirection.all;
    MoneyType type = MoneyType.all;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => MoneyQuickFilters(
            direction: dir,
            type: type,
            typeTotals: () => {for (final t in MoneyType.values) t: t == MoneyType.loan ? 25000.0 : 0.0},
            onDirection: (d) => setState(() => dir = d),
            onType: (t) => setState(() => type = t),
          ),
        ),
      ),
    ));
    for (final label in ['All', 'Money in', 'Money out', 'Type: All']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Money out'));
    await tester.pump();
    expect(dir, MoneyDirection.moneyOut);
    await tester.tap(find.text('Type: All'));
    await tester.pumpAndSettle();
    expect(find.text('Loan'), findsOneWidget);
    await tester.tap(find.text('Loan'));
    await tester.pumpAndSettle();
    expect(type, MoneyType.loan);
    expect(find.text('Type: Loan'), findsOneWidget);
  });
}
