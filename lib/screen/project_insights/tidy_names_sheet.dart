import 'dart:convert';

import 'package:buildtrack_mobile/common/utils/entry_names.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';

// ── Server calls: rename / restore entry names ──────────────────────────────
//
// POST /transactions/rename {ids, field, to} and
// POST /transactions/rename/restore {ids}. Admin only. They change only the
// name field — never amounts, payments or dates (a PUT /transactions/:id
// recalculates those, which is why renaming doesn't use it).

/// Outcome of one rename / restore call. [error] is a message for the user
/// when the call failed as a whole; [done] is how many entries changed.
class EntryNameResult {
  final int done;
  final List<String> skipped;
  final String? error;
  const EntryNameResult({this.done = 0, this.skipped = const [], this.error});
  bool get ok => error == null;
}

const String _serverUpdateMsg = 'The server needs an update before renaming';

EntryNameResult _readResult(int status, String body, String countKey) {
  Map<String, dynamic>? json;
  try {
    final d = jsonDecode(body);
    if (d is Map) json = Map<String, dynamic>.from(d);
  } catch (_) {}
  if (status == 200) {
    final n = json?[countKey];
    final skipped = json?['skipped'];
    return EntryNameResult(
      done: n is num ? n.toInt() : int.tryParse('$n') ?? 0,
      skipped: skipped is List ? [for (final s in skipped) '$s'] : const [],
    );
  }
  // An older server has no such route: never fall back to PUT (it would
  // recalculate amounts), just say the server must be updated.
  if (status == 404 && body.contains('Route not found')) return const EntryNameResult(error: _serverUpdateMsg);
  if (status == 403) return const EntryNameResult(error: 'Only an admin can rename entries.');
  final msg = '${json?['message'] ?? json?['error'] ?? ''}'.trim();
  return EntryNameResult(error: msg.isNotEmpty ? msg : 'Couldn\'t rename (error $status). Try again.');
}

/// Sets [field] ('title' | 'category' | 'supplier' | 'contractor') to [to] on
/// every entry in [ids], in one call.
Future<EntryNameResult> renameEntriesOnServer({required List<String> ids, required String field, required String to}) async {
  if (ids.isEmpty) return const EntryNameResult();
  try {
    final res = await ApiService.post('/transactions/rename', {'ids': ids, 'field': field, 'to': to});
    return _readResult(res.statusCode, res.body, 'updated');
  } catch (_) {
    return const EntryNameResult(error: 'Couldn\'t reach the server. Check the connection and try again.');
  }
}

/// Puts back the original title on every entry in [ids].
Future<EntryNameResult> restoreEntryNamesOnServer(List<String> ids) async {
  if (ids.isEmpty) return const EntryNameResult();
  try {
    final res = await ApiService.post('/transactions/rename/restore', {'ids': ids});
    return _readResult(res.statusCode, res.body, 'restored');
  } catch (_) {
    return const EntryNameResult(error: 'Couldn\'t reach the server. Check the connection and try again.');
  }
}

/// Non-dismissable "working…" dialog; close it with
/// `Navigator.of(context, rootNavigator: true).pop()`.
void showEntryNamesBusy(BuildContext context, String text) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: Ins.t(15))),
        ]),
      ),
    ),
  );
}

// ── Proposals (same rules as the backend cleanup script) ───────────────────

/// Entries of one kind spelled [from] that should be called [to].
class TidyProposal {
  final CostCategory kind;
  final String from, to;
  final List<SpendLine> lines;
  TidyProposal(this.kind, this.from, this.to, this.lines);
  double get amount => lines.fold(0.0, (s, l) => s + l.amount);
}

/// The entry's title as stored (the rename compares against this).
String _title(SpendLine l) {
  final t = l.raw['title'];
  return t == null ? l.name : '$t';
}

/// For each kind: target = (materials) the rule's simple child name when one
/// matches, else the most common spelling among entries with the same
/// [entryNameKey]. Proposed only where target != current title.
List<TidyProposal> computeTidyProposals(Iterable<SpendLine> lines) {
  final out = <TidyProposal>[];
  for (final kind in const [CostCategory.labour, CostCategory.material, CostCategory.equipment]) {
    final ofKind = [
      for (final l in lines)
        if (l.category == kind && l.id.isNotEmpty && entryNameKey(_title(l)).isNotEmpty) l,
    ];
    final byKey = <String, List<SpendLine>>{};
    for (final l in ofKind) {
      (byKey[entryNameKey(_title(l))] ??= []).add(l);
    }
    final common = {for (final e in byKey.entries) e.key: mostCommonSpelling(e.value.map(_title))};
    // (from, to) → lines
    final moves = <String, Map<String, List<SpendLine>>>{};
    for (final l in ofKind) {
      final current = _title(l);
      final target = (kind == CostCategory.material ? classifyMaterial(current).child : null) ?? common[entryNameKey(current)];
      if (target == null || target == current) continue;
      ((moves[target] ??= {})[current] ??= []).add(l);
    }
    for (final t in moves.entries) {
      for (final f in t.value.entries) {
        out.add(TidyProposal(kind, f.key, t.key, f.value));
      }
    }
  }
  for (final kind in CostCategory.values) {
    // Largest first inside each kind; kinds keep their order.
    final idx = out.indexWhere((p) => p.kind == kind);
    if (idx < 0) continue;
    final end = out.lastIndexWhere((p) => p.kind == kind) + 1;
    final part = out.sublist(idx, end)..sort((a, b) => b.amount.compareTo(a.amount));
    out.replaceRange(idx, end, part);
  }
  return out;
}

// ── Page ────────────────────────────────────────────────────────────────────

/// Full-screen "Tidy names" page. Pops with true when something was renamed.
class TidyNamesPage extends StatefulWidget {
  const TidyNamesPage({super.key, required this.projectLines, this.projectName});

  /// The current project's entries (already parsed by the By type tab).
  final List<SpendLine> projectLines;
  final String? projectName;

  @override
  State<TidyNamesPage> createState() => _TidyNamesPageState();
}

class _TidyNamesPageState extends State<TidyNamesPage> {
  bool _allProjects = false;
  bool _loadingAll = false;
  String? _allError;
  List<SpendLine>? _allLines;
  late List<TidyProposal> _proposals;
  final Set<TidyProposal> _ticked = {};

  @override
  void initState() {
    super.initState();
    _setProposals(widget.projectLines);
  }

  void _setProposals(List<SpendLine> lines) {
    _proposals = computeTidyProposals(lines);
    _ticked
      ..clear()
      ..addAll(_proposals);
  }

  Future<void> _toggleAll(bool v) async {
    setState(() {
      _allProjects = v;
      _allError = null;
      if (!v) _setProposals(widget.projectLines);
    });
    if (!v) return;
    if (_allLines != null) return setState(() => _setProposals(_allLines!));
    setState(() => _loadingAll = true);
    try {
      final raw = await ApiService.fetchMaterials(projectId: null);
      final lines = [
        for (final j in raw)
          if (j is Map) ?SpendLine.tryParse(j is Map<String, dynamic> ? j : Map<String, dynamic>.from(j)),
      ];
      if (!mounted) return;
      setState(() {
        _loadingAll = false;
        _allLines = lines;
        if (_allProjects) _setProposals(lines);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAll = false;
        _allError = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  int get _tickedEntries => _ticked.fold(0, (s, p) => s + p.lines.length);

  Future<void> _apply() async {
    // One call per target name.
    final byTarget = <String, List<String>>{};
    for (final p in _ticked) {
      (byTarget[p.to] ??= []).addAll(p.lines.map((l) => l.id));
    }
    if (byTarget.isEmpty) return;
    final total = _tickedEntries;
    showEntryNamesBusy(context, 'Renaming $total ${total == 1 ? 'entry' : 'entries'}…');
    var done = 0, failed = 0;
    String? error;
    for (final e in byTarget.entries) {
      final r = await renameEntriesOnServer(ids: e.value.toSet().toList(), field: 'title', to: e.key);
      if (r.ok) {
        done += r.done;
      } else {
        failed += e.value.length;
        error ??= r.error;
        if (r.error == _serverUpdateMsg) break;
      }
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (error == null) {
      btToast(context, 'Tidied $done ${done == 1 ? 'entry' : 'entries'} — amounts unchanged');
    } else if (done == 0) {
      btToast(context, error, error: true);
    } else {
      btToast(context, 'Tidied $done, $failed not renamed: $error', error: true);
    }
    if (done > 0) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final count = _tickedEntries;
    final busy = _allProjects && _loadingAll;
    return Scaffold(
      backgroundColor: Ins.bg,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Ins.border)),
        foregroundColor: Ins.ink,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tidy names', style: Ins.t(17, w: FontWeight.w600)),
          Text(_allProjects ? 'All projects' : (widget.projectName ?? 'This project'),
              style: Ins.t(12.5, c: Ins.ink3), overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 32),
        children: [
          InsCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _allProjects,
              onChanged: busy ? null : _toggleAll,
              title: Text('All projects', style: Ins.t(15, w: FontWeight.w600)),
              subtitle: Text('Off: only ${widget.projectName ?? 'this project'}', style: Ins.t(12.5, c: Ins.ink3)),
            ),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Ins.ink3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Only names change — amounts, payments and dates stay the same. '
                'Each entry keeps its old name, so you can undo from the entry list ("Undo rename").',
                style: Ins.t(12.5, c: Ins.ink3),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (busy)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_allProjects && _allError != null)
            InsCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const InsCardHeader(title: 'Couldn\'t load all projects'),
                Text(_allError!, style: Ins.t(14, c: Ins.ink3)),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Ins.primary, minimumSize: const Size(120, Ins.tap)),
                  onPressed: () => _toggleAll(true),
                  child: const Text('Try again'),
                ),
              ]),
            )
          else if (_proposals.isEmpty)
            InsCard(
              child: Column(children: [
                const SizedBox(height: 8),
                const Icon(Icons.check_circle_outline_rounded, size: 36, color: Ins.good),
                const SizedBox(height: 8),
                Text('Names are already tidy', style: Ins.t(16, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Nothing to rename here.', style: Ins.t(13, c: Ins.ink3)),
                const SizedBox(height: 8),
              ]),
            )
          else
            for (final kind in const [CostCategory.labour, CostCategory.material, CostCategory.equipment])
              if (_proposals.any((p) => p.kind == kind)) ...[
                _KindCard(
                  kind: kind,
                  proposals: [for (final p in _proposals) if (p.kind == kind) p],
                  ticked: _ticked,
                  onToggle: (p, v) => setState(() => v ? _ticked.add(p) : _ticked.remove(p)),
                ),
                const SizedBox(height: 12),
              ],
        ],
      ),
      bottomNavigationBar: _proposals.isEmpty || busy || (_allProjects && _allError != null)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Ins.gutter, 8, Ins.gutter, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Ins.primary, minimumSize: const Size.fromHeight(Ins.tap + 4)),
                  onPressed: count == 0 ? null : _apply,
                  child: Text(count == 0 ? 'Nothing selected' : 'Apply $count ${count == 1 ? 'rename' : 'renames'}'),
                ),
              ),
            ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({required this.kind, required this.proposals, required this.ticked, required this.onToggle});
  final CostCategory kind;
  final List<TidyProposal> proposals;
  final Set<TidyProposal> ticked;
  final void Function(TidyProposal, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final n = proposals.fold(0, (s, p) => s + p.lines.length);
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Ins.catIcon(kind), size: 18, color: Ins.cat(kind)),
          const SizedBox(width: 6),
          Expanded(child: Text(kind == CostCategory.material ? 'Materials' : kind.label, style: Ins.t(15, w: FontWeight.w600))),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('$n ${n == 1 ? 'entry' : 'entries'}', style: Ins.t(12.5, c: Ins.ink3)),
          ),
        ]),
        const SizedBox(height: 4),
        for (final p in proposals)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
            value: ticked.contains(p),
            onChanged: (v) => onToggle(p, v ?? false),
            title: Text.rich(
              TextSpan(children: [
                TextSpan(text: p.from.trim().isEmpty ? '(blank)' : p.from, style: Ins.t(14, c: Ins.ink3)),
                TextSpan(text: '  →  ', style: Ins.t(14, c: Ins.ink3)),
                TextSpan(text: p.to, style: Ins.t(14, w: FontWeight.w600)),
              ]),
            ),
            subtitle: Text('${p.lines.length} ${p.lines.length == 1 ? 'entry' : 'entries'} · ${inrFull(p.amount)}',
                style: Ins.t(12.5, c: Ins.ink3)),
          ),
      ]),
    );
  }
}
