import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
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
  });

  final List<EntryModel> entries;

  /// The tab's active columns, in the user's order (see "Edit columns").
  final List<String> columns;
  final String Function(EntryModel) projectNameOf;

  /// 'Fully Paid', 'Partial' or 'Not Paid'.
  final String Function(EntryModel) statusOf;

  /// 'date', 'project' or 'amount'.
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

  static const _itemColumns = {'Description', 'Material', 'Worker Type', 'Equipment'};
  static const _actionColumns = ['Add More', 'Record Payment', 'Edit Entry'];
  static const _sortKeys = {'Purchased Date': 'date', 'Project': 'project', 'Amount': 'amount'};
  static const _numeric = {
    'Amount', 'Paid', 'Remaining', 'Rate', 'Rate/Day', 'Rent Rate', 'Qty', 'Days', 'Duration',
  };

  static double widthOf(String column) {
    switch (column) {
      case 'Purchased Date':
        return 92;
      case 'Payment Date':
        return 104;
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
        return 'DATE';
      case 'Amount':
        return 'AMOUNT (INR)';
      case 'Paid':
        return 'PAID (INR)';
      case 'Remaining':
        return 'REMAINING (INR)';
      default:
        return column.toUpperCase();
    }
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
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
    final rowsChanged = old.entries.length != widget.entries.length ||
        Iterable.generate(widget.entries.length).any((i) => old.entries[i].id != widget.entries[i].id);
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

  String? get _pinned {
    final cols = widget.columns;
    for (final c in cols) {
      if (ReportSheet._itemColumns.contains(c)) return c;
    }
    return cols.isEmpty ? null : cols.first;
  }

  List<String> get _scrollColumns {
    final pinned = _pinned;
    return [...widget.columns.where((c) => c != pinned), ...ReportSheet._actionColumns];
  }

  void _tapRow(EntryModel e) {
    if (_selectedId != e.id) setState(() => _selectedId = e.id);
    widget.onRowTap(e);
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final s = _Styles(context, bt);
    final rows = widget.entries;
    final pinned = _pinned;
    final pinW = widget.pinnedWidth;
    final scrollCols = _scrollColumns;
    final scrollWidth = scrollCols.fold<double>(0, (w, c) => w + ReportSheet.widthOf(c));
    final maxBody = (widget.maxHeight - ReportSheet.headerHeight).clamp(ReportSheet.rowHeight, double.infinity);
    final bodyHeight = (rows.length * ReportSheet.rowHeight).clamp(ReportSheet.rowHeight, maxBody).toDouble();
    final innerScroll = rows.length * ReportSheet.rowHeight > bodyHeight + .5;
    final vPhysics = innerScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics();

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
                        SingleChildScrollView(
                          controller: _hHead,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Container(
                            height: ReportSheet.headerHeight,
                            decoration: const BoxDecoration(color: _headBg, border: Border(bottom: BorderSide(color: _line2))),
                            child: Row(children: [for (final c in scrollCols) _headerCell(c, ReportSheet.widthOf(c), s)]),
                          ),
                        ),
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
                child: Row(children: [
                  Text('Tap a row for details', style: BtText.caption(context).copyWith(fontSize: 12)),
                  const SizedBox(width: 12),
                  Expanded(child: _ScrollTrack(controller: _hBody)),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _headerLabel(String column, _Styles s) {
    final sortKey = ReportSheet._sortKeys[column];
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
        onTap: () => widget.onSort(sortKey, active ? !widget.sortAscending : sortKey == 'project'),
        child: SizedBox(height: ReportSheet.headerHeight, child: content),
      ),
    );
  }

  Widget _headerCell(String column, double width, _Styles s) {
    return Container(
      width: width,
      height: ReportSheet.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: ReportSheet._numeric.contains(column) ? Alignment.centerRight : Alignment.centerLeft,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _line))),
      child: _headerLabel(column, s),
    );
  }

  Widget _pinnedCell(EntryModel e, String column, int i, _Styles s, BtTheme bt) {
    final selected = e.id == _selectedId;
    final isItem = ReportSheet._itemColumns.contains(column);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapRow(e),
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
                ? Text(_text(e.description), maxLines: 1, overflow: TextOverflow.ellipsis, style: s.cell.copyWith(fontWeight: FontWeight.w600))
                : _cell(column, e, s, bt),
          ),
        ]),
      ),
    );
  }

  Widget _bodyRow(EntryModel e, List<String> cols, int i, _Styles s) {
    final selected = e.id == _selectedId;
    final bt = context.bt;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapRow(e),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? s.selected : (i.isOdd ? _zebra : Bt.card),
          border: const Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(children: [
          for (final c in cols)
            Container(
              width: ReportSheet.widthOf(c),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: ReportSheet._numeric.contains(c) ? Alignment.centerRight : Alignment.centerLeft,
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: _line))),
              child: _cell(c, e, s, bt),
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

  Widget _cell(String column, EntryModel e, _Styles s, BtTheme bt) {
    switch (column) {
      case 'Purchased Date':
        return _plain(formatShortDate(e.date), s, numeric: true);
      case 'Payment Date':
        return _plain(e.paymentDate == null ? '—' : formatShortDate(e.paymentDate), s, numeric: true);
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
  const _StatusPill({required this.status, required this.style});
  final String status;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
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
        Text(label, maxLines: 1, style: style.copyWith(color: fg)),
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

/// Table / List switch in the Reports toolbar.
class ReportViewToggle extends StatelessWidget {
  const ReportViewToggle({super.key, required this.table, required this.onChanged});
  final bool table;
  final ValueChanged<bool> onChanged;

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
        option(true, Icons.table_chart_outlined, 'Table'),
        option(false, Icons.view_agenda_outlined, 'List'),
      ]),
    );
  }
}
