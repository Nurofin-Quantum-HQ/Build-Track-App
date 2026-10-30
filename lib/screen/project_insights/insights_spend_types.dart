import 'dart:convert';
import 'dart:math' as math;

import 'package:buildtrack_mobile/common/utils/entry_names.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart' show PaymentStatus;
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_charts.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:buildtrack_mobile/screen/project_insights/suggest_groups_sheet.dart';
import 'package:buildtrack_mobile/screen/project_insights/tidy_names_sheet.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "By type" tab of project insights: where the money went inside each cost
/// category — per labour type (and worker / contractor), per material, per
/// equipment item. Computed on the device from the project's entries
/// (GET /transactions), so it works with the live server as it is.
class InsSpendByTypeView extends StatefulWidget {
  const InsSpendByTypeView({super.key, required this.projectId, this.projectName, this.reloadTick = 0});
  final String projectId;
  final String? projectName;

  /// Bumped by the parent's pull-to-refresh to refetch entries.
  final int reloadTick;

  @override
  State<InsSpendByTypeView> createState() => _InsSpendByTypeViewState();
}

enum _Period { all, month, d90, fy }

extension on _Period {
  String get label => switch (this) {
    _Period.all => 'All time',
    _Period.month => 'This month',
    _Period.d90 => 'Last 90 days',
    _Period.fy => 'This FY',
  };

  DateTime? get from {
    final now = DateTime.now();
    return switch (this) {
      _Period.all => null,
      _Period.month => DateTime(now.year, now.month),
      _Period.d90 => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89)),
      _Period.fy => DateTime(now.month >= 4 ? now.year : now.year - 1, 4),
    };
  }
}

// Remembered for the session so switching projects keeps the same view.
CostCategory _lastCat = CostCategory.labour;
_Period _lastPeriod = _Period.all;

class _InsSpendByTypeViewState extends State<InsSpendByTypeView> {
  List<SpendLine>? _lines;
  SpendBreakdown? _bd;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  CostCategory _cat = _lastCat;
  _Period _period = _lastPeriod;

  /// The "By labour type / material / equipment" list — target of the chart's Others bar.
  final GlobalKey _listKey = GlobalKey();

  /// The user's own groups per category (nameKey → group name), from "Move
  /// to group" / "Suggest groups". Display only; never changes entries.
  Map<CostCategory, Map<String, String>> _groups = const {};
  bool _groupsFromServer = false;
  bool _groupsEdited = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InsSpendByTypeView old) {
    super.didUpdateWidget(old);
    if (old.projectId != widget.projectId || old.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _loadGroups();
    List<SpendLine>? lines;
    var offline = false;
    String? error;
    try {
      final raw = await ApiService.fetchMaterials(projectId: widget.projectId);
      lines = _parse(raw);
    } catch (e) {
      // Offline / server error: fall back to the entries the app already
      // has for this project (only the selected project is cached).
      if (!mounted) return;
      final cached = context.read<ProjectProvider>().entriesForProject(widget.projectId);
      if (cached.isNotEmpty) {
        lines = _parse(cached.map((e) => e.rawJson ?? e.toJson()));
        offline = true;
      } else {
        error = '$e'.replaceFirst('Exception: ', '');
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = offline;
      _error = lines == null ? error : null;
      if (lines != null) _lines = lines;
      _recompute();
    });
  }

  List<SpendLine> _parse(Iterable<dynamic> raw) => [
    for (final j in raw)
      if (j is Map)
        ?SpendLine.tryParse(j is Map<String, dynamic> ? j : Map<String, dynamic>.from(j)),
  ];

  /// Runs only when the data or the period changes — never in build.
  void _recompute() {
    final lines = _lines;
    _bd = lines == null
        ? null
        : SpendBreakdown.compute(lines, projectId: widget.projectId, from: _period.from, groups: _groups);
  }

  // ── Move to group (display only; never changes entries) ──────────────────

  /// Phone cache first (instant), then the profile copy (source of truth).
  Future<void> _loadGroups() async {
    final uid = UserSession.userId;
    final cached = await _UserGroups.readCache(uid);
    if (cached != null && mounted && !_groupsEdited && !_groupsFromServer) {
      setState(() {
        _groups = cached;
        _recompute();
      });
    }
    final server = await _UserGroups.fetch();
    if (server == null || !mounted) return;
    _groupsFromServer = true;
    if (_groupsEdited) return;
    await _UserGroups.writeCache(uid, server);
    if (!mounted || _groupsEdited) return;
    setState(() {
      _groups = server;
      _recompute();
    });
  }

  /// Applies [next] for [cat] right away, caches it on the phone and saves
  /// the whole map to the profile (the server merges preferences one level
  /// deep, so each category's map is replaced as a whole).
  Future<void> _setGroups(CostCategory cat, Map<String, String> next, String done) =>
      _saveGroups({..._groups, cat: Map.unmodifiable(next)}, [cat], done);

  /// Removes every group in every category ("Clear my groups").
  Future<void> _clearGroups() => _saveGroups(const {}, CostCategory.values, 'Groups cleared — every item shows on its own');

  Future<void> _saveGroups(Map<CostCategory, Map<String, String>> all, List<CostCategory> changed, String done) async {
    setState(() {
      _groups = Map.unmodifiable(all);
      _groupsEdited = true;
      _recompute();
    });
    await _UserGroups.writeCache(UserSession.userId, all);
    final synced = await _UserGroups.save({for (final c in changed) c: all[c] ?? const {}});
    if (!mounted) return;
    btToast(context, synced ? done : '$done — saved on this phone only (couldn\'t reach the server)', error: !synced);
  }

  int get _groupedCount => _groups.values.fold(0, (s, m) => s + m.length);

  /// Distinct name keys of the entries in [g].
  static Set<String> _keysOf(SpendGroup g) => {for (final l in g.lines) entryNameKey(l.name)}..remove('');

  /// The user group [g] is shown under (or [g] itself when it is one).
  String? _parentOf(CostCategory cat, SpendGroup g) {
    for (final p in _bd?.byCategory[cat]?.byName ?? const <SpendGroup>[]) {
      if (p.children.isEmpty) continue;
      if (identical(p, g) || p.children.any((c) => identical(c, g))) return p.name;
    }
    return null;
  }

  /// Long-press menu of an item / group row (top-level or child) in "By
  /// material / labour type / equipment": Move to group…, Remove from group,
  /// Rename (admin). On a change from a pushed page, go back to the tab,
  /// whose groups are already recomputed.
  _RenameCallback _itemMenu(CostCategory cat) {
    final viewRoute = ModalRoute.of(context);
    void backToTab() {
      if (viewRoute != null && mounted) Navigator.of(context).popUntil((r) => r == viewRoute);
    }

    return (pageCtx, g) async {
      final keys = _keysOf(g);
      final mine = _groups[cat] ?? const <String, String>{};
      final moved = keys.any(mine.containsKey);
      final isGroup = g.children.isNotEmpty;
      final canRename = RoleManager.isAdmin && !_offline && g.children.length <= 1;
      final renameTarget = g.children.length == 1 ? g.children.first : g;
      final action = await showModalBottomSheet<String>(
        context: pageCtx,
        sheetAnimationStyle: btSheetStyleDefault(pageCtx),
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (sheetCtx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Ins.gutter, 0, Ins.gutter, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: Ins.t(17, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text('${isGroup ? 'Your group' : cat.label} · ${g.count} ${g.count == 1 ? 'entry' : 'entries'}', style: Ins.t(12.5, c: Ins.ink3)),
              ]),
            ),
            if (keys.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text('Move to group…', style: Ins.t(15, w: FontWeight.w600)),
                subtitle: Text('Only changes how Insights groups it for you — entries stay the same', style: Ins.t(12.5, c: Ins.ink3)),
                onTap: () => Navigator.pop(sheetCtx, 'move'),
              ),
            if (moved)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: Text(isGroup ? 'Ungroup' : 'Remove from group', style: Ins.t(15, w: FontWeight.w600)),
                subtitle: Text(isGroup ? 'Show its ${g.children.length} items on their own again' : 'Show it on its own again',
                    style: Ins.t(12.5, c: Ins.ink3)),
                onTap: () => Navigator.pop(sheetCtx, 'auto'),
              ),
            if (canRename)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Rename', style: Ins.t(15, w: FontWeight.w600)),
                subtitle: Text('Changes the name on its entries', style: Ins.t(12.5, c: Ins.ink3)),
                onTap: () => Navigator.pop(sheetCtx, 'rename'),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      );
      if (action == null || !mounted || !pageCtx.mounted) return;
      switch (action) {
        case 'rename':
          if (await _renameSpendGroup(pageCtx, renameTarget, _RenameField.name) && mounted) {
            backToTab();
            _load();
          }
        case 'move':
          if (await _moveToGroup(pageCtx, cat, g, keys)) backToTab();
        case 'auto':
          final next = Map<String, String>.of(mine)..removeWhere((k, _) => keys.contains(k));
          await _setGroups(cat, next, isGroup ? 'Ungrouped "${g.name}" — entries unchanged' : '"${g.name}" shows on its own again');
          backToTab();
      }
    };
  }

  /// Pick a group (the user's groups, plus common material kinds) or type a
  /// new one; stores an override for every name key in [g]. True when
  /// something changed.
  Future<bool> _moveToGroup(BuildContext ctx, CostCategory cat, SpendGroup g, Set<String> keys) async {
    // Don't overwrite profile overrides we haven't seen yet.
    if (!_groupsFromServer) await _loadGroups();
    if (!mounted || !ctx.mounted) return false;
    final current = _parentOf(cat, g);
    final options = <String>[];
    final seen = <String>{if (current != null) entryNameKey(current)};
    for (final n in [
      for (final p in _bd?.byCategory[cat]?.byName ?? const <SpendGroup>[])
        if (p.children.isNotEmpty) p.name,
      ...?_groups[cat]?.values,
      if (cat == CostCategory.material) ...materialRuleParents.where((p) => p != miscellaneousParent),
    ]) {
      final d = entryNameDisplay(n);
      if (d.isNotEmpty && seen.add(entryNameKey(d))) options.add(d);
    }
    const newGroup = '\u0000new';
    final picked = await showModalBottomSheet<String>(
      context: ctx,
      sheetAnimationStyle: btSheetStyleDefault(ctx),
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * .75),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Ins.gutter, 0, Ins.gutter, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Move "${g.name}" to', style: Ins.t(17, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(current == null ? 'Pick a group' : 'Now in $current', style: Ins.t(12.5, c: Ins.ink3)),
              ]),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                ListTile(
                  leading: const Icon(Icons.add_rounded, color: Ins.primary),
                  title: Text('New group…', style: Ins.t(15, w: FontWeight.w600, c: Ins.primary)),
                  onTap: () => Navigator.pop(sheetCtx, newGroup),
                ),
                for (final o in options)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(o, style: Ins.t(15)),
                    onTap: () => Navigator.pop(sheetCtx, o),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted || !ctx.mounted) return false;
    var target = picked;
    if (picked == newGroup) {
      final typed = await _askGroupName(ctx);
      if (typed == null || !mounted) return false;
      target = options.firstWhere((o) => entryNameKey(o) == entryNameKey(typed), orElse: () => typed);
    }
    final next = {...?_groups[cat], for (final k in keys) k: target};
    await _setGroups(cat, next, 'Moved "${g.name}" to $target — entries unchanged');
    return true;
  }

  void _setPeriod(_Period p) => setState(() {
    _period = _lastPeriod = p;
    _recompute();
  });

  void _setCat(CostCategory c) => setState(() => _cat = _lastCat = c);

  /// A user group with several items opens the item list; a group with one
  /// item (and every plain item) opens the detail page directly.
  void _open(SpendGroup g, String scope) {
    final cat = _cat, period = _period.label;
    final field = scope == 'Worker / contractor' ? _RenameField.party : _RenameField.name;
    final rename = _renameFrom(field);
    final restore = _reloadAfter(_restoreSpendGroup);
    final menu = field == _RenameField.name ? _itemMenu(cat) : null;
    if (g.children.length > 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ChildrenPage(parent: g, category: cat, period: period, onRename: rename, onRestore: restore, onMenu: menu),
        ),
      );
      return;
    }
    final target = g.children.length == 1 ? g.children.first : g;
    final sc = g.children.length == 1 ? g.name : scope;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupEntriesPage(
          group: target,
          category: cat,
          scope: sc,
          period: period,
          onRename: rename,
          onRestore: restore,
          onMenu: menu,
        ),
      ),
    );
  }

  /// Rename from any page opened from this tab: on success, go back to the
  /// tab and reload so the groups reflect the new name.
  _RenameCallback _renameFrom(_RenameField field) => _reloadAfter((c, g) => _renameSpendGroup(c, g, field));

  /// Wraps a rename / undo action for a page opened from this tab: on
  /// success, pop back to the tab and reload.
  _RenameCallback _reloadAfter(Future<bool> Function(BuildContext, SpendGroup) action) {
    final viewRoute = ModalRoute.of(context);
    return (pageCtx, g) async {
      final ok = await action(pageCtx, g);
      if (!ok || !mounted) return;
      if (viewRoute != null) Navigator.of(context).popUntil((r) => r == viewRoute);
      _load();
    };
  }

  /// Admin "Tidy spellings": preview + apply spelling fixes for this project
  /// (or all projects); reload when anything was renamed.
  Future<void> _openTidy() async {
    final lines = _lines ?? const <SpendLine>[];
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TidyNamesPage(projectLines: lines, projectName: widget.projectName),
      ),
    );
    if (changed == true && mounted) {
      context.read<ProjectProvider>().load();
      _load();
    }
  }

  /// "Suggest groups": rule-based proposals for ungrouped materials; the
  /// ticked ones are added to the user's material groups.
  Future<void> _openSuggest() async {
    if (!_groupsFromServer) await _loadGroups();
    if (!mounted) return;
    final mine = _groups[CostCategory.material] ?? const <String, String>{};
    final lines = [
      for (final l in _lines ?? const <SpendLine>[])
        if (l.projectId.isEmpty || l.projectId == widget.projectId) l,
    ];
    final picked = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SuggestGroupsPage(lines: lines, groups: mine, projectName: widget.projectName),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _setCat(CostCategory.material);
    final n = picked.length;
    await _setGroups(CostCategory.material, {...mine, ...picked}, 'Grouped $n ${n == 1 ? 'item' : 'items'} — entries unchanged');
  }

  Future<void> _confirmClearGroups() async {
    final n = _groupedCount;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Clear my groups', style: Ins.t(18, w: FontWeight.w700)),
        content: Text('Show all $n grouped ${n == 1 ? 'item' : 'items'} on their own again? Entries and names stay the same.',
            style: Ins.t(14, c: Ins.ink3)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (yes == true && mounted) await _clearGroups();
  }

  /// "Organise" sheet (chip at the right of the period chips): Suggest groups
  /// (everyone), Tidy spellings (admin, online), Clear my groups.
  Future<void> _openOrganise() async {
    final n = _groupedCount;
    final canTidy = RoleManager.isAdmin;
    final action = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: btSheetStyleDefault(context),
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Ins.gutter, 0, Ins.gutter, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Organise', style: Ins.t(17, w: FontWeight.w600)),
              Text('Items show as entered. Grouping is up to you.', style: Ins.t(12.5, c: Ins.ink3)),
            ]),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined, color: Ins.ink),
            title: Text('Suggest groups', style: Ins.t(15, w: FontWeight.w600)),
            subtitle: Text('Materials into Sand, Cement, Doors & Windows… — you pick', style: Ins.t(12.5, c: Ins.ink3)),
            onTap: () => Navigator.pop(sheetCtx, 'suggest'),
          ),
          if (canTidy)
            ListTile(
              enabled: !_offline,
              leading: Icon(Icons.spellcheck_rounded, color: _offline ? Ins.ink3 : Ins.ink),
              title: Text('Tidy spellings', style: Ins.t(15, w: FontWeight.w600, c: _offline ? Ins.ink3 : Ins.ink)),
              subtitle: Text(_offline ? 'Needs a connection' : 'Fix spaces/capitals on saved names — needs the latest server',
                  style: Ins.t(12.5, c: Ins.ink3)),
              onTap: () => Navigator.pop(sheetCtx, 'tidy'),
            ),
          ListTile(
            enabled: n > 0,
            leading: Icon(Icons.layers_clear_outlined, color: n > 0 ? Ins.bad : Ins.ink3),
            title: Text('Clear my groups', style: Ins.t(15, w: FontWeight.w600, c: n > 0 ? Ins.bad : Ins.ink3)),
            subtitle: Text(n > 0 ? '$n ${n == 1 ? 'item is' : 'items are'} in your groups — show all on their own' : 'You have no groups yet',
                style: Ins.t(12.5, c: Ins.ink3)),
            onTap: () => Navigator.pop(sheetCtx, 'clear'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'suggest':
        await _openSuggest();
      case 'tidy':
        await _openTidy();
      case 'clear':
        await _confirmClearGroups();
    }
  }

  Future<void> _renameHere(SpendGroup g, _RenameField field) async {
    if (await _renameSpendGroup(context, g, field) && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final bd = _bd;
    if (bd == null) {
      if (_loading) {
        return Column(children: [
          for (final h in [44.0, 130.0, 320.0])
            Container(
              height: h,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Ins.muted, borderRadius: BorderRadius.circular(Ins.r)),
            ),
        ]);
      }
      return InsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const InsCardHeader(title: 'Couldn\'t load entries'),
          Text(_error ?? 'Something went wrong.', style: Ins.t(14, c: Ins.ink3)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Ins.primary, minimumSize: const Size(120, Ins.tap)),
            onPressed: _load,
            child: const Text('Try again'),
          ),
        ]),
      );
    }
    final c = bd.byCategory[_cat]!;
    final color = Ins.cat(_cat);
    final nameTitle = switch (_cat) {
      CostCategory.labour => 'By labour type',
      CostCategory.material => 'By material',
      CostCategory.equipment => 'By equipment',
    };
    final nameHint = switch (_cat) {
      CostCategory.labour => 'Painters, masons, tile work… as entered — long-press to group',
      CostCategory.material => 'Each material as entered — long-press to put it in a group',
      CostCategory.equipment => 'Each machine or equipment item — long-press to group',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CatSegment(value: _cat, onChanged: _setCat, totals: {for (final k in CostCategory.values) k: bd.byCategory[k]!.total}),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              itemCount: _Period.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = _Period.values[i];
                return BtChip(label: p.label, selected: p == _period, onTap: () => _setPeriod(p));
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Organise: suggest groups${RoleManager.isAdmin ? ', tidy spellings' : ''}, clear my groups',
          child: ExcludeSemantics(child: BtChip(label: 'Organise', icon: Icons.tune_rounded, onTap: _openOrganise)),
        ),
      ]),
      if (_offline) ...[
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 15, color: Ins.warn),
          const SizedBox(width: 6),
          Expanded(child: Text('Offline — showing the entries saved on this phone.', style: Ins.t(12.5, c: Ins.warn))),
        ]),
      ],
      const SizedBox(height: 12),
      _SummaryCard(data: c, color: color, period: _period.label),
      const SizedBox(height: 12),
      // Top items, from the very same groups the list below shows.
      if (c.byName.isNotEmpty) ...[
        InsTopGroupsChart(
          key: ValueKey('top-${_cat.name}-${_period.name}'),
          title: switch (_cat) {
            CostCategory.labour => 'Top labour types',
            CostCategory.material => 'Top materials',
            CostCategory.equipment => 'Top equipment',
          },
          description: '${_period.label} · tap a bar to open it',
          groups: c.byName,
          color: color,
          onTap: (g) => _open(g, nameTitle.replaceFirst('By ', '')),
          onOthers: () => _scrollToList(context, _listKey),
        ),
        const SizedBox(height: 12),
      ],
      _GroupsCard(
        key: _listKey,
        title: nameTitle,
        description: nameHint,
        groups: c.byName,
        color: color,
        showQty: _cat != CostCategory.labour,
        emptyText: 'No ${_cat.label.toLowerCase()} entries ${_period == _Period.all ? 'yet' : 'in this period'}.',
        onTap: (g) => _open(g, nameTitle.replaceFirst('By ', '')),
        onLongPress: (g) => _itemMenu(_cat)(context, g),
      ),
      if (_cat == CostCategory.labour && c.count > 0) ...[
        const SizedBox(height: 12),
        _GroupsCard(
          title: 'By worker / contractor',
          description: 'Worker on the entry, else the contractor / team',
          groups: c.byPerson,
          color: color,
          showQty: false,
          emptyText: '',
          onTap: (g) => _open(g, 'Worker / contractor'),
          onLongPress: (g) => _renameHere(g, _RenameField.party),
        ),
      ],
    ]);
  }
}

// ── Category segment ────────────────────────────────────────────────────────

class _CatSegment extends StatelessWidget {
  const _CatSegment({required this.value, required this.onChanged, required this.totals});
  final CostCategory value;
  final ValueChanged<CostCategory> onChanged;
  final Map<CostCategory, double> totals;
  static const _order = [CostCategory.labour, CostCategory.material, CostCategory.equipment];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Ins.muted, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final c in _order)
          Expanded(
            child: Semantics(
              button: true,
              selected: c == value,
              label: '${c.label}, ${inrCompact(totals[c] ?? 0)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: Ins.motion,
                  alignment: Alignment.center,
                  decoration: c == value
                      ? BoxDecoration(color: Ins.card, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 3, offset: Offset(0, 1))])
                      : null,
                  child: ExcludeSemantics(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: Ins.cat(c), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(c == CostCategory.material ? 'Materials' : c.label,
                              overflow: TextOverflow.ellipsis,
                              style: Ins.t(13.5, w: c == value ? FontWeight.w600 : FontWeight.w500, c: c == value ? Ins.ink : Ins.ink3)),
                        ),
                      ]),
                      Text(inrCompact(totals[c] ?? 0), style: Ins.t(11.5, c: Ins.ink3, h: 1.2)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Summary ─────────────────────────────────────────────────────────────────

class _PaidBar extends StatelessWidget {
  const _PaidBar({required this.paid, required this.pending, required this.color, this.height = 10, this.fraction = 1});
  final double paid, pending, fraction, height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = paid + pending;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final filled = (w * fraction.clamp(0.0, 1.0)).clamp(total > 0 ? 3.0 : 0.0, w);
      final paidW = total > 0 ? filled * paid / total : 0.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: Ins.muted,
          alignment: Alignment.centerLeft,
          child: Row(children: [
            Container(width: paidW, color: color),
            Container(width: filled - paidW, color: color.withValues(alpha: .32)),
          ]),
        ),
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.color, required this.period});
  final SpendCategoryBreakdown data;
  final Color color;
  final String period;

  @override
  Widget build(BuildContext context) {
    final paidPct = data.total > 0 ? (data.paid / data.total * 100).round() : 0;
    return InsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Ins.catIcon(data.category), size: 18, color: color),
          const SizedBox(width: 6),
          Text('${data.category.label.toUpperCase()} SPEND · ${period.toUpperCase()}', style: Ins.overline()),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(inrFull(data.total), style: Ins.num(28))),
          Text('${data.count} ${data.count == 1 ? 'entry' : 'entries'}', style: Ins.t(13, c: Ins.ink3)),
        ]),
        const SizedBox(height: 12),
        _PaidBar(paid: data.paid, pending: data.pending, color: color),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Stat(label: 'Paid', value: inrCompact(data.paid), sub: data.total > 0 ? '$paidPct%' : null, swatch: color)),
          Expanded(child: _Stat(label: 'To pay', value: inrCompact(data.pending), sub: data.total > 0 ? '${100 - paidPct}%' : null, swatch: color.withValues(alpha: .32))),
        ]),
        if (data.awaitingApproval > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.hourglass_empty_rounded, size: 15, color: Ins.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Includes ${data.awaitingApproval} ${data.awaitingApproval == 1 ? 'entry' : 'entries'} awaiting approval. Rejected entries are left out.',
                style: Ins.t(12.5, c: Ins.ink3),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.sub, required this.swatch});
  final String label, value;
  final String? sub;
  final Color swatch;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: Ins.t(12.5, c: Ins.ink2)),
    ]),
    const SizedBox(height: 2),
    Text.rich(TextSpan(children: [
      TextSpan(text: value, style: Ins.num(16)),
      if (sub != null) TextSpan(text: '  $sub', style: Ins.t(12, c: Ins.ink3)),
    ])),
  ]);
}

// ── Group list ──────────────────────────────────────────────────────────────

String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(q.abs() < 10 ? 2 : 1).replaceFirst(RegExp(r'\.?0+$'), '');

/// Bring the list card behind [key] into view (the chart's "Others" bar).
void _scrollToList(BuildContext context, GlobalKey key) {
  final target = key.currentContext;
  if (target == null) return;
  Scrollable.ensureVisible(
    target,
    alignment: .04,
    duration: Bt.reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
  );
}

class _GroupsCard extends StatefulWidget {
  const _GroupsCard({
    super.key,
    required this.title,
    required this.description,
    required this.groups,
    required this.color,
    required this.showQty,
    required this.emptyText,
    required this.onTap,
    this.onLongPress,
  });
  final String title, description, emptyText;
  final List<SpendGroup> groups;
  final Color color;
  final bool showQty;
  final ValueChanged<SpendGroup> onTap;
  final ValueChanged<SpendGroup>? onLongPress;

  @override
  State<_GroupsCard> createState() => _GroupsCardState();
}

class _GroupsCardState extends State<_GroupsCard> {
  static const _collapsed = 8;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final shown = _all || groups.length <= _collapsed + 2 ? groups : groups.take(_collapsed).toList();
    final top = groups.isEmpty ? 1.0 : groups.map((g) => g.amount).reduce(math.max);
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InsCardHeader(title: widget.title, description: widget.description),
        if (groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 14, runSpacing: 6, children: [
              InsSwatch(color: widget.color, label: 'Paid'),
              InsSwatch(color: widget.color.withValues(alpha: .32), label: 'To pay'),
            ]),
          ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(widget.emptyText, style: Ins.t(14, c: Ins.ink3)),
          ),
        for (var i = 0; i < shown.length; i++)
          _GroupRow(rank: i + 1, group: shown[i], color: widget.color, fraction: shown[i].amount / top, showQty: widget.showQty, onTap: () => widget.onTap(shown[i]),
              onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(shown[i])),
        if (shown.length < groups.length)
          InkWell(
            onTap: () => setState(() => _all = true),
            child: Container(
              constraints: const BoxConstraints(minHeight: Ins.tap),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ins.border))),
              alignment: Alignment.center,
              child: Text('Show all ${groups.length}', style: Ins.t(14, w: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.rank, required this.group, required this.color, required this.fraction, required this.showQty, required this.onTap, this.onLongPress});
  final int rank;
  final SpendGroup group;
  final Color color;
  final double fraction;
  final bool showQty;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final meta = <String>[
      '${(g.share * 100).toStringAsFixed(g.share < .01 && g.share > 0 ? 1 : 0)}% of total',
      if (g.children.length > 1) '${g.children.length} types',
      '${g.count} ${g.count == 1 ? 'entry' : 'entries'}',
      if (showQty && g.quantity != null) '${_qty(g.quantity!)} ${g.unit}',
      if (showQty && g.avgRate != null) 'avg ${inrCompact(g.avgRate!)}/${g.unit}',
    ];
    return Semantics(
      button: true,
      label: '${g.name}, ${inrFull(g.amount)}, ${meta.join(', ')}, ${inrFull(g.pending)} to pay',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ins.border))),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ExcludeSemantics(
            child: Row(children: [
              SizedBox(width: 22, child: Text('$rank', style: Ins.mono(13, c: Ins.ink3))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(g.name, style: Ins.t(14, w: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text(inrCompact(g.amount), style: Ins.num(14)),
                  ]),
                  const SizedBox(height: 6),
                  _PaidBar(paid: g.paid, pending: g.pending, color: color, height: 6, fraction: fraction),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: Text(meta.join(' · '), style: Ins.t(11.5, c: Ins.ink3), overflow: TextOverflow.ellipsis)),
                    if (g.pending > 0.5) Text('${inrCompact(g.pending)} to pay', style: Ins.t(11.5, c: Ins.warn, w: FontWeight.w600)),
                  ]),
                ]),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Ins.ink3),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Pages: shared chrome ───────────────────────────────────────────────────

PreferredSizeWidget _insAppBar(String title, String subtitle, {List<Widget>? actions}) => AppBar(
  actions: actions,
  toolbarHeight: 64,
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.white,
  scrolledUnderElevation: 0,
  elevation: 0,
  shape: const Border(bottom: BorderSide(color: Ins.border)),
  foregroundColor: Ins.ink,
  titleSpacing: 0,
  title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Ins.t(17, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
    Text(subtitle, style: Ins.t(12.5, c: Ins.ink3), overflow: TextOverflow.ellipsis),
  ]),
);

/// ₹ with paise only for small fractional rates (₹7.50/kg), else whole rupees.
String _rate(double r) => r < 100 && r != r.roundToDouble() ? '₹${r.toStringAsFixed(2)}' : inrFull(r);

/// Total, paid / to pay, entries, quantity + average rate of one group.
class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.group, required this.category});
  final SpendGroup group;
  final CostCategory category;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final color = Ins.cat(category);
    final paidPct = g.amount > 0 ? (g.paid / g.amount * 100).round() : 0;
    final mixedUnits = g.quantity == null && g.lines.any((l) => l.quantity > 0);
    final units = mixedUnits
        ? (g.lines.map((l) => l.unit.trim()).where((u) => u.isNotEmpty).toSet().toList()..sort()).join(', ')
        : '';
    return InsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TOTAL SPENT', style: Ins.overline()),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(inrFull(g.amount), style: Ins.num(26))),
          Text('${(g.share * 100).toStringAsFixed(g.share < .01 && g.share > 0 ? 1 : 0)}% of ${category.label.toLowerCase()}',
              style: Ins.t(13, c: Ins.ink3)),
        ]),
        const SizedBox(height: 12),
        _PaidBar(paid: g.paid, pending: g.pending, color: color),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Stat(label: 'Paid', value: inrCompact(g.paid), sub: g.amount > 0 ? '$paidPct%' : null, swatch: color)),
          Expanded(
            child: _Stat(
              label: 'To pay',
              value: inrCompact(g.pending),
              sub: g.amount > 0 ? '${100 - paidPct}%' : null,
              swatch: color.withValues(alpha: .32),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: Ins.border),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Fact(label: 'Entries', value: '${g.count}')),
          Expanded(child: _Fact(label: 'Total quantity', value: g.quantity != null ? '${_qty(g.quantity!)} ${g.unit}' : '—')),
          Expanded(child: _Fact(label: 'Average rate', value: g.avgRate != null ? '${_rate(g.avgRate!)}/${g.unit}' : '—')),
        ]),
        if (mixedUnits) ...[
          const SizedBox(height: 8),
          Text('Entries use different units${units.isEmpty ? '' : ' ($units)'}, so quantity isn\'t added up.',
              style: Ins.t(12.5, c: Ins.ink3)),
        ],
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color = Ins.ink});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Ins.t(11.5, c: Ins.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(value, style: Ins.num(14, c: color), maxLines: 1),
    ),
  ]);
}

// ── Items inside one of the user's groups (Sand → M-Sand, P Sand, …) ───────

class _ChildrenPage extends StatefulWidget {
  const _ChildrenPage({required this.parent, required this.category, required this.period, this.onRename, this.onRestore, this.onMenu});
  final SpendGroup parent;
  final CostCategory category;
  final String period;
  final _RenameCallback? onRename, onRestore;

  /// Long-press menu (Move to group… / Remove from group / Rename).
  final _RenameCallback? onMenu;

  @override
  State<_ChildrenPage> createState() => _ChildrenPageState();
}

class _ChildrenPageState extends State<_ChildrenPage> {
  final GlobalKey _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final category = widget.category;
    final period = widget.period;
    final onRename = widget.onRename, onRestore = widget.onRestore, onMenu = widget.onMenu;
    return Scaffold(
      backgroundColor: Ins.bg,
      appBar: _insAppBar(parent.name, '${category.label} · $period'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 32),
        children: [
          _GroupHeaderCard(group: parent, category: category),
          const SizedBox(height: 12),
          InsTopGroupsChart(
            title: 'Split of ${parent.name}',
            description: 'What is inside this group · tap a bar to see its entries',
            groups: parent.children,
            color: Ins.cat(category),
            drill: true,
            onOthers: () => _scrollToList(context, _listKey),
            onTap: (c) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _GroupEntriesPage(
                  group: c,
                  category: category,
                  scope: parent.name,
                  period: period,
                  onRename: onRename,
                  onRestore: onRestore,
                  onMenu: onMenu,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GroupsCard(
            key: _listKey,
            title: 'Inside ${parent.name}',
            description: onMenu != null ? 'Tap one to see its entries · long-press to move it' : 'Tap one to see its entries',
            groups: parent.children,
            color: Ins.cat(category),
            showQty: true,
            emptyText: '',
            onTap: (c) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _GroupEntriesPage(
                  group: c,
                  category: category,
                  scope: parent.name,
                  period: period,
                  onRename: onRename,
                  onRestore: onRestore,
                  onMenu: onMenu,
                ),
              ),
            ),
            onLongPress: onMenu != null
                ? (c) => onMenu(context, c)
                : onRename == null
                ? null
                : (c) => onRename(context, c),
          ),
        ],
      ),
    );
  }
}

// ── Drill-down chart: one group's entries split by its children ────────────

/// Labour type → workers; worker → labour types; material / equipment →
/// suppliers. Same grouping as the lists (spelling variants merged). Empty
/// when nothing was recorded to split by.
List<Widget> _splitChart(SpendGroup g, CostCategory category, String scope) {
  final byPerson = category == CostCategory.labour && scope == 'Worker / contractor';
  final String title, description, fallback;
  final String Function(SpendLine) nameOf;
  if (byPerson) {
    title = 'Labour types for ${g.name}';
    description = 'Spend by type of work';
    fallback = 'Unnamed';
    nameOf = (l) => l.name;
  } else if (category == CostCategory.labour) {
    title = 'Workers in ${g.name}';
    description = 'Spend by worker / contractor';
    fallback = 'Not recorded';
    nameOf = (l) => l.party;
  } else {
    title = 'Suppliers for ${g.name}';
    description = 'Spend by supplier';
    fallback = 'No supplier';
    nameOf = (l) => l.party;
  }
  final parts = SpendBreakdown.splitLines(g.lines, nameOf, fallback);
  // One bucket that is just "not recorded" says nothing — leave it out.
  if (parts.isEmpty || (parts.length == 1 && parts.first.name == fallback)) return const [];
  return [
    InsTopGroupsChart(key: ValueKey('split-${g.name}'), title: title, description: description, groups: parts, color: Ins.cat(category), drill: true),
    const SizedBox(height: 12),
  ];
}

// ── Detail of one group: header + entries (like Reports) ────────────────────

class _GroupEntriesPage extends StatelessWidget {
  const _GroupEntriesPage({
    required this.group,
    required this.category,
    required this.scope,
    required this.period,
    this.onRename,
    this.onRestore,
    this.onMenu,
  });
  final SpendGroup group;
  final CostCategory category;
  final String scope;
  final String period;
  final _RenameCallback? onRename;

  /// "Undo rename": puts back the original names of renamed entries.
  final _RenameCallback? onRestore;

  /// Move to group… / Remove from group / Rename.
  final _RenameCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final g = group;
    // Show each entry's own name when the group merges different names
    // (e.g. Sand → "Sand", "Fine sand", or a worker's several labour types).
    final showName = g.lines.map((l) => entryNameKey(l.name)).toSet().length > 1;
    final renamed = g.lines.any((l) => l.originalName.isNotEmpty);
    return Scaffold(
      backgroundColor: Ins.bg,
      appBar: _insAppBar(g.name, '${category.label} · $scope · $period', actions: [
        if (onRestore != null && renamed && RoleManager.isAdmin)
          IconButton(
            tooltip: 'Undo rename',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => onRestore!(context, g),
          ),
        if (onMenu != null)
          IconButton(
            tooltip: 'Move to group',
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: () => onMenu!(context, g),
          ),
        if (onRename != null && RoleManager.isAdmin)
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => onRename!(context, g),
          ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 32),
        children: [
          _GroupHeaderCard(group: g, category: category),
          const SizedBox(height: 12),
          ..._splitChart(g, category, scope),
          InsCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InsCardHeader(title: '${g.count} ${g.count == 1 ? 'entry' : 'entries'}', description: 'Newest first · tap an entry to open it'),
              for (final l in g.lines) _EntryRow(line: l, showName: showName),
            ]),
          ),
        ],
      ),
    );
  }
}

/// One entry, Reports columns stacked for a phone: date + amount + status,
/// floor/phase/activity, supplier or worker, then Qty · Rate · Paid · Remaining.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.line, required this.showName});
  final SpendLine line;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final party = l.party;
    final partyLabel = l.category == CostCategory.labour ? 'Worker' : 'Supplier';
    final title = [
      l.date != null ? dateShort.format(l.date!) : 'No date',
      if (showName && l.name.isNotEmpty) entryNameDisplay(l.name),
    ].join(' · ');
    final place = l.place;
    final rate = l.rate;
    final wasName = l.originalName.isNotEmpty && entryNameKey(l.originalName) != entryNameKey(l.name)
        ? entryNameDisplay(l.originalName)
        : null;
    final status = l.paid >= l.amount - 0.5
        ? (fg: Ins.good, bg: Ins.goodSoft, label: 'Paid')
        : l.paid > 0
        ? (fg: Ins.warn, bg: Ins.warnSoft, label: 'Partial')
        : (fg: Ins.ink3, bg: Ins.muted, label: 'To pay');
    return Semantics(
      button: l.id.isNotEmpty,
      label: '$title${wasName != null ? ', was $wasName' : ''}, ${inrFull(l.amount)}, ${status.label}'
          '${place.isNotEmpty ? ', $place' : ''}${party.isNotEmpty ? ', $partyLabel $party' : ''}'
          ', paid ${inrFull(l.paid)}, remaining ${inrFull(l.pending)}',
      child: InkWell(
        onTap: l.id.isEmpty ? null : () => Navigator.pushNamed(context, '/entry-detail', arguments: _entryDetailArgs(l)),
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ins.border))),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ExcludeSemantics(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: Ins.t(14, w: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (wasName != null)
                          Text('Was: $wasName', style: Ins.t(12, c: Ins.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(place.isEmpty ? 'No floor / phase' : place,
                            style: Ins.t(12.5, c: Ins.ink3), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (party.isNotEmpty)
                          Text('$partyLabel: $party', style: Ins.t(12.5, c: Ins.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(inrFull(l.amount), style: Ins.num(15)),
                      const SizedBox(height: 4),
                      InsBadge(label: status.label, fg: status.fg, bg: status.bg),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _Fact(label: 'Qty', value: l.quantity > 0 ? '${_qty(l.quantity)} ${l.unit}'.trim() : '—')),
                    Expanded(child: _Fact(label: 'Rate', value: rate != null ? _rate(rate) : '—')),
                    Expanded(child: _Fact(label: 'Paid', value: inrFull(l.paid))),
                    Expanded(child: _Fact(label: 'Remaining', value: inrFull(l.pending), color: l.pending > 0.5 ? Ins.warn : Ins.ink)),
                  ]),
                  if (!l.approved) ...[
                    const SizedBox(height: 6),
                    Text('Awaiting approval', style: Ins.t(12, c: Ins.warn)),
                  ],
                ]),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: Ins.ink3),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Transaction JSON → `/entry-detail` arguments (same shape the inbox uses;
/// the detail screen refetches the entry by id).
Map<String, dynamic> _entryDetailArgs(SpendLine l) {
  final tx = l.raw;
  double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  final isPositive = '${tx['subType'] ?? ''}'.toLowerCase() != 'consumption';
  final project = tx['project'];
  final projectName = project is Map ? project['projectName']?.toString() : null;
  final createdBy = tx['createdBy'];
  final approval = '${tx['approvalStatus'] ?? ''}'.toLowerCase();
  final payStatus = l.paid >= l.amount - 0.5
      ? PaymentStatus.paid
      : l.paid > 0
      ? PaymentStatus.partial
      : PaymentStatus.pending;
  final attachments = tx['attachments'];
  final title = l.name.isEmpty ? 'Entry' : l.name;
  return {
    ...tx,
    'id': l.id,
    'title': title,
    'name': title,
    'ref': l.id.length > 4 ? '#${l.id.substring(l.id.length - 4)}' : '#${l.id}',
    'amount': '${isPositive ? '+' : '-'}${tx['quantity'] ?? 0}',
    'date': tx['date']?.toString() ?? '',
    'isPositive': isPositive,
    'type': l.category.key,
    'receipt': (attachments is List && attachments.isNotEmpty) ? attachments.first?.toString() : null,
    'attachment': null,
    'createdBy': createdBy is Map ? '${createdBy['_id'] ?? ''}' : '${createdBy ?? ''}',
    'project': l.projectId,
    'projectId': l.projectId,
    'projectName': ?projectName,
    'status': approval == 'approved' ? 'approved' : (approval == 'rejected' ? 'rejected' : 'pending'),
    'paymentStatus': payStatus,
    'billAmount': l.amount,
    'paidAmount': l.paid,
    'supplier': tx['supplier'] ?? '',
    'paymentMethod': tx['paymentMode'] ?? '',
    'lastUpdated': tx['updatedAt'] ?? tx['date'] ?? '',
    'paymentHistory': tx['paymentHistory'],
    'rate': d(tx['rate'] ?? tx['ratePerUnit']),
    'brand': tx['brand'] ?? '',
    'notes': tx['notes'] ?? '',
    'remarks': tx['remarks'] ?? '',
    'categoryName': tx['category'] ?? '',
    'quantity': l.quantity,
    'overtime': d(tx['overtime']),
    'subType': tx['subType'] ?? '',
    'materialType': tx['materialType'] ?? '',
    'floor': tx['floor']?.toString(),
    'phase': tx['phase']?.toString(),
    'activity': tx['activity']?.toString(),
    'paymentReceipt': tx['paymentReceipt']?.toString(),
  };
}


// ── Rename a group (fix a name on every entry in it) ────────────────────────

enum _RenameField { name, party }

typedef _RenameCallback = Future<void> Function(BuildContext pageContext, SpendGroup group);

/// Renames every entry in [g]: the entry's name (labour type / material /
/// equipment) or, for "By worker / contractor", the contractor / team field.
/// One POST /transactions/rename per field — it changes only the name, never
/// amounts / payments / dates, and title renames keep the old name so they
/// can be undone. Admin only.
Future<bool> _renameSpendGroup(BuildContext context, SpendGroup g, _RenameField field) async {
  if (!RoleManager.isAdmin) {
    btToast(context, 'Only an admin can rename entries.', error: true);
    return false;
  }
  if (g.children.length > 1) {
    btToast(context, '${g.name} holds ${g.children.length} items — open it and rename each one.', error: true);
    return false;
  }
  final lines = (g.children.length == 1 ? g.children.first.lines : g.lines).where((l) => l.id.isNotEmpty).toList();
  // Server field → entry ids. Worker names picked from the team list live on
  // the person, not the entry, so those entries are skipped.
  final byField = <String, List<String>>{};
  var teamWorkers = 0;
  for (final l in lines) {
    if (field == _RenameField.name) {
      (byField['title'] ??= []).add(l.id);
    } else if (l.worker.isNotEmpty && l.worker != l.contractor) {
      teamWorkers++;
    } else {
      final raw = l.raw;
      final key = (raw['category'] ?? '').toString().trim().isNotEmpty && l.category == CostCategory.labour
          ? 'category'
          : (raw['contractor'] ?? '').toString().trim().isNotEmpty
              ? 'contractor'
              : 'supplier';
      (byField[key] ??= []).add(l.id);
    }
  }
  final total = byField.values.fold(0, (s, ids) => s + ids.length);
  if (total == 0) {
    btToast(context, '"${g.name}" is a team member — change the name in Team Overview.', error: true);
    return false;
  }
  final newName = await _askNewName(context, g.name, total, field);
  if (newName == null || !context.mounted) return false;

  showEntryNamesBusy(context, 'Renaming $total ${total == 1 ? 'entry' : 'entries'}…');
  var ok = 0, failed = 0, serverSkipped = 0;
  String? error;
  for (final e in byField.entries) {
    final r = await renameEntriesOnServer(ids: e.value, field: e.key, to: newName);
    if (r.ok) {
      ok += r.done;
      serverSkipped += r.skipped.length;
    } else {
      failed += e.value.length;
      error ??= r.error;
    }
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (!context.mounted) return ok > 0;
  final skipped = [
    if (teamWorkers > 0) '$teamWorkers team-member entries left as they are',
    if (serverSkipped > 0) '$serverSkipped skipped',
  ].map((s) => ' · $s').join();
  if (error == null) {
    btToast(context, 'Renamed $ok ${ok == 1 ? 'entry' : 'entries'} to "$newName"$skipped');
  } else if (ok == 0) {
    btToast(context, error, error: true);
  } else {
    btToast(context, 'Renamed $ok, $failed not renamed: $error$skipped', error: true);
  }
  if (ok > 0) context.read<ProjectProvider>().load();
  return ok > 0;
}

/// "Undo rename" on a detail page: puts back the original names of the
/// renamed entries in [g]. Admin only.
Future<bool> _restoreSpendGroup(BuildContext context, SpendGroup g) async {
  if (!RoleManager.isAdmin) {
    btToast(context, 'Only an admin can undo a rename.', error: true);
    return false;
  }
  final ids = [for (final l in g.lines) if (l.id.isNotEmpty && l.originalName.isNotEmpty) l.id];
  if (ids.isEmpty) return false;
  final n = ids.length;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Undo rename', style: Ins.t(18, w: FontWeight.w700)),
      content: Text('Put back the original names on $n ${n == 1 ? 'entry' : 'entries'}?', style: Ins.t(14, c: Ins.ink3)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Put back')),
      ],
    ),
  );
  if (yes != true || !context.mounted) return false;
  showEntryNamesBusy(context, 'Putting back $n ${n == 1 ? 'name' : 'names'}…');
  final r = await restoreEntryNamesOnServer(ids);
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (!context.mounted) return r.ok && r.done > 0;
  if (!r.ok) {
    btToast(context, r.error!, error: true);
    return false;
  }
  btToast(context, 'Put back the original name on ${r.done} ${r.done == 1 ? 'entry' : 'entries'}');
  if (r.done > 0) context.read<ProjectProvider>().load();
  return r.done > 0;
}

Future<String?> _askNewName(BuildContext context, String current, int count, _RenameField field) {
  final ctrl = TextEditingController(text: current);
  ctrl.selection = TextSelection(baseOffset: 0, extentOffset: current.length);
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          final v = ctrl.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (v.isEmpty) return setState(() => error = 'Enter a name');
          if (v == current) return setState(() => error = 'That is the current name');
          Navigator.pop(ctx, v);
        }
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(field == _RenameField.party ? 'Rename worker / contractor' : 'Rename', style: Ins.t(18, w: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Changes "$current" on $count ${count == 1 ? 'entry' : 'entries'}. Entries with the new name are grouped together.',
                style: Ins.t(14, c: Ins.ink3)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(labelText: 'New name', errorText: error, border: const OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: submit, child: const Text('Rename')),
          ],
        );
      },
    ),
  ).whenComplete(ctrl.dispose);
}

/// "New group…" name (trimmed, spaces collapsed, ≤ 40 characters).
Future<String?> _askGroupName(BuildContext context) {
  final ctrl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          final v = entryNameDisplay(ctrl.text);
          if (entryNameKey(v).isEmpty) return setState(() => error = 'Enter a group name');
          if (v.length > 40) return setState(() => error = 'Keep it under 40 characters');
          Navigator.pop(ctx, v);
        }
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('New group', style: Ins.t(18, w: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Only you see this grouping. Entries keep their names.', style: Ins.t(14, c: Ins.ink3)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(labelText: 'Group name', hintText: 'e.g. Glass', errorText: error, border: const OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: submit, child: const Text('Move')),
          ],
        );
      },
    ),
  ).whenComplete(ctrl.dispose);
}

// ── User groups store: profile preferences + phone cache ───────────────────
//
// GET /users/profile → user.preferences.{material,labour,equipment}Groups;
// PUT /users/profile {preferences: {materialGroups: {...whole map...}}}. The
// server merges preferences one level deep, so each changed category's whole
// map is sent (other categories are untouched). Phone cache per category:
// SharedPreferences `<cat>Groups_<userId>` (materialGroups_<uid> as before).

abstract final class _UserGroups {
  static String _field(CostCategory c) => '${c.key}Groups';
  static String _prefKey(CostCategory c, String uid) => '${_field(c)}_$uid';

  static Map<String, String> _clean(dynamic v) => {
    if (v is Map)
      for (final e in v.entries)
        if (entryNameKey('${e.key}').isNotEmpty && e.value is String && (e.value as String).trim().isNotEmpty)
          entryNameKey('${e.key}'): entryNameDisplay(e.value as String),
  };

  /// Null when nothing is cached for any category.
  static Future<Map<CostCategory, Map<String, String>>?> readCache(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final out = <CostCategory, Map<String, String>>{};
      for (final c in CostCategory.values) {
        final raw = prefs.getString(_prefKey(c, uid));
        if (raw != null) out[c] = _clean(jsonDecode(raw));
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeCache(String uid, Map<CostCategory, Map<String, String>> all) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final c in CostCategory.values) {
        await prefs.setString(_prefKey(c, uid), jsonEncode(all[c] ?? const <String, String>{}));
      }
    } catch (_) {}
  }

  /// Null when the profile couldn't be read (keep what we have).
  static Future<Map<CostCategory, Map<String, String>>?> fetch() async {
    try {
      final res = await ApiService.get('/users/profile', timeout: const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      final user = body is Map ? body['user'] : null;
      final prefs = user is Map ? user['preferences'] : null;
      return {
        for (final c in CostCategory.values) c: _clean(prefs is Map ? prefs[_field(c)] : null),
      };
    } catch (_) {
      return null;
    }
  }

  /// Saves the whole map of each category in [changed], in one call.
  static Future<bool> save(Map<CostCategory, Map<String, String>> changed) async {
    try {
      final res = await ApiService.put('/users/profile', {
        'preferences': {for (final e in changed.entries) _field(e.key): e.value},
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
