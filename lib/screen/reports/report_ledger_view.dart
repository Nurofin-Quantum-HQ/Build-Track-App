import 'dart:async';

import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/screen/reports/report_ledger_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Money in / Money out / All, for people allowed to see finances.
/// Sits inside the Reports sheet; the project and period come from Reports.
class LedgerPanel extends StatefulWidget {
  const LedgerPanel({
    super.key,
    required this.direction,
    required this.projectId,
    required this.projectLabel,
    required this.periodLabel,
    required this.from,
    required this.to,
    required this.onForbidden,
  });

  final LedgerDirection direction;
  final String projectId;
  final String projectLabel;
  final String periodLabel;
  final DateTime? from;
  final DateTime? to;

  /// The server said 403: Reports hides the finance views.
  final VoidCallback onForbidden;

  @override
  State<LedgerPanel> createState() => LedgerPanelState();
}

class _Item {
  const _Item.header(this.group) : row = null;
  const _Item.row(this.row) : group = null;
  final _GroupHeader? group;
  final LedgerRow? row;
}

class _GroupHeader {
  const _GroupHeader(this.label, this.moneyIn, this.moneyOut, this.net, this.count);
  final String label;
  final double moneyIn;
  final double moneyOut;
  final double net;
  final int count;
}

class LedgerPanelState extends State<LedgerPanel> {
  static const _pageSize = 100;

  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  Set<String> _cats = {};
  String _q = '';
  LedgerGroupBy _groupBy = LedgerGroupBy.none;
  LedgerResult? _data;
  bool _loading = true;
  String? _error;
  int _request = 0;
  int _shown = _pageSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LedgerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.direction != widget.direction) {
      _cats = {}; // categories differ per view
      _load();
    } else if (old.projectId != widget.projectId || old.from != widget.from || old.to != widget.to) {
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  LedgerQuery get _query => LedgerQuery(
        projectId: widget.projectId,
        from: widget.from,
        to: widget.to,
        direction: widget.direction,
        categories: _cats,
        q: _q,
        groupBy: _groupBy,
      );

  /// Reload the ledger (pull-to-refresh, retry, after a category change).
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _shown = _pageSize;
    });
    try {
      final r = await LedgerApi.fetch(_query);
      if (!mounted || id != _request) return;
      setState(() {
        _data = r;
        _loading = false;
      });
    } on LedgerForbidden {
      if (!mounted || id != _request) return;
      widget.onForbidden();
    } on LedgerFailure catch (e) {
      if (!mounted || id != _request) return;
      // Never leave old numbers (or a zero) on screen next to an error.
      setState(() {
        _data = null;
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || v.trim() == _q) return;
      _q = v.trim();
      _load();
    });
    setState(() {}); // clear button
  }

  // ───────────────────────────────────────────────────────── grouping

  String _keyOf(LedgerRow r) => switch (_groupBy) {
        LedgerGroupBy.category => r.category,
        LedgerGroupBy.project => r.projectId,
        LedgerGroupBy.month => r.date == null ? '' : DateFormat('yyyy-MM').format(r.date!),
        LedgerGroupBy.payee => r.payee.isEmpty ? 'Unspecified' : r.payee,
        LedgerGroupBy.none => '',
      };

  String _labelOf(LedgerRow r) => switch (_groupBy) {
        LedgerGroupBy.category => LedgerCategories.label(r.category),
        LedgerGroupBy.project => r.projectName.isEmpty ? 'No project' : r.projectName,
        LedgerGroupBy.month => r.date == null ? 'No date' : DateFormat('MMM yyyy').format(r.date!),
        LedgerGroupBy.payee => r.payee.isEmpty ? 'No payee' : r.payee,
        LedgerGroupBy.none => '',
      };

  /// Header + rows in display order. Subtotals come from the server groups
  /// (complete even when the row list is cut at 5,000); when a server key
  /// can't be matched they are added up from the rows.
  List<_Item> _items(LedgerResult data) {
    if (_groupBy == LedgerGroupBy.none) return [for (final r in data.rows) _Item.row(r)];
    final byKey = <String, List<LedgerRow>>{};
    for (final r in data.rows) {
      byKey.putIfAbsent(_keyOf(r), () => []).add(r);
    }
    // Server payee keys are ids ("s:<supplier>", "w:<workerId>"); rows only carry
    // the name, so payee groups are matched by their label.
    String gk(LedgerGroup g) => _groupBy == LedgerGroupBy.payee ? g.label : g.key;
    final server = {for (final g in data.groups) gk(g): g};
    final order = <String>[
      for (final g in data.groups)
        if (byKey.containsKey(gk(g))) gk(g),
      for (final k in byKey.keys)
        if (!server.containsKey(k)) k,
    ];
    final out = <_Item>[];
    for (final k in order) {
      final rows = byKey[k]!;
      final g = server[k];
      final inn = rows.where((r) => r.isIn).fold<double>(0, (s, r) => s + r.amount);
      final outt = rows.where((r) => !r.isIn).fold<double>(0, (s, r) => s + r.amount);
      out.add(_Item.header(_GroupHeader(
        g != null && g.label.isNotEmpty ? g.label : _labelOf(rows.first),
        g?.moneyIn ?? inn,
        g?.moneyOut ?? outt,
        g?.net ?? (inn - outt),
        g?.count ?? rows.length,
      )));
      out.addAll(rows.map(_Item.row));
    }
    return out;
  }

  // ───────────────────────────────────────────────────────── actions

  String get _filterSummary {
    final parts = <String>[
      'Project: ${widget.projectLabel}',
      'Period: ${widget.periodLabel}',
      'Showing: ${switch (widget.direction) {
        LedgerDirection.inbound => 'Money in',
        LedgerDirection.outbound => 'Money out',
        LedgerDirection.all => 'Money in and out',
      }}',
      if (_cats.isNotEmpty) 'Categories: ${_cats.map(LedgerCategories.label).join(', ')}',
      if (_q.isNotEmpty) 'Search: $_q',
      if (_data?.truncated == true) 'Newest 5,000 entries only',
    ];
    return parts.join(' | ');
  }

  /// Download sheet: Excel and PDF of exactly what is on screen.
  void openExport() {
    final data = _data;
    if (data == null || data.rows.isEmpty) {
      btToast(context, 'Nothing to download for these filters.', error: true);
      return;
    }
    showBtSheet(
      context,
      title: 'Download',
      subtitle: '${data.rows.length} entries · current filters',
      builder: (sheetCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtButton(
            label: 'Download PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: () {
              Navigator.pop(sheetCtx);
              _run(() => LedgerExport.sharePdf(data, title: 'BuildTrack money in and out', filterSummary: _filterSummary), 'PDF');
            },
          ),
          const SizedBox(height: 10),
          BtButton(
            label: 'Download Excel',
            icon: Icons.table_chart_outlined,
            variant: BtButtonVariant.secondary,
            onPressed: () {
              Navigator.pop(sheetCtx);
              _run(() => LedgerExport.shareExcel(data), 'Excel');
            },
          ),
          const SizedBox(height: 8),
          Text('Excel opens the same entries as a spreadsheet (.csv).', textAlign: TextAlign.center, style: BtText.caption(context)),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() job, String what) async {
    try {
      await job();
    } catch (e) {
      if (mounted) btToast(context, '$what download failed. Please try again.', error: true);
    }
  }

  Future<void> _pickGroupBy() async {
    final v = await showBtSheet<LedgerGroupBy>(
      context,
      title: 'Group by',
      builder: (sheetCtx) => BtGroup(
        children: [
          for (final g in LedgerGroupBy.values)
            BtRow(
              title: g.label,
              minHeight: 48,
              trailing: g == _groupBy ? Icon(Icons.check_rounded, color: sheetCtx.bt.accentInk, size: 20) : null,
              onTap: () => Navigator.pop(sheetCtx, g),
            ),
        ],
      ),
    );
    if (v != null && v != _groupBy) {
      _groupBy = v;
      _load();
    }
  }

  void _openRow(LedgerRow r) {
    showBtSheet(
      context,
      title: r.title.isEmpty ? LedgerCategories.label(r.category) : r.title,
      subtitle: LedgerCategories.label(r.category),
      builder: (sheetCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtGroup(
            children: [
              BtValueRow(label: r.isIn ? 'Money in' : 'Money out', value: '${r.isIn ? '+' : '−'}${formatInr(r.amount)}', valueColor: r.isIn ? Bt.green : Bt.ink),
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
              _changeCategory(r);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeCategory(LedgerRow r) async {
    final options = LedgerCategories.forDirection(r.isIn ? LedgerDirection.inbound : LedgerDirection.outbound);
    final picked = await showBtSheet<String>(
      context,
      title: 'Change category',
      subtitle: 'Only the category changes. The amount and entry stay as they are.',
      builder: (sheetCtx) => BtGroup(
        children: [
          for (final k in options)
            BtRow(
              title: LedgerCategories.label(k),
              minHeight: 48,
              trailing: k == r.category ? Icon(Icons.check_rounded, color: sheetCtx.bt.accentInk, size: 20) : null,
              onTap: () => Navigator.pop(sheetCtx, k),
            ),
        ],
      ),
    );
    if (picked == null || picked == r.category || !mounted) return;
    try {
      await LedgerApi.setCategory(r.id, picked);
      if (!mounted) return;
      btToast(context, 'Moved to ${LedgerCategories.label(picked)}.');
      _load();
    } on LedgerForbidden {
      if (mounted) btToast(context, "You don't have access to change this.", error: true);
    } on LedgerFailure catch (e) {
      if (mounted) btToast(context, e.message, error: true);
    }
  }

  // ───────────────────────────────────────────────────────── build

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data != null && !_loading) _Summary(data: data) else if (_loading) const BtSkeleton(height: 62, radius: 14),
        const SizedBox(height: 12),
        _categoryChips(),
        const SizedBox(height: 10),
        _searchField(context),
        const SizedBox(height: 10),
        Row(children: [
          BtChip(
            label: _groupBy == LedgerGroupBy.none ? 'Group by' : 'Grouped by ${_groupBy.label.toLowerCase()}',
            icon: Icons.layers_outlined,
            trailingIcon: Icons.expand_more_rounded,
            selected: _groupBy != LedgerGroupBy.none,
            onTap: _pickGroupBy,
          ),
          const SizedBox(width: 8),
          BtChip(label: 'Download', icon: Icons.file_download_outlined, onTap: openExport),
        ]),
        const SizedBox(height: 12),
        _body(context),
      ],
    );
  }

  Widget _categoryChips() {
    final keys = LedgerCategories.forDirection(widget.direction);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: [
        for (final k in keys) ...[
          BtChip(
            label: LedgerCategories.label(k),
            selected: _cats.contains(k),
            onTap: () {
              setState(() => _cats.contains(k) ? _cats.remove(k) : _cats.add(k));
              _load();
            },
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _search,
      onChanged: _onSearch,
      style: BtText.body(context),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search title, payee or notes',
        hintStyle: BtText.body(context, color: Bt.placeholder),
        prefixIcon: const Icon(Icons.search_rounded, color: Bt.ink3, size: 22),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.cancel_rounded, color: Bt.placeholder, size: 20),
                onPressed: () {
                  _search.clear();
                  _debounce?.cancel();
                  _q = '';
                  setState(() {});
                  _load();
                },
              ),
        filled: true,
        fillColor: Bt.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: const BorderSide(color: Bt.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Bt.rInput), borderSide: BorderSide(color: context.bt.brand, width: 1.5)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const BtSkeletonList(count: 5);
    if (_error != null) return BtErrorCard(message: _error!, onRetry: _load);
    final data = _data;
    if (data == null) return BtErrorCard(onRetry: _load);
    if (data.rows.isEmpty) {
      return const BtCard(
        child: BtEmpty(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Nothing here yet',
          message: 'No money entries match this project, period and filters.',
        ),
      );
    }
    final items = _items(data);
    // Show the first _shown rows (headers ride along with their rows).
    final visible = <_Item>[];
    var rowsShown = 0;
    var totalRows = 0;
    for (final it in items) {
      if (it.row != null) {
        totalRows++;
        if (rowsShown >= _shown) continue;
        rowsShown++;
      } else if (rowsShown >= _shown) {
        continue;
      }
      visible.add(it);
    }
    final children = <Widget>[];
    var open = <Widget>[];
    void flush() {
      if (open.isEmpty) return;
      children.add(_Card(children: open));
      open = [];
    }

    for (final it in visible) {
      if (it.group != null) {
        flush();
        children.add(_GroupHeaderView(header: it.group!));
      } else {
        open.add(_RowView(
          row: it.row!,
          onTap: () => _openRow(it.row!),
        ));
      }
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (totalRows > rowsShown) ...[
          const SizedBox(height: 10),
          BtButton(
            label: 'Show ${totalRows - rowsShown > _pageSize ? _pageSize : totalRows - rowsShown} more',
            variant: BtButtonVariant.secondary,
            small: true,
            onPressed: () => setState(() => _shown += _pageSize),
          ),
        ],
        if (data.truncated) ...[
          const SizedBox(height: 12),
          Text(
            'Showing the newest ${NumberFormat.decimalPattern('en_IN').format(data.rows.length)} entries. Totals cover everything; narrow the project or period to see the rest.',
            style: BtText.caption(context),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(14), boxShadow: Bt.shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: Bt.line),
            children[i],
          ],
        ]),
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row, required this.onTap});
  final LedgerRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final title = r.title.isEmpty ? LedgerCategories.label(r.category) : r.title;
    final sub = [formatShortDate(r.date), if (r.payee.isNotEmpty) r.payee].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      label: '$title, ${r.isIn ? 'money in' : 'money out'} ${formatInr(r.amount)}',
      child: InkWell(
        onTap: onTap,
        onLongPress: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Bt.fill, borderRadius: BorderRadius.circular(10)),
                  child: Text(LedgerCategories.label(r.category), style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w600).copyWith(fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${r.isIn ? '+' : '−'}${formatInr(r.amount)}',
                style: BtText.num(BtText.body(context, weight: FontWeight.w700, color: r.isIn ? Bt.green : Bt.ink)),
              ),
              if (r.runningBalance != null) ...[
                const SizedBox(height: 2),
                Text('Bal ${formatInr(r.runningBalance)}', style: BtText.num(BtText.caption(context))),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _GroupHeaderView extends StatelessWidget {
  const _GroupHeaderView({required this.header});
  final _GroupHeader header;
  @override
  Widget build(BuildContext context) {
    final h = header;
    final parts = <String>[
      if (h.moneyIn > 0) 'In ${formatInr(h.moneyIn)}',
      if (h.moneyOut > 0) 'Out ${formatInr(h.moneyOut)}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w700)),
            Text(
              '${h.count} ${h.count == 1 ? 'entry' : 'entries'}${parts.isEmpty ? '' : ' · ${parts.join(' · ')}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BtText.num(BtText.caption(context)),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text(
          h.net >= 0 ? '+${formatInr(h.net)}' : formatInr(h.net),
          style: BtText.num(BtText.body(context, weight: FontWeight.w700, color: h.net >= 0 ? Bt.green : Bt.red)),
        ),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});
  final LedgerResult data;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String text, Color color) => Expanded(
          child: Container(
            color: Bt.card,
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.ink2).copyWith(fontSize: 12)),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(text, maxLines: 1, style: BtText.num(BtText.body(context, weight: FontWeight.w700, color: color).copyWith(fontSize: 15))),
                ),
              ],
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: Bt.shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Bt.line,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              cell('Money in', formatInr(data.moneyIn), Bt.green),
              const SizedBox(width: 1),
              cell('Money out', formatInr(data.moneyOut), Bt.red),
              const SizedBox(width: 1),
              cell('Net', data.net > 0 ? '+${formatInr(data.net)}' : formatInr(data.net), data.net >= 0 ? Bt.green : Bt.red),
            ]),
          ),
        ),
      ),
    );
  }
}
