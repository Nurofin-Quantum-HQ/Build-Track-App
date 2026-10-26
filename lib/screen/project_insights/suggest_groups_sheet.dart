import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:flutter/material.dart';

/// Full-screen "Suggest groups" page: the built-in rules propose a group for
/// each material item that isn't in one yet (M-Sand → Sand, UPVC door →
/// Doors & Windows). The user unticks anything to skip; "Apply" pops with the
/// new overrides (nameKey → group) to add to materialGroups. Display only —
/// entries and names never change.
class SuggestGroupsPage extends StatefulWidget {
  const SuggestGroupsPage({super.key, required this.lines, required this.groups, this.projectName});

  /// The project's entries (all periods); only materials are looked at.
  final List<SpendLine> lines;

  /// The user's current material groups (nameKey → group).
  final Map<String, String> groups;
  final String? projectName;

  @override
  State<SuggestGroupsPage> createState() => _SuggestGroupsPageState();
}

class _SuggestGroupsPageState extends State<SuggestGroupsPage> {
  late final List<GroupSuggestion> _all = computeGroupSuggestions(widget.lines, widget.groups);
  late final Set<String> _ticked = {for (final s in _all) s.key};

  /// Suggested group → its items, in rule order.
  late final Map<String, List<GroupSuggestion>> _byGroup = () {
    final m = <String, List<GroupSuggestion>>{};
    for (final s in _all) {
      (m[s.group] ??= []).add(s);
    }
    return m;
  }();

  void _apply() => Navigator.pop(context, {
    for (final s in _all)
      if (_ticked.contains(s.key)) s.key: s.group,
  });

  @override
  Widget build(BuildContext context) {
    final n = _ticked.length;
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
          Text('Suggest groups', style: Ins.t(17, w: FontWeight.w600)),
          Text('Materials · ${widget.projectName ?? 'This project'} · All time',
              style: Ins.t(12.5, c: Ins.ink3), overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ins.gutter, 16, Ins.gutter, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Ins.infoSoft, borderRadius: BorderRadius.circular(Ins.r)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Ins.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Only changes how Insights groups items for you. Entries and names stay the same.',
                    style: Ins.t(13.5, c: Ins.ink2, w: FontWeight.w500)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (_all.isEmpty)
            InsCard(
              child: Column(children: [
                const SizedBox(height: 8),
                const Icon(Icons.check_circle_outline_rounded, size: 36, color: Ins.good),
                const SizedBox(height: 8),
                Text('Nothing to suggest', style: Ins.t(16, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Every material is already in a group, or none match a common kind.',
                    textAlign: TextAlign.center, style: Ins.t(13, c: Ins.ink3)),
                const SizedBox(height: 8),
              ]),
            )
          else ...[
            Text('Untick anything you want to keep on its own.', style: Ins.t(12.5, c: Ins.ink3)),
            const SizedBox(height: 10),
            for (final e in _byGroup.entries) ...[
              _GroupCard(
                group: e.key,
                items: e.value,
                ticked: _ticked,
                onToggle: (s, v) => setState(() => v ? _ticked.add(s.key) : _ticked.remove(s.key)),
                onSkipAll: () => setState(() => _ticked.removeAll(e.value.map((s) => s.key))),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
      bottomNavigationBar: _all.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Ins.gutter, 8, Ins.gutter, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Ins.primary, minimumSize: const Size.fromHeight(Ins.tap + 4)),
                  onPressed: n == 0 ? null : _apply,
                  child: Text(n == 0 ? 'Nothing selected' : 'Apply — group $n ${n == 1 ? 'item' : 'items'}'),
                ),
              ),
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.items, required this.ticked, required this.onToggle, required this.onSkipAll});
  final String group;
  final List<GroupSuggestion> items;
  final Set<String> ticked;
  final void Function(GroupSuggestion, bool) onToggle;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context) {
    final amount = items.fold(0.0, (s, i) => s + i.amount);
    final anyTicked = items.any((i) => ticked.contains(i.key));
    return InsCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.folder_outlined, size: 18, color: Ins.material),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group, style: Ins.t(15, w: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text('${items.length} ${items.length == 1 ? 'item' : 'items'} · ${inrFull(amount)}', style: Ins.t(12.5, c: Ins.ink3)),
            ]),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Ins.ink2, minimumSize: const Size(0, 40)),
            onPressed: anyTicked ? onSkipAll : null,
            child: Text('Skip', style: Ins.t(13.5, w: FontWeight.w600, c: anyTicked ? Ins.ink2 : Ins.ink3)),
          ),
        ]),
        const SizedBox(height: 2),
        for (final s in items)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
            value: ticked.contains(s.key),
            onChanged: (v) => onToggle(s, v ?? false),
            title: Text(s.name, style: Ins.t(14, w: FontWeight.w500), overflow: TextOverflow.ellipsis),
            subtitle: Text('${s.count} ${s.count == 1 ? 'entry' : 'entries'} · ${inrFull(s.amount)}', style: Ins.t(12.5, c: Ins.ink3)),
          ),
      ]),
    );
  }
}
