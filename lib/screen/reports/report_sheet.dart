import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Spreadsheet view of report entries, shown right on the Reports page.
/// The item column stays pinned on the left and the header row stays on top;
/// everything else scrolls sideways, and up/down once there are more than
/// [maxVisibleRows] rows.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.entries,
    required this.columns,
    required this.totalCount,
    required this.projectNameOf,
    required this.statusOf,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onRowTap,
    required this.onAddMore,
    required this.onRecordPayment,
    required this.onEdit,
    required this.onEditColumns,
    required this.onFullScreen,
  });

  final List<EntryModel> entries;

  /// The tab's active columns, in the user's order (see "Edit columns").
  final List<String> columns;
  final int totalCount;
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
  final VoidCallback onEditColumns;
  final VoidCallback onFullScreen;

  static const rowHeight = 48.0;
  static const headerHeight = 40.0;
  static const maxVisibleRows = 10;
  static const pinnedWidth = 136.0;

  static const _itemColumns = {'Description', 'Material', 'Worker Type', 'Equipment'};
  static const _actionsColumn = 'Actions';
  static const _sortKeys = {'Purchased Date': 'date', 'Project': 'project', 'Amount': 'amount'};
  static const _numeric = {
    'Amount', 'Paid', 'Remaining', 'Rate', 'Rate/Day', 'Rent Rate', 'Qty', 'Days', 'Duration',
  };

  static double widthOf(String column) {
    switch (column) {
      case 'Purchased Date':
        return 100;
      case 'Payment Date':
        return 112;
      case 'Project':
        return 148;
      case 'Type':
        return 116;
      case 'Description':
      case 'Material':
      case 'Worker Type':
      case 'Equipment':
        return 168;
      case 'Brand':
        return 120;
      case 'Floor':
        return 96;
      case 'Phase':
      case 'Activity':
        return 140;
      case 'Unit':
        return 76;
      case 'Status':
        return 108;
      case 'Amount':
        return 112;
      case 'Paid':
        return 104;
      case 'Remaining':
        return 116;
      case 'Rate':
      case 'Rate/Day':
      case 'Rent Rate':
        return 100;
      case 'Qty':
      case 'Days':
      case 'Duration':
        return 84;
      case _actionsColumn:
        return 340;
      default:
        return 120;
    }
  }

  static String labelOf(String column) => column == 'Purchased Date' ? 'Date' : column;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _hHead = ScrollController();
  final _hBody = ScrollController();
  final _vPin = ScrollController();
  final _vBody = ScrollController();
  bool _syncing = false;

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
    return [...widget.columns.where((c) => c != pinned), ReportSheet._actionsColumn];
  }

  String get _sortCaption {
    switch (widget.sortColumn) {
      case 'amount':
        return widget.sortAscending ? 'Amount: low to high' : 'Amount: high to low';
      case 'project':
        return widget.sortAscending ? 'Project A–Z' : 'Project Z–A';
      default:
        return widget.sortAscending ? 'Oldest first' : 'Newest first';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final rows = widget.entries;
    final pinned = _pinned;
    final scrollCols = _scrollColumns;
    final scrollWidth = scrollCols.fold<double>(0, (w, c) => w + ReportSheet.widthOf(c));
    final visibleRows = rows.length.clamp(1, ReportSheet.maxVisibleRows);
    final bodyHeight = visibleRows * ReportSheet.rowHeight;
    final innerScroll = rows.length > ReportSheet.maxVisibleRows;
    final vPhysics = innerScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics();

    return ScrollConfiguration(
      // Let mouse and trackpad drag the sheet too (web / desktop).
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
        scrollbars: false,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Bt.card,
          border: Border.symmetric(horizontal: BorderSide(color: Bt.line)),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final overflows = scrollWidth > constraints.maxWidth - ReportSheet.pinnedWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Bt.gutter, 6, 4, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.totalCount} ${widget.totalCount == 1 ? 'entry' : 'entries'}',
                            style: BtText.num(BtText.body(context, weight: FontWeight.w600)),
                          ),
                          Text(
                            overflows ? 'Swipe sideways for more columns' : _sortCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BtText.caption(context),
                          ),
                        ],
                      ),
                    ),
                    BtIconButton(
                      icon: Icons.view_column_outlined,
                      semantic: 'Edit columns',
                      color: Bt.ink2,
                      onTap: widget.onEditColumns,
                    ),
                    BtIconButton(
                      icon: Icons.open_in_full_rounded,
                      semantic: 'Full screen, can rotate',
                      color: Bt.ink2,
                      onTap: widget.onFullScreen,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Bt.line),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pinned != null)
                    AnimatedBuilder(
                      animation: _hBody,
                      builder: (context, child) {
                        final lifted = _hBody.hasClients && _hBody.offset > 1;
                        return Container(
                          width: ReportSheet.pinnedWidth,
                          decoration: BoxDecoration(
                            color: Bt.card,
                            boxShadow: lifted
                                ? const [BoxShadow(color: Color(0x2E101828), blurRadius: 12, offset: Offset(4, 0), spreadRadius: -6)]
                                : null,
                          ),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          _headerCell(context, pinned, ReportSheet.pinnedWidth),
                          SizedBox(
                            height: bodyHeight,
                            child: ListView.builder(
                              controller: _vPin,
                              physics: vPhysics,
                              padding: EdgeInsets.zero,
                              itemExtent: ReportSheet.rowHeight,
                              itemCount: rows.length,
                              itemBuilder: (context, i) => _pinnedCell(context, rows[i], pinned, i, bt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          controller: _hHead,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Row(children: [for (final c in scrollCols) _headerCell(context, c, ReportSheet.widthOf(c))]),
                        ),
                        SizedBox(
                          height: bodyHeight,
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
                                itemBuilder: (context, i) => _bodyRow(context, rows[i], scrollCols, i, bt),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _ScrollTrack(controller: _hBody),
            ],
          );
        }),
      ),
    );
  }

  Widget _headerCell(BuildContext context, String column, double width) {
    final bt = context.bt;
    final sortKey = ReportSheet._sortKeys[column];
    final active = sortKey != null && sortKey == widget.sortColumn;
    final numeric = ReportSheet._numeric.contains(column);
    final color = active ? bt.brand : Bt.ink2;
    final label = Text(
      ReportSheet.labelOf(column),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: BtText.caption(context, color: color, weight: FontWeight.w600),
    );
    Widget content = Row(
      mainAxisAlignment: numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        if (sortKey != null) ...[
          const SizedBox(width: 4),
          Icon(
            active ? (widget.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
            size: 14,
            color: active ? bt.brand : Bt.placeholder,
          ),
        ],
      ],
    );
    final cell = Container(
      width: width,
      height: ReportSheet.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: Bt.fill,
        border: Border(right: BorderSide(color: Bt.line), bottom: BorderSide(color: Bt.line)),
      ),
      child: content,
    );
    if (sortKey == null) return cell;
    return Semantics(
      button: true,
      label: 'Sort by ${ReportSheet.labelOf(column)}',
      child: InkWell(
        // Tapping the active column flips the direction; a new column starts newest/highest first.
        onTap: () => widget.onSort(sortKey, active ? !widget.sortAscending : sortKey == 'project'),
        child: cell,
      ),
    );
  }

  Color _rowColor(int i) => i.isOdd ? const Color(0xFFFAFBFC) : Bt.card;

  Widget _pinnedCell(BuildContext context, EntryModel e, String column, int i, BtTheme bt) {
    final isItem = ReportSheet._itemColumns.contains(column);
    return InkWell(
      onTap: () => widget.onRowTap(e),
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 10),
        decoration: BoxDecoration(
          color: _rowColor(i),
          border: const Border(right: BorderSide(color: Bt.line), bottom: BorderSide(color: Bt.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(color: _typeColor(e.type, bt), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isItem
                  ? Text(
                      _text(e.description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.caption(context, color: Bt.ink, weight: FontWeight.w600).copyWith(height: 1.25),
                    )
                  : _cell(context, column, e, bt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyRow(BuildContext context, EntryModel e, List<String> cols, int i, BtTheme bt) {
    return InkWell(
      onTap: () => widget.onRowTap(e),
      child: Container(
        color: _rowColor(i),
        child: Row(
          children: [
            for (final c in cols)
              Container(
                width: ReportSheet.widthOf(c),
                height: ReportSheet.rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: ReportSheet._numeric.contains(c) ? Alignment.centerRight : Alignment.centerLeft,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Bt.line), bottom: BorderSide(color: Bt.line)),
                ),
                child: _cell(context, c, e, bt),
              ),
          ],
        ),
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

  Widget _plain(BuildContext context, String v, {Color? color, FontWeight? weight, bool numeric = false}) {
    final style = BtText.caption(context, color: v == '—' ? Bt.placeholder : (color ?? Bt.ink), weight: weight ?? FontWeight.w400);
    return Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: numeric ? BtText.num(style) : style);
  }

  Widget _cell(BuildContext context, String column, EntryModel e, BtTheme bt) {
    switch (column) {
      case 'Purchased Date':
        return _plain(context, formatShortDate(e.date), numeric: true);
      case 'Payment Date':
        return _plain(context, e.paymentDate == null ? '—' : formatShortDate(e.paymentDate), numeric: true);
      case 'Project':
        return _plain(context, _text(widget.projectNameOf(e)));
      case 'Type':
        final label = e.type == EntryType.material ? 'Material' : (e.type == EntryType.labour ? 'Labour' : 'Equipment');
        return Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _typeColor(e.type, bt), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: _plain(context, label, color: Bt.ink2)),
        ]);
      case 'Description':
      case 'Material':
      case 'Worker Type':
      case 'Equipment':
        return _plain(context, _text(e.description));
      case 'Brand':
        return _plain(context, _text(e.brand));
      case 'Floor':
        return _plain(context, _text(e.floor));
      case 'Phase':
        return _plain(context, _text(e.phase));
      case 'Activity':
        return _plain(context, _text(e.activity));
      case 'Unit':
        return _plain(context, _text(e.unit));
      case 'Status':
        return _StatusPill(status: widget.statusOf(e));
      case 'Amount':
        return _plain(context, formatInr(e.amount), weight: FontWeight.w600, numeric: true);
      case 'Paid':
        return _plain(context, formatInr(e.paidAmount), color: e.paidAmount > 0 ? Bt.green : Bt.ink3, numeric: true);
      case 'Remaining':
        final rem = e.remainingAmount;
        return _plain(context, formatInr(rem), color: rem > 0 ? Bt.red : Bt.green, weight: FontWeight.w600, numeric: true);
      case 'Rate':
      case 'Rate/Day':
      case 'Rent Rate':
        return _plain(context, e.ratePerUnit == null ? '—' : formatInr(e.ratePerUnit), numeric: true);
      case 'Qty':
      case 'Days':
      case 'Duration':
        return _plain(context, _qty(e), numeric: true);
      case ReportSheet._actionsColumn:
        return Row(children: [
          _SheetAction(label: 'Add more', icon: Icons.add_rounded, primary: true, onTap: () => widget.onAddMore(e)),
          const SizedBox(width: 6),
          _SheetAction(label: 'Record payment', icon: Icons.credit_card_outlined, onTap: () => widget.onRecordPayment(e)),
          const SizedBox(width: 6),
          _SheetAction(label: 'Edit', icon: Icons.edit_outlined, onTap: () => widget.onEdit(e)),
        ]);
      default:
        return _plain(context, '—');
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'Fully Paid' => ('Paid', Bt.green, Bt.greenSoft),
      'Partial' => ('Part paid', Bt.amber, Bt.amberSoft),
      _ => ('Not paid', Bt.red, Bt.redSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Text(label, style: BtText.caption(context, color: fg, weight: FontWeight.w500)),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.label, required this.icon, required this.onTap, this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final fg = primary ? bt.brand : Bt.ink;
    return Material(
      color: primary ? bt.brandSoft : Bt.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: primary ? BorderSide.none : const BorderSide(color: Bt.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(label, style: BtText.caption(context, color: fg, weight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Thin sideways-position bar under the sheet; hidden when nothing is off-screen.
class _ScrollTrack extends StatelessWidget {
  const _ScrollTrack({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasClients || !controller.position.hasContentDimensions) {
          return const SizedBox(height: 11);
        }
        final pos = controller.position;
        final max = pos.maxScrollExtent;
        if (max <= 0) return const SizedBox(height: 11);
        final view = pos.viewportDimension;
        final frac = (view / (view + max)).clamp(.08, 1.0);
        final at = (pos.pixels / max).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(Bt.gutter, 8, Bt.gutter, 0),
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth * frac;
            return Container(
              height: 3,
              decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(2)),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: (c.maxWidth - w) * at),
                child: Container(width: w, decoration: BoxDecoration(color: Bt.ink3, borderRadius: BorderRadius.circular(2))),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Table / List switch next to the Entries title.
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: on ? Bt.card : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: on ? const [BoxShadow(color: Color(0x1F11121C), blurRadius: 2, offset: Offset(0, 1))] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: on ? Bt.ink : Bt.ink2),
              const SizedBox(width: 5),
              Text(label, style: BtText.caption(context, color: on ? Bt.ink : Bt.ink2, weight: on ? FontWeight.w600 : FontWeight.w500)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        option(true, Icons.table_chart_outlined, 'Table'),
        const SizedBox(width: 2),
        option(false, Icons.view_list_rounded, 'List'),
      ]),
    );
  }
}
