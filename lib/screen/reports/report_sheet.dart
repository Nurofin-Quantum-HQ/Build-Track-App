import 'package:buildtrack_mobile/common/utils/date_parse.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/screen/reports/report_ledger_data.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Grid colours from the V2 "Report table" board (ink at 8 % / 14 % / 5 % / 2.2 %).
const _line = Color(0x14111317);
const _line2 = Color(0x24111317);
const _headBg = Color(0xFFF3F3F3);
const _zebra = Color(0xFFFAFAFA);

/// Excel-style sheet of report entries, shown at the top of the Reports tab
/// (and full screen). The item column (with row numbers) stays pinned on the
/// left and the header row stays on top; everything else scrolls sideways,
/// and up/down inside the sheet once the rows outgrow [maxHeight].
///
/// [ReportSheet.money] is the same sheet for people who can see finances: one
/// row per money movement (spending entries plus client payments, loans…).
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.entries,
    required this.columns,
    required this.projectNameOf,
    required this.statusOf,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onRowTap,
    required this.onAddMore,
    required this.onRecordPayment,
    required this.onEdit,
    this.maxHeight = 420,
    this.firstRowNumber = 1,
    this.pinnedWidth = 132,
    this.tourWrap,
    this.pinnedColumn,
    this.onPinColumn,
  }) : moneyRows = null, onMoneyRowTap = null;

  /// The finance table: [rows] are every money movement, spending entries
  /// included (those keep Paid / Remaining and the row actions). Columns are
  /// fixed ([moneyColumns]); the Description column is pinned.
  const ReportSheet.money({
    super.key,
    required List<MoneyRow> rows,
    required this.statusOf,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onMoneyRowTap,
    required this.onAddMore,
    required this.onRecordPayment,
    required this.onEdit,
    this.maxHeight = 420,
    this.firstRowNumber = 1,
    this.pinnedWidth = 132,
    this.tourWrap,
  })  : moneyRows = rows,
        entries = const [],
        columns = moneyColumns,
        projectNameOf = _noProjectName,
        pinnedColumn = 'Description',
        onPinColumn = null,
        onRowTap = _ignoreRowTap;

  static String _noProjectName(EntryModel e) => '';
  static void _ignoreRowTap(EntryModel e) {}

  /// Finance table columns, in the user-facing order (Description is pinned,
  /// so it shows first on screen).
  static const moneyColumns = ['Description', 'Date', 'Project', 'Type', 'In', 'Out', 'Balance', 'Paid / Remaining', 'Status'];

  /// Rows of the finance table; null for the plain entries sheet.
  final List<MoneyRow>? moneyRows;
  final void Function(MoneyRow)? onMoneyRowTap;

  /// The column frozen on the left (chosen in Edit columns or by
  /// long-pressing a header). Ignored when it isn't one of [columns]; then the
  /// item column (Description / Material / …) is pinned, else the first one.
  final String? pinnedColumn;

  /// Long-pressing a scrolling header pins that column. Null: no long-press.
  final ValueChanged<String>? onPinColumn;

  /// Lets the screen wrap the header row ('header') and the scroll hint
  /// ('footer') in guided-tour steps. Identity when null.
  final Widget Function(String part, Widget child)? tourWrap;

  final List<EntryModel> entries;

  /// The tab's active columns, in the user's order (see "Edit columns").
  final List<String> columns;
  final String Function(EntryModel) projectNameOf;

  /// 'Fully Paid', 'Partial' or 'Not Paid'.
  final String Function(EntryModel) statusOf;

  /// 'date' (purchase date), 'paymentDate', 'project' or 'amount'.
  final String sortColumn;
  final bool sortAscending;
  final void Function(String sortColumn, bool ascending) onSort;
  final void Function(EntryModel) onRowTap;
  final void Function(EntryModel) onAddMore;
  final void Function(EntryModel) onRecordPayment;
  final void Function(EntryModel) onEdit;

  /// Height of the whole sheet (header + rows); fewer rows shrink it.
  final double maxHeight;

  /// Number shown in the # column for the first row (continues across pages).
  final int firstRowNumber;
  final double pinnedWidth;

  static const rowHeight = 40.0;
  static const headerHeight = 36.0;

  /// Height of the hint + scroll track under the sheet.
  static const footerHeight = 28.0;

  static const itemColumns = {'Description', 'Material', 'Worker Type', 'Equipment'};
  static const _actionColumns = ['Add More', 'Record Payment', 'Edit Entry'];
  static const _sortKeys = {'Purchased Date': 'date', 'Payment Date': 'paymentDate', 'Project': 'project', 'Amount': 'amount'};
  static const _moneySortKeys = {'Date': 'date', 'Description': 'title', 'Project': 'project', 'Type': 'type', 'In': 'in', 'Out': 'out'};

  /// The column that is pinned for [columns] with the user's choice [pinned]:
  /// that choice when it is shown, else the item column, else the first.
  static String? pinnedOf(List<String> columns, String? pinned) {
    if (pinned != null && columns.contains(pinned)) return pinned;
    for (final c in columns) {
      if (itemColumns.contains(c)) return c;
    }
    return columns.isEmpty ? null : columns.first;
  }

  /// [columns] in on-screen order: the pinned one first, the rest as saved.
  /// Exports use this too, so a file has the same column order as the sheet.
  static List<String> displayOrder(List<String> columns, String? pinned) {
    final p = pinnedOf(columns, pinned);
    if (p == null) return List.of(columns);
    return [p, ...columns.where((c) => c != p)];
  }

  /// Date of the latest payment made on [e], or null when nothing is paid.
  /// Taken from the payment history (the newest dated payment) and the
  /// entry's own paymentDate, whichever is later — the old server only
  /// refreshes paymentDate on some update paths.
  static DateTime? paymentDateOf(EntryModel e) {
    final cached = _paymentDateCache[e];
    if (cached != null) return cached.$1;
    final d = _latestPaymentDate(e);
    _paymentDateCache[e] = (d,);
    return d;
  }

  /// Entries are rebuilt on every reload, so caching per object is safe.
  static final Expando<(DateTime?,)> _paymentDateCache = Expando();

  static DateTime? _latestPaymentDate(EntryModel e) {
    final hasPayment = e.paidAmount > 0 ||
        e.paymentHistory.any((p) => (num.tryParse('${p['amount'] ?? ''}') ?? 0) > 0);
    if (!hasPayment) return null;
    DateTime? latest = e.paymentDate;
    for (final p in e.paymentHistory) {
      final d = parseFlexibleDate(p['date'] ?? p['paymentDate']);
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    return latest;
  }

  static const _numeric = {
    'Amount', 'Paid', 'Remaining', 'Rate', 'Rate/Day', 'Rent Rate', 'Qty', 'Days', 'Duration', 'In', 'Out', 'Balance',
  };

  static const _moneyWidths = {
    'Date': 104.0,
    'Project': 132.0,
    'Type': 138.0,
    'In': 112.0,
    'Out': 112.0,
    'Balance': 124.0,
    'Paid / Remaining': 184.0,
    'Status': 104.0,
  };

  static double widthOf(String column) {
    switch (column) {
      case 'Purchased Date':
      case 'Payment Date':
        return 116;
      case 'Project':
        return 132;
      case 'Type':
        return 108;
      case 'Description':
      case 'Material':
      case 'Worker Type':
      case 'Equipment':
        return 156;
      case 'Brand':
        return 108;
      case 'Floor':
        return 92;
      case 'Phase':
      case 'Activity':
        return 128;
      case 'Unit':
        return 68;
      case 'Status':
        return 100;
      case 'Amount':
        return 124;
      case 'Paid':
        return 108;
      case 'Remaining':
        return 132;
      case 'Rate':
      case 'Rate/Day':
      case 'Rent Rate':
        return 96;
      case 'Qty':
      case 'Days':
      case 'Duration':
        return 76;
      case 'Add More':
        return 112;
      case 'Record Payment':
        return 150;
      case 'Edit Entry':
        return 112;
      default:
        return 112;
    }
  }

  static String labelOf(String column) {
    switch (column) {
      case 'Purchased Date':
        return 'PURCHASE DATE';
      case 'Amount':
        return 'AMOUNT (INR)';
      case 'Paid':
        return 'PAID (INR)';
      case 'Remaining':
        return 'REMAINING (INR)';
      case 'In':
      case 'Out':
      case 'Balance':
      case 'Paid / Remaining':
        return '${column.toUpperCase()} (INR)';
      default:
        return column.toUpperCase();
    }
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

/// One sheet row: a plain entry, or a finance-table row ([money], with its
/// spending [entry] when it is one).
class _SheetRow {
  const _SheetRow(this.id, this.entry, this.money);
  final String id;
  final EntryModel? entry;
  final MoneyRow? money;
}

/// Text styles resolved once per build (not per cell).
class _Styles {
  _Styles(BuildContext context, BtTheme bt)
      : cell = BtText.caption(context, color: Bt.ink).copyWith(fontSize: 12.5, height: 1.2),
        head = BtText.mono(context, size: 9.5, color: Bt.ink2),
        rowNo = BtText.mono(context, size: 10, color: Bt.ink3).copyWith(letterSpacing: 0, fontFeatures: BtText.tnum),
        pill = BtText.caption(context, weight: FontWeight.w600).copyWith(fontSize: 11, height: 1.1),
        action = BtText.caption(context, weight: FontWeight.w600).copyWith(fontSize: 11.5, height: 1.1),
        accentInk = bt.accentInk,
        selected = Color.alphaBlend(bt.accent.withValues(alpha: .14), Bt.card),
        accent = bt.accent;
  final TextStyle cell;
  final TextStyle head;
  final TextStyle rowNo;
  final TextStyle pill;
  final TextStyle action;
  final Color accentInk;
  final Color selected;
  final Color accent;
}

class _ReportSheetState extends State<ReportSheet> {
  final _hHead = ScrollController();
  final _hBody = ScrollController();
  final _vPin = ScrollController();
  final _vBody = ScrollController();
  bool _syncing = false;

  /// Last row the user opened — highlighted like a selected spreadsheet row.
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _hBody.addListener(() => _follow(_hBody, _hHead));
    _hHead.addListener(() => _follow(_hHead, _hBody));
    _vBody.addListener(() => _follow(_vBody, _vPin));
    _vPin.addListener(() => _follow(_vPin, _vBody));
  }

  @override
  void didUpdateWidget(ReportSheet old) {
    super.didUpdateWidget(old);
    // Different rows (page, search, sort) go back to the top; different
    // columns (tab, Edit columns) go back to the left. Plain rebuilds keep
    // the reader where they were.
    final oldIds = _idsOf(old);
    final newIds = _idsOf(widget);
    final rowsChanged = oldIds.length != newIds.length || Iterable.generate(newIds.length).any((i) => oldIds[i] != newIds[i]);
    final colsChanged = old.columns.join('|') != widget.columns.join('|');
    if (!rowsChanged && !colsChanged) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final c in [if (rowsChanged) ...[_vPin, _vBody], if (colsChanged) ...[_hHead, _hBody]]) {
        if (c.hasClients) c.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_hHead, _hBody, _vPin, _vBody]) {
      c.dispose();
    }
    super.dispose();
  }

  void _follow(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if ((to.offset - target).abs() < .5) return;
    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  static List<String> _idsOf(ReportSheet w) => w.moneyRows != null ? [for (final m in w.moneyRows!) m.id] : [for (final e in w.entries) e.id];

  bool get _isMoney => widget.moneyRows != null;

  List<_SheetRow> get _rows => _isMoney
      ? [for (final m in widget.moneyRows!) _SheetRow(m.id, m.entry, m)]
      : [for (final e in widget.entries) _SheetRow(e.id, e, null)];

  double _widthOf(String column) => (_isMoney ? ReportSheet._moneyWidths[column] : null) ?? ReportSheet.widthOf(column);

  String? get _pinned => ReportSheet.pinnedOf(widget.columns, widget.pinnedColumn);

  List<String> get _scrollColumns {
    final pinned = _pinned;
    return [...widget.columns.where((c) => c != pinned), ...ReportSheet._actionColumns];
  }

  void _tapRow(_SheetRow r) {
    if (_selectedId != r.id) setState(() => _selectedId = r.id);
    if (r.money != null) {
      widget.onMoneyRowTap?.call(r.money!);
    } else {
      widget.onRowTap(r.entry!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final s = _Styles(context, bt);
    final rows = _rows;
    final pinned = _pinned;
    final pinW = widget.pinnedWidth;
    final scrollCols = _scrollColumns;
    final scrollWidth = scrollCols.fold<double>(0, (w, c) => w + _widthOf(c));
    final maxBody = (widget.maxHeight - ReportSheet.headerHeight).clamp(ReportSheet.rowHeight, double.infinity);
    final bodyHeight = (rows.length * ReportSheet.rowHeight).clamp(ReportSheet.rowHeight, maxBody).toDouble();
    final innerScroll = rows.length * ReportSheet.rowHeight > bodyHeight + .5;
    final vPhysics = innerScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics();
    Widget wrap(String part, Widget child) => widget.tourWrap?.call(part, child) ?? child;

    return ScrollConfiguration(
      // Let mouse and trackpad drag the sheet too (web / desktop).
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
        scrollbars: false,
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final overflows = scrollWidth > constraints.maxWidth - (pinned == null ? 0 : pinW);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(16), boxShadow: Bt.shadow),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: ReportSheet.headerHeight + bodyHeight,
                  child: Stack(children: [
                    Positioned.fill(
                      left: pinned == null ? 0 : pinW,
                      child: Column(children: [
                        wrap('header', SingleChildScrollView(
                          controller: _hHead,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Container(
                            height: ReportSheet.headerHeight,
                            decoration: const BoxDecoration(color: _headBg, border: Border(bottom: BorderSide(color: _line2))),
                            child: Row(children: [for (final c in scrollCols) _headerCell(c, _widthOf(c), s)]),
                          ),
                        )),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _hBody,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: scrollWidth,
                              child: ListView.builder(
                                controller: _vBody,
                                physics: vPhysics,
                                padding: EdgeInsets.zero,
                                itemExtent: ReportSheet.rowHeight,
                                itemCount: rows.length,
                                itemBuilder: (context, i) => _bodyRow(rows[i], scrollCols, i, s),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    if (overflows)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 26,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _hBody,
                            builder: (context, child) {
                              final atEnd = _hBody.hasClients &&
                                  _hBody.position.hasContentDimensions &&
                                  _hBody.offset >= _hBody.position.maxScrollExtent - 1;
                              return AnimatedOpacity(opacity: atEnd ? 0 : 1, duration: Bt.fast, child: child);
                            },
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Color(0x00FFFFFF), Bt.card]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (pinned != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: pinW,
                        child: AnimatedBuilder(
                          animation: _hBody,
                          builder: (context, child) {
                            final lifted = _hBody.hasClients && _hBody.offset > 1;
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: Bt.card,
                                border: const Border(right: BorderSide(color: _line2)),
                                boxShadow: lifted
                                    ? const [BoxShadow(color: Color(0x590C0E12), blurRadius: 14, offset: Offset(8, 0), spreadRadius: -10)]
                                    : null,
                              ),
                              child: child,
                            );
                          },
                          child: Column(children: [
                            Container(
                              height: ReportSheet.headerHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: const BoxDecoration(color: _headBg, border: Border(bottom: BorderSide(color: _line2))),
                              child: Row(children: [
                                SizedBox(width: 20, child: Text('#', textAlign: TextAlign.right, style: s.rowNo)),
                                const SizedBox(width: 6),
                                Expanded(child: _headerLabel(pinned, s)),
                              ]),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: _vPin,
                                physics: vPhysics,
                                padding: EdgeInsets.zero,
                                itemExtent: ReportSheet.rowHeight,
                                itemCount: rows.length,
                                itemBuilder: (context, i) => _pinnedCell(rows[i], pinned, i, s, bt),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            SizedBox(
              height: ReportSheet.footerHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                child: wrap('footer', Row(children: [
                  Text('Tap a row for details', style: BtText.caption(context).copyWith(fontSize: 12)),
                  const SizedBox(width: 12),
                  Expanded(child: _ScrollTrack(controller: _hBody)),
                ])),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _headerLabel(String column, _Styles s) {
    final sortKey = (_isMoney ? ReportSheet._moneySortKeys : ReportSheet._sortKeys)[column];
    final active = sortKey != null && sortKey == widget.sortColumn;
    final numeric = ReportSheet._numeric.contains(column);
    final label = Text(ReportSheet.labelOf(column), maxLines: 1, overflow: TextOverflow.ellipsis, style: active ? s.head.copyWith(color: Bt.ink) : s.head);
    final content = Row(
      mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        if (sortKey != null) ...[
          const SizedBox(width: 3),
          active
              ? Icon(widget.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: s.accentInk)
              : const Icon(Icons.unfold_more_rounded, size: 13, color: Color(0x59111317)),
        ],
      ],
    );
    if (sortKey == null) return content;
    return Semantics(
      button: true,
      label: 'Sort by ${ReportSheet.labelOf(column).toLowerCase()}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tapping the active column flips the direction; a new column starts newest/highest first.
        onTap: () => widget.onSort(sortKey, active ? !widget.sortAscending : const {'project', 'title', 'type'}.contains(sortKey)),
        child: SizedBox(height: ReportSheet.headerHeight, child: content),
      ),
    );
  }

  Widget _headerCell(String column, double width, _Styles s) {
    final pin = widget.onPinColumn;
    final cell = Container(
      width: width,
      height: ReportSheet.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: ReportSheet._numeric.contains(column) ? Alignment.centerRight : Alignment.centerLeft,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _line))),
      child: _headerLabel(column, s),
    );
    if (pin == null) return cell;
    // Long-press a heading to freeze that column on the left.
    return GestureDetector(onLongPress: () => pin(column), child: cell);
  }

  Widget _pinnedCell(_SheetRow row, String column, int i, _Styles s, BtTheme bt) {
    final selected = row.id == _selectedId;
    final isItem = ReportSheet.itemColumns.contains(column);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapRow(row),
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 8),
        decoration: BoxDecoration(
          color: selected ? s.selected : (i.isOdd ? _zebra : Bt.card),
          border: Border(
            bottom: const BorderSide(color: _line),
            left: selected ? BorderSide(color: s.accent, width: 3) : BorderSide.none,
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: selected ? 17 : 20,
            child: Text('${widget.firstRowNumber + i}', textAlign: TextAlign.right, maxLines: 1, style: s.rowNo),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: isItem
                ? Text(_text(row.money?.description ?? row.entry!.description), maxLines: 1, overflow: TextOverflow.ellipsis, style: s.cell.copyWith(fontWeight: FontWeight.w600))
                : Align(alignment: Alignment.centerLeft, child: _cell(column, row, s, bt)),
          ),
        ]),
      ),
    );
  }

  Widget _bodyRow(_SheetRow row, List<String> cols, int i, _Styles s) {
    final selected = row.id == _selectedId;
    final bt = context.bt;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapRow(row),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? s.selected : (i.isOdd ? _zebra : Bt.card),
          border: const Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(children: [
          for (final c in cols)
            Container(
              width: _widthOf(c),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: ReportSheet._numeric.contains(c) ? Alignment.centerRight : Alignment.centerLeft,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: _line))),
              child: _cell(c, row, s, bt),
            ),
        ]),
      ),
    );
  }

  static String _text(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

  static Color _typeColor(EntryType t, BtTheme bt) {
    switch (t) {
      case EntryType.material:
        return bt.series[0];
      case EntryType.labour:
        return bt.series[1];
      case EntryType.equipment:
        return bt.series[2];
    }
  }

  /// Quantity as entered; older entries without one fall back to amount ÷ rate.
  static String _qty(EntryModel e) {
    double? q = e.quantity;
    if (q == null || q <= 0) {
      final rate = e.ratePerUnit ?? 0;
      q = rate > 0 ? e.amount / rate : null;
    }
    if (q == null) return '—';
    return q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  Widget _plain(String v, _Styles s, {Color? color, FontWeight? weight, bool numeric = false}) {
    var style = s.cell;
    if (v == '—') {
      style = style.copyWith(color: Bt.placeholder);
    } else if (color != null || weight != null) {
      style = style.copyWith(color: color, fontWeight: weight);
    }
    if (numeric) style = style.copyWith(fontFeatures: BtText.tnum);
    return Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: style);
  }

  Widget _cell(String column, _SheetRow row, _Styles s, BtTheme bt) {
    final m = row.money;
    return m == null ? _entryCell(column, row.entry!, s, bt) : _moneyCell(column, m, s, bt);
  }

  /// Cells of the finance table. Actions and Status of spending rows are the
  /// entries sheet's own; other rows leave the spending-only cells blank.
  Widget _moneyCell(String column, MoneyRow m, _Styles s, BtTheme bt) {
    final l = m.ledger;
    final e = m.entry;
    switch (column) {
      case 'Description':
        return _plain(_text(m.description), s, weight: FontWeight.w600);
      case 'Date':
        return _plain(l.date == null ? '—' : formatShortDate(l.date), s, numeric: true);
      case 'Project':
        return _plain(_text(l.projectName), s);
      case 'Type':
        return _CategoryPill(category: l.category, label: m.categoryLabel, style: s.pill, bt: bt);
      case 'In':
        return m.isIn ? _plain(formatInr(l.amount), s, color: Bt.green, weight: FontWeight.w700, numeric: true) : const SizedBox.shrink();
      case 'Out':
        return m.isIn ? const SizedBox.shrink() : _plain(formatInr(l.amount), s, weight: FontWeight.w700, numeric: true);
      case 'Balance':
        final b = l.runningBalance;
        return b == null ? _plain('—', s) : _plain(formatInr(b), s, color: b < 0 ? Bt.red : Bt.ink, weight: FontWeight.w600, numeric: true);
      case 'Paid / Remaining':
        if (e == null) return const SizedBox.shrink();
        final rem = e.remainingAmount;
        return Text.rich(
          TextSpan(children: [
            TextSpan(text: formatInr(e.paidAmount), style: TextStyle(color: e.paidAmount > 0 ? Bt.green : Bt.ink3)),
            const TextSpan(text: ' / ', style: TextStyle(color: Bt.ink3)),
            TextSpan(text: formatInr(rem), style: TextStyle(color: rem > 0 ? Bt.red : Bt.green, fontWeight: FontWeight.w600)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: s.cell.copyWith(fontFeatures: BtText.tnum),
        );
      case 'Status':
        if (e != null) return _StatusPill(status: widget.statusOf(e), style: s.pill);
        // Money that is not a spending entry has no part-payments: it was
        // received / paid, unless it still waits for approval.
        return _StatusPill(
          status: m.waitsForApproval ? 'Partial' : 'Fully Paid',
          label: m.statusLabel(widget.statusOf),
          style: s.pill,
        );
      case 'Add More':
      case 'Record Payment':
      case 'Edit Entry':
        return e == null ? const SizedBox.shrink() : _entryCell(column, e, s, bt);
      default:
        return _plain('—', s);
    }
  }

  Widget _entryCell(String column, EntryModel e, _Styles s, BtTheme bt) {
    switch (column) {
      case 'Purchased Date':
        return _plain(formatShortDate(e.date), s, numeric: true);
      case 'Payment Date':
        final paid = ReportSheet.paymentDateOf(e);
        return _plain(paid == null ? '—' : formatShortDate(paid), s, numeric: true);
      case 'Project':
        return _plain(_text(widget.projectNameOf(e)), s);
      case 'Type':
        final label = e.type == EntryType.material ? 'Material' : (e.type == EntryType.labour ? 'Labour' : 'Equipment');
        return Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _typeColor(e.type, bt), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Flexible(child: _plain(label, s, color: Bt.ink2)),
        ]);
      case 'Description':
      case 'Material':
      case 'Worker Type':
      case 'Equipment':
        return _plain(_text(e.description), s);
      case 'Brand':
        return _plain(_text(e.brand), s);
      case 'Floor':
        return _plain(_text(e.floor), s);
      case 'Phase':
        return _plain(_text(e.phase), s);
      case 'Activity':
        return _plain(_text(e.activity), s);
      case 'Unit':
        return _plain(_text(e.unit), s);
      case 'Status':
        return _StatusPill(status: widget.statusOf(e), style: s.pill);
      case 'Amount':
        return _plain(formatInr(e.amount), s, weight: FontWeight.w700, numeric: true);
      case 'Paid':
        return _plain(formatInr(e.paidAmount), s, color: e.paidAmount > 0 ? Bt.green : Bt.ink3, numeric: true);
      case 'Remaining':
        final rem = e.remainingAmount;
        return _plain(formatInr(rem), s, color: rem > 0 ? Bt.red : Bt.green, weight: FontWeight.w600, numeric: true);
      case 'Rate':
      case 'Rate/Day':
      case 'Rent Rate':
        return _plain(e.ratePerUnit == null ? '—' : formatInr(e.ratePerUnit), s, numeric: true);
      case 'Qty':
      case 'Days':
      case 'Duration':
        return _plain(_qty(e), s, numeric: true);
      case 'Add More':
        return _SheetAction(label: 'Add More', icon: Icons.add_circle_outline_rounded, primary: true, style: s.action, onTap: () => widget.onAddMore(e));
      case 'Record Payment':
        return _SheetAction(label: 'Record Payment', icon: Icons.credit_card_outlined, style: s.action, onTap: () => widget.onRecordPayment(e));
      case 'Edit Entry':
        return _SheetAction(label: 'Edit Entry', icon: Icons.edit_outlined, style: s.action, onTap: () => widget.onEdit(e));
      default:
        return _plain('—', s);
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.style, this.label});
  final String status;
  final TextStyle style;

  /// Replaces the wording of [status] (its colour stays).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (text, fg, bg) = switch (status) {
      'Fully Paid' => ('Paid', Bt.green, Bt.greenSoft),
      'Partial' => ('Part paid', Bt.amber, Bt.amberSoft),
      _ => ('Not paid', Bt.red, Bt.redSoft),
    };
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label ?? text, maxLines: 1, style: style.copyWith(color: fg)),
      ]),
    );
  }
}

/// Category (Material, Client payment, Loan repayment…) pill of the finance table.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.label, required this.style, required this.bt});
  final String category;
  final String label;
  final TextStyle style;
  final BtTheme bt;

  @override
  Widget build(BuildContext context) {
    final dot = switch (category) {
      'material' => bt.series[0],
      'labour' => bt.series[1],
      'equipment' => bt.series[2],
      'client_payment' || 'loan_received' => Bt.green,
      'loan_repayment' => Bt.amber,
      _ => Bt.ink3,
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(color: Bt.ink2))),
      ]),
    );
  }
}

/// Small in-cell button (Add More / Record Payment / Edit Entry). Plain
/// decorated box + gesture detector so 50 rows stay cheap.
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.icon, required this.onTap, required this.style, this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final TextStyle style;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Bt.bone : Bt.ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: primary ? Bt.ink : Bt.card,
            borderRadius: BorderRadius.circular(8),
            border: primary ? null : Border.all(color: _line2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(label, maxLines: 1, style: style.copyWith(color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Thin sideways-position bar under the sheet; empty when nothing is off-screen.
class _ScrollTrack extends StatelessWidget {
  const _ScrollTrack({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.hasClients || !controller.position.hasContentDimensions) {
            return const SizedBox(height: 4);
          }
          final pos = controller.position;
          final max = pos.maxScrollExtent;
          if (max <= 0) return const SizedBox(height: 4);
          final view = pos.viewportDimension;
          final frac = (view / (view + max)).clamp(.08, 1.0);
          final at = (pos.pixels / max).clamp(0.0, 1.0);
          return LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth * frac;
            return Container(
              height: 4,
              decoration: BoxDecoration(color: const Color(0x14111317), borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: (c.maxWidth - w) * at),
                child: Container(width: w, decoration: BoxDecoration(color: Bt.ink2, borderRadius: BorderRadius.circular(4))),
              ),
            );
          });
        },
      ),
    );
  }
}

/// Table / List switch in the Reports toolbar (also Cards / List under "By type").
class ReportViewToggle extends StatelessWidget {
  const ReportViewToggle({
    super.key,
    required this.table,
    required this.onChanged,
    this.tableIcon = Icons.table_chart_outlined,
    this.tableLabel = 'Table',
    this.listIcon = Icons.view_agenda_outlined,
    this.listLabel = 'List',
  });
  final bool table;
  final ValueChanged<bool> onChanged;
  final IconData tableIcon;
  final String tableLabel;
  final IconData listIcon;
  final String listLabel;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, IconData icon, String label) {
      final on = table == value;
      return Semantics(
        button: true,
        selected: on,
        label: '$label view',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: Bt.fast,
            curve: Bt.ease,
            height: 30,
            width: 34,
            decoration: BoxDecoration(
              color: on ? Bt.card : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on ? const [BoxShadow(color: Color(0x240C0E12), blurRadius: 3, offset: Offset(0, 1))] : null,
            ),
            child: Icon(icon, size: 17, color: on ? Bt.ink : Bt.ink3),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Bt.ink.withValues(alpha: .06), borderRadius: BorderRadius.circular(Bt.rChip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        option(true, tableIcon, tableLabel),
        option(false, listIcon, listLabel),
      ]),
    );
  }
}
