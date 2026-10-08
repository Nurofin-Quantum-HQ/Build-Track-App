import 'package:buildtrack_mobile/models/project_insights.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_money.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_overview.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_phases.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// Project insights — light, tabbed (Overview · Phases · Money).
///
/// Mobile UX choices: three bottom tabs in the thumb zone instead of one long
/// scroll (Hick's law / progressive disclosure), ≥48dp targets, phase detail as
/// its own page so the back gesture works as expected.
class ProjectInsightsScreen extends StatefulWidget {
  const ProjectInsightsScreen({super.key, required this.projectId, this.projectName});

  final String projectId;
  final String? projectName;

  @override
  State<ProjectInsightsScreen> createState() => _ProjectInsightsScreenState();
}

class _ProjectInsightsScreenState extends State<ProjectInsightsScreen> {
  late Future<ProjectInsights> _future;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProjectInsights> _load() async =>
      ProjectInsights.fromJson(await ApiService.fetchProjectInsights(widget.projectId));

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  void _openPhase(InsightPhase p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PhaseInsightsPage(phase: p)));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FutureBuilder<ProjectInsights>(
        future: _future,
        builder: (context, snap) {
          final data = snap.data;
          return Scaffold(
            backgroundColor: Ins.bg,
            appBar: _AppBar(
              title: data?.name ?? widget.projectName ?? 'Project insights',
              subtitle: data == null ? null : [data.code, data.location].where((s) => s.isNotEmpty).join(' · '),
            ),
            bottomNavigationBar: data == null
                ? null
                : NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.white,
                      indicatorColor: Ins.primarySoft,
                      surfaceTintColor: Colors.white,
                      labelTextStyle: WidgetStateProperty.resolveWith(
                        (s) => Ins.t(
                          12.5,
                          w: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
                          c: s.contains(WidgetState.selected) ? Ins.primary : Ins.ink3,
                        ),
                      ),
                      iconTheme: WidgetStateProperty.resolveWith(
                        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Ins.primary : Ins.ink3),
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Ins.border)),
                      ),
                      child: NavigationBar(
                        height: 68,
                        selectedIndex: _tab,
                        onDestinationSelected: (i) => setState(() => _tab = i),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.space_dashboard_outlined),
                            selectedIcon: Icon(Icons.space_dashboard),
                            label: 'Overview',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.view_list_outlined),
                            selectedIcon: Icon(Icons.view_list),
                            label: 'Phases',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.payments_outlined),
                            selectedIcon: Icon(Icons.payments),
                            label: 'Money',
                          ),
                        ],
                      ),
                    ),
                  ),
            body: switch (snap.connectionState) {
              ConnectionState.done when data != null => RefreshIndicator(
                color: Ins.primary,
                onRefresh: _refresh,
                child: AnimatedSwitcher(
                  duration: Ins.motion,
                  child: KeyedSubtree(key: ValueKey(_tab), child: _tabBody(data)),
                ),
              ),
              ConnectionState.done => _Error(
                message: '${snap.error ?? 'Could not load insights'}'.replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              ),
              _ => const _Skeleton(),
            },
          );
        },
      ),
    );
  }

  Widget _tabBody(ProjectInsights d) {
    final tabs = <List<Widget>>[
      // Overview
      [
        VerdictCard(data: d),
        InsKpiGrid(data: d),
        BudgetBridgeCard(data: d, onTapPhase: (id) => _openById(d, id)),
        ProgressLineCard(data: d),
        AttentionCard(alerts: d.alerts, onTapPhase: (id) => _openById(d, id)),
      ],
      // Phases
      [
        if (d.phases.isEmpty)
          InsCard(
            child: Text(
              'This project has no phases yet. Add phases with activity budgets to see this view.',
              style: Ins.t(14, c: Ins.ink3),
            ),
          )
        else ...[
          PhaseMatrixCard(phases: d.phases, onOpen: _openPhase),
          SpendVsWorkCard(phases: d.phases, onOpen: _openPhase),
        ],
      ],
      // Money
      [
        InsSpendCurveCard(data: d),
        InsMonthlyCard(data: d),
        InsMixCard(data: d),
        InsCashCard(data: d),
        InsSuppliersCard(suppliers: d.suppliers),
      ],
    ];
    final children = tabs[_tab];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final pad = c.maxWidth < 400 ? Ins.gutter : 24.0;
        if (!wide) {
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 32),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => children[i],
          );
        }
        // Two balanced columns on tablets / wide windows.
        final left = <Widget>[], right = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          (i.isEven ? left : right).add(Padding(padding: const EdgeInsets.only(bottom: 16), child: children[i]));
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(children: right)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openById(ProjectInsights d, String id) {
    final p = d.phases.where((x) => x.id == id).firstOrNull;
    if (p != null) _openPhase(p);
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      scrolledUnderElevation: 0,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: Ins.border)),
      foregroundColor: Ins.ink,
      titleSpacing: Navigator.canPop(context) ? 0 : Ins.gutter,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Ins.t(17, w: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: Ins.t(12.5, c: Ins.ink3),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Ins.muted, borderRadius: BorderRadius.circular(Ins.r)),
    );
    return ListView(padding: const EdgeInsets.all(Ins.gutter), children: [box(220), box(110), box(110), box(260)]);
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Ins.ink3),
          const SizedBox(height: 12),
          Text('Couldn\'t load insights', style: Ins.t(17, w: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Ins.t(14, c: Ins.ink3),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Ins.primary, minimumSize: const Size(120, Ins.tap)),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
