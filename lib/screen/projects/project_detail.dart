import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/common/utils/currency_formatter.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/log_sheet.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
import 'package:buildtrack_mobile/screen/projects/edit_project.dart';
import 'package:buildtrack_mobile/screen/project_insights/project_insights_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:buildtrack_mobile/screen/reports/save_helper_stub.dart'
    if (dart.library.html) 'package:buildtrack_mobile/screen/reports/save_helper_web.dart'
    if (dart.library.io) 'package:buildtrack_mobile/screen/reports/save_helper_mobile.dart';
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key});
  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}
enum _DetailTab { overview, phases, money, details }

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  // Phases start folded (as in the original) except the one being worked on,
  // which opens automatically; tapping a phase header folds/unfolds it.
  final Set<String> _toggled = {};
  _DetailTab _tab = _DetailTab.overview;

  /// PUT /projects/:id also accepts anyone with a task on the project, so
  /// those users keep the update controls even without the permission.
  bool _hasMyTask = false;
  String? _taskCheckFor;

  void _checkMyTask(String projectId) {
    if (_taskCheckFor == projectId) return;
    _taskCheckFor = projectId;
    _hasMyTask = false;
    if (RoleManager.canSubmitProjectUpdate) return;
    final me = UserSession.userId;
    TaskService.getProjectTasks(projectId).then((tasks) {
      final mine = tasks.any((t) => me.isNotEmpty && (t.assignedTo?['_id'] ?? t.assignedTo?['id'])?.toString() == me);
      if (mounted && _taskCheckFor == projectId && mine) setState(() => _hasMyTask = true);
    }).catchError((_) {});
  }

  /// Phases-tab tick. Un-marking clears the activity's notes and photos, so it
  /// asks first; the result is always reported.
  Future<void> _toggleActivity(ProjectModel project, ProjectActivity activity) async {
    if (activity.completed) {
      final ok = await btConfirm(
        context,
        title: 'Mark "${activity.name}" as not done?',
        message: 'Its completion date, notes and photos will be removed.',
        confirmLabel: 'Mark not done',
      );
      if (!ok || !mounted) return;
    }
    final provider = context.read<ProjectProvider>();
    final success = await provider.toggleActivityCompletion(project.id, activity.id);
    if (!mounted) return;
    if (success) {
      btToast(context, activity.completed ? '${activity.name} marked not done' : '${activity.name} marked done');
    } else {
      btToast(context, provider.lastSaveError ?? 'Could not save. Try again.', error: true);
    }
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<ProjectProvider>();
        provider.load();
        if (provider.selectedProject != null) {
          provider.refreshProject(provider.selectedProject!.id);
        }
      }
    });
  }

  static const _gap = SizedBox(height: 26);

  /// First phase that still has open activities (the "now" phase).
  static String? _activePhaseId(List<ProjectPhase>? phases) {
    if (phases == null) return null;
    for (final p in phases) {
      if (p.activities.any((a) => !a.completed)) return p.id;
    }
    return null;
  }

  bool _isExpanded(ProjectPhase phase, String? activeId) {
    final byDefault = phase.id == activeId;
    return _toggled.contains(phase.id) ? !byDefault : byDefault;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.selectedProject;
    if (project == null) {
      return const Scaffold(
        backgroundColor: Bt.ground,
        appBar: BtNavBar(title: 'Project'),
        body: BtEmpty(
          icon: Icons.folder_open_outlined,
          title: 'No project selected',
          message: 'Go back and select a project.',
        ),
      );
    }
    _checkMyTask(project.id);
    final canUpdate = RoleManager.canSubmitProjectUpdate || _hasMyTask;
    final selectedPhases = project.selectedPhases;
    final hasNewTracker = selectedPhases != null && selectedPhases.isNotEmpty;
    final int trackerTotal = hasNewTracker
        ? selectedPhases.fold<int>(0, (s, p) => s + p.totalCount)
        : 0;
    final int trackerDone = hasNewTracker
        ? selectedPhases.fold<int>(0, (s, p) => s + p.completedCount)
        : (project.completedActivityKeys?.length ?? 0);
    final double progress = trackerTotal > 0
        ? trackerDone / trackerTotal
        : project.progress;
    final activeId = _activePhaseId(selectedPhases);

    List<Widget> overview() => [
          _SummaryCard(
            project: project,
            progress: progress,
            doneCount: trackerDone,
            totalCount: trackerTotal,
          ),
          const SizedBox(height: 12),
          _ProjectTimelineCard(project: project),
          const SizedBox(height: 18),
          _ActionButtons(project: project),
          if (hasNewTracker && activeId != null) ...[
            _gap,
            BtSectionHeader(
              title: 'Active phase',
              action: 'All ${selectedPhases.length}',
              onAction: () => setState(() => _tab = _DetailTab.phases),
            ),
            _ActivePhaseCard(
              phase: selectedPhases.firstWhere((p) => p.id == activeId),
              onTap: () => setState(() => _tab = _DetailTab.phases),
            ),
          ],
          _gap,
          _RecentEntriesSection(
            project: project,
            provider: provider,
            currentUserId: UserSession.userId,
          ),
        ];

    List<Widget> phases() => [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasNewTracker ? 'Execution tracker · ${selectedPhases.length} ${selectedPhases.length == 1 ? 'phase' : 'phases'}' : 'Execution tracker',
                    style: BtText.subhead(context),
                  ),
                ),
                if (hasNewTracker)
                  Text('$trackerDone / $trackerTotal done', style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
              ],
            ),
          ),
          if (hasNewTracker)
            for (var i = 0; i < selectedPhases.length; i++)
              _TrackerPhaseCard(
                index: i,
                phase: selectedPhases[i],
                project: project,
                isActive: selectedPhases[i].id == activeId,
                isExpanded: _isExpanded(selectedPhases[i], activeId),
                onToggleExpand: () => setState(() {
                  final id = selectedPhases[i].id;
                  if (_toggled.contains(id)) {
                    _toggled.remove(id);
                  } else {
                    _toggled.add(id);
                  }
                }),
                canUpdate: canUpdate,
                onToggleActivity: (activity) => _toggleActivity(project, activity),
              )
          else
            const BtCard(
              child: BtEmpty(
                icon: Icons.checklist_rounded,
                title: 'No execution plan configured',
                message: 'Select phases & activities when creating a project.',
              ),
            ),
        ];

    List<Widget> money() => [
          _FinancialCard(project: project),
          if (RoleManager.canViewReports && RoleManager.canViewProjectBudget) ...[
            const SizedBox(height: 12),
            _InsightsEntryCard(project: project),
          ],
          // CSV import/export reads and writes activity budget amounts.
          if (RoleManager.canViewProjectBudget) ...[
            _gap,
            _CsvImportExportCard(project: project),
          ],
        ];

    final hasRooms = (project.room1BHK ?? 0) +
            (project.room2BHK ?? 0) +
            (project.room3BHK ?? 0) +
            (project.roomCustom ?? 0) +
            (project.bathWestern ?? 0) +
            (project.bathIndian ?? 0) +
            (project.bathCommon ?? 0) +
            (project.bathAttached ?? 0) >
        0;

    List<Widget> details() => [
          if (project.photo != null && project.photo!.isNotEmpty) ...[
            _SitePhotoCard(photoUrl: project.photo!),
            _gap,
          ],
          _ProjectInfoCard(project: project),
          _gap,
          if (project.projectType != null &&
              project.projectType!.isNotEmpty) ...[
            const BtSectionHeader(title: 'Building type'),
            _BuildingTypeCard(project: project),
            _gap,
          ],
          if ((project.landArea != null && project.landArea!.isNotEmpty) ||
              (project.floors != null && project.floors!.isNotEmpty)) ...[
            const BtSectionHeader(title: 'Land & floors'),
            _LandFloorsCard(project: project),
            _gap,
          ],
          if (hasRooms) ...[
            const BtSectionHeader(title: 'Rooms & bathrooms'),
            _RoomsBathsCard(project: project),
            _gap,
          ],
          if (project.selectedFeatures != null &&
              project.selectedFeatures!.isNotEmpty)
            ..._buildConfigSections(project.selectedFeatures!),
          if (project.scope != null && project.scope!.isNotEmpty) ...[
            const BtSectionHeader(title: 'Project scope'),
            _ProjectScopeCard(scope: project.scope!),
            _gap,
          ],
          if (project.documents != null && project.documents!.isNotEmpty) ...[
            BtSectionHeader(title: 'Documents & blueprints', action: '${project.documents!.length}'),
            _DocumentsCard(documents: project.documents!),
            _gap,
          ],
        ];

    final List<Widget> body;
    switch (_tab) {
      case _DetailTab.overview:
        body = overview();
        break;
      case _DetailTab.phases:
        body = phases();
        break;
      case _DetailTab.money:
        body = money();
        break;
      case _DetailTab.details:
        body = details();
        break;
    }

    return Scaffold(
      backgroundColor: Bt.ground,
      body: SingleChildScrollView(
        key: const PageStorageKey('project-detail'),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHero(
              project: project,
              progress: progress,
              tab: _tab,
              onTab: (t) => setState(() => _tab = t),
            ),
            BtSheet(
              padding: const EdgeInsets.fromLTRB(Bt.gutter, 20, Bt.gutter, 48),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < body.length; i++)
                      i < 8 && body[i] is! SizedBox ? BtReveal(index: i, child: body[i]) : body[i],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  List<Widget> _buildConfigSections(List<String> features) {
    final addl = _grp(features, _kAddlConfig);
    final utility = _grp(features, _kUtility);
    final gas = _grp(features, _kGas);
    final kitchen = _grp(features, _kKitchen);
    final electrical = _grp(features, _kElectrical);
    final terrace = _grp(features, _kTerrace);
    final allKnown = [
      ..._kAddlConfig,
      ..._kUtility,
      ..._kGas,
      ..._kKitchen,
      ..._kElectrical,
      ..._kTerrace,
    ];
    final unknown = features.where((f) => !allKnown.contains(f)).toList();
    final addlAll = [...addl, ...unknown];
    Widget sec(String t, List<String> items, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _FeatureGroupCard(icon: icon, title: t, features: items),
    );
    return [
      const BtSectionHeader(title: 'Configuration & features'),
      if (addlAll.isNotEmpty)
        sec('Additional Configuration', addlAll, Icons.tune_rounded),
      if (utility.isNotEmpty)
        sec('Utility & Services', utility, Icons.electrical_services_rounded),
      if (gas.isNotEmpty)
        sec('Gas Connection', gas, Icons.local_fire_department_rounded),
      if (kitchen.isNotEmpty)
        sec('Kitchen Requirements', kitchen, Icons.kitchen_rounded),
      if (electrical.isNotEmpty)
        sec('Electrical & Plumbing', electrical, Icons.bolt_rounded),
      if (terrace.isNotEmpty)
        sec('Terrace & Interior', terrace, Icons.roofing_rounded),
      const SizedBox(height: 16),
    ];
  }
}

// ─────────────────────────────────────────────────────────────── hero

/// Noir header: back / assign, status pill + code · location, project name,
/// money stats on the Money tab, and the four section tabs.
class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.project, required this.progress, required this.tab, required this.onTab});
  final ProjectModel project;
  final double progress;
  final _DetailTab tab;
  final ValueChanged<_DetailTab> onTab;

  @override
  Widget build(BuildContext context) {
    final rawStatus = project.projectStatus;
    final statusLabel = (rawStatus != null && rawStatus.isNotEmpty)
        ? rawStatus
        : (progress >= 1.0
              ? 'Completed'
              : progress >= 0.3
              ? 'In Progress'
              : 'Planning');
    final caption = [
      if (project.projectCode?.isNotEmpty == true) project.projectCode!,
      if (project.location.isNotEmpty) project.location,
    ].join(' · ');
    final glass = Colors.white.withValues(alpha: .08);
    return BtHero(
      padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + 6, Bt.gutter, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BtIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 18,
                semantic: 'Back',
                color: Bt.bone,
                background: glass,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (RoleManager.canAssignTasks)
                BtIconButton(
                  icon: Icons.assignment_outlined,
                  size: 20,
                  semantic: 'Assign task',
                  color: Bt.bone,
                  background: glass,
                  onTap: () => Navigator.pushNamed(context, '/assign-task'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          BtReveal(
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _HeroPill(label: statusLabel, tone: BtBadge.toneFor(statusLabel)),
                if (caption.isNotEmpty) Text(caption.toUpperCase(), style: BtText.mono(context, color: Bt.onNoir2)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          BtReveal(
            index: 1,
            child: Text(project.name, style: BtText.d2(context, color: Bt.bone)),
          ),
          AnimatedSize(
            duration: Bt.medium,
            curve: Bt.ease,
            alignment: Alignment.topCenter,
            child: tab == _DetailTab.money
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: RoleManager.canViewProjectBudget
                        ? Row(
                            children: [
                              Expanded(child: _HeroStat(label: 'Total budget', value: project.totalBudget, color: Bt.bone)),
                              Expanded(child: _HeroStat(label: 'Spent', value: project.spentAmount, color: project.spentAmount > project.totalBudget ? Bt.redBright : context.bt.accent)),
                              Expanded(child: _HeroStat(label: 'Remaining', value: project.remainingBudget, color: project.remainingBudget >= 0 ? const Color(0xFF4ADBA4) : Bt.redBright)),
                            ],
                          )
                        // No budget access: spent only (its colour must not hint at the budget).
                        : Row(children: [Expanded(child: _HeroStat(label: 'Spent', value: project.spentAmount, color: context.bt.accent))]),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 18),
          _HeroTabs(value: tab, onChanged: onTab),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: BtCountUp(
            value: value,
            format: (v) => formatCurrency(v),
            style: BtText.num(BtText.headline(context).copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Status pill for the noir hero.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.tone});
  final String label;
  final BtTone tone;
  @override
  Widget build(BuildContext context) {
    final Color dot;
    switch (tone) {
      case BtTone.green:
        dot = const Color(0xFF4ADBA4);
        break;
      case BtTone.amber:
        dot = Bt.amberBright;
        break;
      case BtTone.red:
        dot = Bt.redBright;
        break;
      case BtTone.brand:
        dot = context.bt.accent;
        break;
      case BtTone.neutral:
        dot = Bt.slate;
        break;
    }
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: BtText.caption(context, color: Bt.bone, weight: FontWeight.w600).copyWith(fontSize: 12)),
      ]),
    );
  }
}

/// Underline tabs on the noir hero (accent indicator slides between tabs).
class _HeroTabs extends StatelessWidget {
  const _HeroTabs({required this.value, required this.onChanged});
  final _DetailTab value;
  final ValueChanged<_DetailTab> onChanged;
  static const _labels = {
    _DetailTab.overview: 'Overview',
    _DetailTab.phases: 'Phases',
    _DetailTab.money: 'Money',
    _DetailTab.details: 'Details',
  };
  @override
  Widget build(BuildContext context) {
    final accent = context.bt.accent;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .10)))),
      child: Row(
        children: [
          for (final e in _labels.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: e.key == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(e.key),
                  child: SizedBox(
                    height: Bt.touch,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: Bt.fast,
                          style: BtText.subhead(context, weight: FontWeight.w500, color: e.key == value ? Bt.bone : Bt.onNoir3).copyWith(fontSize: 15),
                          child: Text(e.value, maxLines: 1),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 0,
                          child: AnimatedScale(
                            scale: e.key == value ? 1 : 0,
                            duration: Bt.medium,
                            curve: Bt.ease,
                            child: Container(height: 2, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Overview shortcut to the phase being worked on.
class _ActivePhaseCard extends StatelessWidget {
  const _ActivePhaseCard({required this.phase, required this.onTap});
  final ProjectPhase phase;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final done = phase.completedCount;
    final total = phase.totalCount;
    final pct = total > 0 ? done / total : 0.0;
    return BtCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(phase.phaseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600))),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
            ],
          ),
          const SizedBox(height: 8),
          BtProgress(value: pct, thin: true),
          const SizedBox(height: 6),
          Text('$done of $total activities done', style: BtText.caption(context)),
        ],
      ),
    );
  }
}
class _TrackerPhaseCard extends StatelessWidget {
  const _TrackerPhaseCard({
    required this.index,
    required this.phase,
    required this.project,
    required this.isActive,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleActivity,
    this.canUpdate = true,
  });
  /// False → no tick / "Update progress" controls (the user can't save them).
  final bool canUpdate;
  final int index;
  final ProjectPhase phase;
  final ProjectModel project;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(ProjectActivity activity) onToggleActivity;
  @override
  Widget build(BuildContext context) {
    final done = phase.completedCount;
    final total = phase.totalCount;
    final pct = total > 0 ? done / total : 0.0;
    final complete = pct >= 1.0;
    final bt = context.bt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rCard),
        boxShadow: Bt.shadow,
        border: isActive ? Border.all(color: bt.accent, width: 1.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: isExpanded,
              label: '${phase.phaseName}, $done of $total activities done',
              child: InkWell(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: BtText.mono(context, size: 11, color: isActive ? bt.accentInk : Bt.ink3),
                        ),
                      ),
                      if (phase.isCustom) ...[
                        Icon(Icons.star_rounded, size: 16, color: bt.accentInk),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    phase.phaseName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: BtText.body(context, weight: FontWeight.w600, color: total > 0 && done == 0 && !isActive ? Bt.ink2 : Bt.ink),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (complete && total > 0)
                                  const BtBadge(label: 'Done', tone: BtTone.green, dot: false)
                                else
                                  Text(
                                    '${(pct * 100).toStringAsFixed(0)}%',
                                    style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: done == 0 ? Bt.ink3 : Bt.ink)),
                                  ),
                              ],
                            ),
                            if (total > 0) ...[
                              const SizedBox(height: 8),
                              BtProgress(value: pct, thin: true, color: complete ? Bt.greenBright : bt.accent),
                            ],
                            const SizedBox(height: 6),
                            Text('$done of $total activities done', style: BtText.caption(context)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: Bt.fast,
                        curve: Bt.ease,
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.ink3, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: Bt.medium,
              curve: Bt.ease,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < phase.activities.length; i++)
                            _TrackerActivityRow(
                              activity: phase.activities[i],
                              project: project,
                              phase: phase,
                              phaseName: phase.phaseName,
                              isFirst: i == 0,
                              isLast: i == phase.activities.length - 1,
                              onToggle: canUpdate ? () => onToggleActivity(phase.activities[i]) : null,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical rail + status node drawn behind an activity row.
class _RailPainter extends CustomPainter {
  const _RailPainter({required this.color, required this.top, required this.bottom});
  final Color color;
  final bool top, bottom;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const x = 30.0, y = 28.0;
    if (top) canvas.drawLine(const Offset(x, 0), const Offset(x, y), p);
    if (bottom) canvas.drawLine(const Offset(x, y), Offset(x, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) => old.color != color || old.top != top || old.bottom != bottom;
}
class _TrackerActivityRow extends StatefulWidget {
  const _TrackerActivityRow({
    required this.activity,
    required this.project,
    required this.phase,
    required this.phaseName,
    required this.onToggle,
    this.isFirst = false,
    this.isLast = false,
  });
  bool get canUpdate => onToggle != null;
  final ProjectActivity activity;
  final ProjectModel project;
  final ProjectPhase phase;
  final String phaseName;
  /// Null when the user can't update progress (controls hidden).
  final VoidCallback? onToggle;
  final bool isFirst, isLast;
  @override
  State<_TrackerActivityRow> createState() => _TrackerActivityRowState();
}
class _TrackerActivityRowState extends State<_TrackerActivityRow> {
  // Budget breakdown starts folded, as in the original.
  bool _isBudgetExpanded = false;
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String? _completedDateLabel() {
    if (!widget.activity.completed) return null;
    final dt = widget.activity.completedAt;
    if (dt == null) return 'Date not recorded';
    if (dt.year == 2000 && dt.month == 1 && dt.day == 1) {
      return 'Date not recorded';
    }
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }
  bool get _canAddEntry => logEntryKinds.any((k) => logKindAllowed(k.$1));
  void _openUpdateProgress(BuildContext context) {
    final floors = widget.project.floors ?? [];
    Navigator.pushNamed(
      context,
      '/update-progress',
      arguments: {
        'projectId': widget.project.id,
        'phaseName': widget.phaseName,
        'activityName': widget.activity.name,
        'activityId': widget.activity.id,
        'floor': floors.isNotEmpty ? floors.first : null,
        'projectFloors': floors,
      },
    ).then((_) async {
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (context.mounted) {
          context.read<ProjectProvider>().load();
        }
      }
    });
  }
  void _openUpdateBudgetDialog(BuildContext context) {
    final provider = context.read<ProjectProvider>();
    final currentProject = provider.projects.firstWhere(
      (p) => p.id == widget.project.id,
      orElse: () => widget.project,
    );
    ProjectActivity currentActivity = widget.activity;
    for (final phase in currentProject.selectedPhases ?? <ProjectPhase>[]) {
      for (final a in phase.activities) {
        if (a.id == widget.activity.id || a.name == widget.activity.name) {
          currentActivity = a;
          break;
        }
      }
    }

    // A zero budget starts empty (hint "0") so typing doesn't append to a
    // literal "0"; a set value is selected on focus (see _BudgetAmountField).
    final materialController = TextEditingController(
      text: _budgetText(currentActivity.budgetMaterial),
    );
    final labourController = TextEditingController(
      text: _budgetText(currentActivity.budgetLabour),
    );
    final equipmentController = TextEditingController(
      text: _budgetText(currentActivity.budgetEquipment),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Bt.ground,
      barrierColor: Bt.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + MediaQuery.of(modalContext).padding.bottom + 16,
          ),
          // Scrolls so the fields and Save stay reachable with the keyboard open.
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Bt.ink.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('BUDGET ALLOCATION', style: BtText.mono(modalContext)),
              const SizedBox(height: 6),
              Text(currentActivity.name, style: BtText.d3(modalContext)),
              const SizedBox(height: 6),
              Text(
                'Allocate activity budgets under Materials, Labour, and Equipment categories.',
                style: BtText.caption(modalContext),
              ),
              const SizedBox(height: 20),
              _buildDialogTextField('Materials budget', materialController),
              const SizedBox(height: 14),
              _buildDialogTextField('Labour budget', labourController),
              const SizedBox(height: 14),
              _buildDialogTextField(
                'Equipment budget',
                equipmentController,
              ),
              const SizedBox(height: 24),
              BtButton(
                label: 'Save budget allocation',
                onPressed: () async {
                  final mat = double.tryParse(materialController.text) ?? 0.0;
                  final lab = double.tryParse(labourController.text) ?? 0.0;
                  final equ =
                      double.tryParse(equipmentController.text) ?? 0.0;
                  Navigator.pop(modalContext);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  final success = await context
                      .read<ProjectProvider>()
                      .updateActivityBudget(
                        widget.project.id,
                        currentActivity.id.isNotEmpty
                            ? currentActivity.id
                            : currentActivity.name,
                        budgetMaterial: mat,
                        budgetLabour: lab,
                        budgetEquipment: equ,
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (success) {
                      btToast(context, 'Budget updated successfully!');
                    } else {
                      btToast(context, context.read<ProjectProvider>().lastSaveError ?? 'Failed to update budget. Please try again.', error: true);
                    }
                  }
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }
  static String _budgetText(double? v) {
    final value = v ?? 0.0;
    if (value == 0) return '';
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
  }
  Widget _buildDialogTextField(String label, TextEditingController controller) {
    return BtField(
      label: label,
      child: _BudgetAmountField(controller: controller),
    );
  }
  Widget _buildBudgetSection(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final entries = provider.entriesForProject(widget.project.id);
    final currentProject = provider.projects.firstWhere(
      (p) => p.id == widget.project.id,
      orElse: () => widget.project,
    );
    ProjectActivity currentActivity = widget.activity;
    for (final phase in currentProject.selectedPhases ?? <ProjectPhase>[]) {
      for (final a in phase.activities) {
        if (a.id == widget.activity.id || a.name == widget.activity.name) {
          currentActivity = a;
          break;
        }
      }
    }

    final allocMat = currentActivity.budgetMaterial ?? 0.0;
    final allocLab = currentActivity.budgetLabour ?? 0.0;
    final allocEqu = currentActivity.budgetEquipment ?? 0.0;
    final allocTotal = allocMat + allocLab + allocEqu;

    bool matchesActivity(EntryModel e) {
      if (currentActivity.id.isNotEmpty && e.activityId == currentActivity.id) {
        return true;
      }
      final actNameLower = currentActivity.name.trim().toLowerCase();
      if (e.activity != null && e.activity!.trim().toLowerCase() == actNameLower) {
        return true;
      }
      if (e.activityId != null && e.activityId!.trim().toLowerCase() == actNameLower) {
        return true;
      }
      return false;
    }

    final actEntries = entries.where(matchesActivity).toList();

    final spentMat = actEntries
        .where((e) => e.type == EntryType.material)
        .fold(0.0, (sum, e) => sum + e.amount);

    final spentLab = actEntries
        .where((e) => e.type == EntryType.labour)
        .fold(0.0, (sum, e) => sum + e.amount);

    final spentEqu = actEntries
        .where((e) => e.type == EntryType.equipment)
        .fold(0.0, (sum, e) => sum + e.amount);

    final spentTotal = spentMat + spentLab + spentEqu;

    final matCat = ActivityBudgetCategory(
      allocated: allocMat,
      spent: spentMat,
      remaining: allocMat - spentMat,
      utilization: allocMat > 0 ? (spentMat / allocMat) : 0.0,
      progress: allocMat > 0 ? (spentMat / allocMat).clamp(0.0, 1.0) : 0.0,
    );

    final labCat = ActivityBudgetCategory(
      allocated: allocLab,
      spent: spentLab,
      remaining: allocLab - spentLab,
      utilization: allocLab > 0 ? (spentLab / allocLab) : 0.0,
      progress: allocLab > 0 ? (spentLab / allocLab).clamp(0.0, 1.0) : 0.0,
    );

    final equCat = ActivityBudgetCategory(
      allocated: allocEqu,
      spent: spentEqu,
      remaining: allocEqu - spentEqu,
      utilization: allocEqu > 0 ? (spentEqu / allocEqu) : 0.0,
      progress: allocEqu > 0 ? (spentEqu / allocEqu).clamp(0.0, 1.0) : 0.0,
    );

    final totalCat = ActivityBudgetCategory(
      allocated: allocTotal,
      spent: spentTotal,
      remaining: allocTotal - spentTotal,
      utilization: allocTotal > 0 ? (spentTotal / allocTotal) : 0.0,
      progress: allocTotal > 0 ? (spentTotal / allocTotal).clamp(0.0, 1.0) : 0.0,
    );

    final bt = context.bt;
    final canSeeBudget = RoleManager.canViewProjectBudget;
    return Container(
      margin: const EdgeInsets.fromLTRB(58, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: Bt.ground,
        borderRadius: BorderRadius.circular(Bt.rTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(canSeeBudget ? 'ACTIVITY BUDGET' : 'ACTIVITY SPEND', style: BtText.mono(context)),
              ),
              if (canSeeBudget)
              TextButton.icon(
                onPressed: () => _openUpdateBudgetDialog(context),
                style: TextButton.styleFrom(
                  foregroundColor: bt.accentInk,
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text('Update budget', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.accentInk)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBudgetItem(
            label: 'Materials',
            category: matCat,
            color: bt.series[0],
            showBudget: canSeeBudget,
          ),
          const SizedBox(height: 8),
          _buildBudgetItem(
            label: 'Labour',
            category: labCat,
            color: bt.series[1],
            showBudget: canSeeBudget,
          ),
          const SizedBox(height: 8),
          _buildBudgetItem(
            label: 'Equipment',
            category: equCat,
            color: bt.series[2],
            showBudget: canSeeBudget,
          ),
          const Divider(height: 20, color: Bt.line),
          _buildBudgetItem(
            label: canSeeBudget ? 'Total budget' : 'Total spent',
            category: totalCat,
            color: Bt.ink2,
            isBold: true,
            showBudget: canSeeBudget,
          ),
        ],
      ),
    );
  }
  Widget _buildBudgetItem({
    required String label,
    required ActivityBudgetCategory category,
    required Color color,
    bool isBold = false,
    bool showBudget = true,
  }) {
    final spent = category.spent;
    if (!showBudget) {
      // Spent only: no allocation, remaining, utilisation bar or over-budget hint.
      return Row(
        children: [
          if (!isBold) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: BtText.caption(context, color: isBold ? Bt.ink : Bt.ink2, weight: isBold ? FontWeight.w600 : FontWeight.w500),
            ),
          ),
          Text(formatCurrency(spent), style: BtText.num(BtText.caption(context, color: Bt.ink, weight: FontWeight.w600))),
        ],
      );
    }
    final allocated = category.allocated;
    final remaining = category.remaining;
    final pct = category.progress;
    final isOver = spent > allocated && allocated > 0;
    final barColor = isOver ? Bt.redBright : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!isBold) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: BtText.caption(context, color: isBold ? Bt.ink : Bt.ink2, weight: isBold ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: formatCurrency(spent),
                  style: BtText.num(BtText.caption(context, color: isOver ? Bt.red : Bt.ink, weight: FontWeight.w600)),
                ),
                TextSpan(
                  text: ' / ${formatCurrency(allocated)}',
                  style: BtText.num(BtText.caption(context, color: Bt.ink3)),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 5),
        BtProgress(value: pct, thin: true, color: barColor),
        if (isOver) ...[
          const SizedBox(height: 3),
          Text(
            'Exceeded by ${formatCurrency(spent - allocated)}',
            style: BtText.caption(context, color: Bt.red, weight: FontWeight.w600).copyWith(fontSize: 12),
          ),
        ] else if (allocated > 0 && spent > 0) ...[
          const SizedBox(height: 3),
          Text(
            '${formatCurrency(remaining)} remaining',
            style: BtText.caption(context).copyWith(fontSize: 12),
          ),
        ],
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final done = widget.activity.completed;
    final dateLabel = _completedDateLabel();
    final bt = context.bt;
    return CustomPaint(
      painter: _RailPainter(color: Bt.line, top: !widget.isFirst, bottom: !widget.isLast),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isBudgetExpanded = !_isBudgetExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    checked: done,
                    label: done ? 'Mark ${widget.activity.name} as not done' : 'Mark ${widget.activity.name} as done',
                    child: GestureDetector(
                      onTap: widget.onToggle,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 44,
                        height: Bt.touch,
                        child: Center(
                          child: AnimatedContainer(
                            duration: Bt.fast,
                            curve: Bt.ease,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done ? Bt.greenBright : Bt.card,
                              border: done ? null : Border.all(color: Bt.inputBorder, width: 2),
                            ),
                            child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activity.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BtText.body(context, weight: FontWeight.w500, color: done ? Bt.ink2 : Bt.ink).copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            done ? 'Done · ${dateLabel ?? ''}' : 'Pending',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BtText.caption(context, color: done ? Bt.green : Bt.amber, weight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (widget.canUpdate)
                                _rowAction(context, Icons.trending_up_rounded, 'Update progress', bt.accentInk, () => _openUpdateProgress(context)),
                              if (_canAddEntry)
                                _rowAction(
                                  context,
                                  Icons.add_rounded,
                                  'Add entry',
                                  Bt.ink,
                                  () => _showAddEntrySheet(
                                    context,
                                    project: widget.project,
                                    phase: widget.phase,
                                    activity: widget.activity,
                                  ),
                                ),
                              if (done) _rowAction(context, Icons.visibility_outlined, 'View', Bt.ink2, () => _showActivityDetails(context)),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    label: _isBudgetExpanded ? 'Hide budget' : 'Show budget',
                    child: SizedBox(
                      width: 40,
                      height: Bt.touch,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedRotation(
                            turns: _isBudgetExpanded ? 0.5 : 0,
                            duration: Bt.fast,
                            curve: Bt.ease,
                            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.ink3, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Bt.medium,
            curve: Bt.ease,
            alignment: Alignment.topCenter,
            child: _isBudgetExpanded ? _buildBudgetSection(context) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _rowAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: '$label, ${widget.activity.name}',
      excludeSemantics: true,
      child: BtPressable(
        onTap: onTap,
        scale: .95,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Bt.rChip),
            color: Bt.fill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(label, style: BtText.caption(context, color: color, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
  void _showActivityDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Bt.ground,
      barrierColor: Bt.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
      ),
      builder: (sheetContext) {
        final maxH = MediaQuery.of(context).size.height * 0.85;
        final formattedDate = _completedDateLabel() ?? 'Completed';
        final notes = widget.activity.notes;
        final hasNotes = notes != null && notes.trim().isNotEmpty;
        final hasPhotos = (widget.activity.photos != null && widget.activity.photos!.isNotEmpty) ||
            (widget.activity.photo != null && widget.activity.photo!.isNotEmpty);
        final photoCount = (widget.activity.photos != null && widget.activity.photos!.isNotEmpty) ? widget.activity.photos!.length : 1;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Bt.ink.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              BtBadge(label: widget.phaseName, tone: BtTone.brand),
                              Text('Completed on $formattedDate'.toUpperCase(), style: BtText.mono(context, color: Bt.green)),
                            ],
                          ),
                        ),
                      ),
                      BtIconButton(
                        icon: Icons.close_rounded,
                        semantic: 'Close',
                        color: Bt.ink2,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BtReveal(child: Text(widget.activity.name, style: BtText.d2(context))),
                        if (hasPhotos) ...[
                          const SizedBox(height: 22),
                          BtReveal(
                            index: 1,
                            child: BtSectionHeader(title: 'Progress photos', action: '$photoCount'),
                          ),
                          BtReveal(index: 2, child: _buildProgressPhotosList(context, widget.activity)),
                        ],
                        if (hasNotes) ...[
                          const SizedBox(height: 22),
                          const BtReveal(index: 3, child: BtSectionHeader(title: 'Notes & remarks')),
                          BtReveal(
                            index: 4,
                            child: BtCard(
                              padding: const EdgeInsets.all(16),
                              child: Text(notes, style: BtText.subhead(context, color: Bt.ink).copyWith(height: 1.5)),
                            ),
                          ),
                        ],
                        if (!hasNotes && !hasPhotos) ...[
                          const SizedBox(height: 18),
                          const BtCard(
                            child: BtEmpty(
                              icon: Icons.info_outline_rounded,
                              title: 'Nothing recorded yet',
                              message: 'No additional notes or photos recorded for this activity.',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.canUpdate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: BtButton(
                    label: 'Update progress',
                    icon: Icons.trending_up_rounded,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openUpdateProgress(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildThumbnailImage(String photoUrl, {double? width, double? height}) {
    Widget broken() => Container(
          color: Bt.fill,
          child: const Center(child: Icon(Icons.broken_image_outlined, color: Bt.ink3, size: 24)),
        );
    Widget img;
    if (photoUrl.startsWith('data:image/') && photoUrl.contains(';base64,')) {
      try {
        final base64String = photoUrl.split(';base64,').last;
        final bytes = base64.decode(base64String);
        img = Image.memory(bytes, fit: BoxFit.cover, width: width, height: height, gaplessPlayback: true);
      } catch (e) {
        img = broken();
      }
    } else {
      img = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => broken(),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(Bt.rTile), child: img);
  }
  Widget _buildProgressPhotosList(
    BuildContext context,
    ProjectActivity activity,
  ) {
    final photos = (activity.photos != null && activity.photos!.isNotEmpty)
        ? activity.photos!
        : [activity.photo!];
    Widget tile(int idx, {Widget? overlay}) => Semantics(
          button: true,
          label: 'Open photo ${idx + 1} of ${photos.length}',
          child: BtPressable(
            scale: .97,
            onTap: () => _openPhotoGallery(context, photos, idx),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildThumbnailImage(photos[idx]),
                ?overlay,
              ],
            ),
          ),
        );
    if (photos.length == 1) {
      return SizedBox(height: 198, child: tile(0));
    }
    if (photos.length == 2) {
      return SizedBox(
        height: 160,
        child: Row(children: [Expanded(child: tile(0)), const SizedBox(width: 6), Expanded(child: tile(1))]),
      );
    }
    final extra = photos.length - 3;
    return SizedBox(
      height: 198,
      child: Row(
        children: [
          Expanded(flex: 2, child: tile(0)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: 6),
                Expanded(
                  child: tile(
                    2,
                    overlay: extra > 0
                        ? Container(
                            decoration: BoxDecoration(color: const Color(0x8C0C0E12), borderRadius: BorderRadius.circular(Bt.rTile)),
                            alignment: Alignment.center,
                            child: Text('+$extra', style: BtText.title(context, size: 18).copyWith(color: Bt.bone)),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _openPhotoGallery(
    BuildContext context,
    List<String> photos,
    int initialIndex,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) =>
          _GalleryDialog(photos: photos, initialIndex: initialIndex),
    );
  }
}
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.project,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
  });
  final ProjectModel project;
  final double progress;
  final int doneCount, totalCount;
  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(1);
    final rawStatus = project.projectStatus;
    final statusColor = rawStatus == 'Completed'
        ? Bt.greenBright
        : rawStatus == 'On Hold'
        ? Bt.amberBright
        : rawStatus == 'Cancelled'
        ? Bt.redBright
        : context.bt.accent;
    final allPhases = buildDefaultPhases();
    final selectedNames = project.selectedPhaseNames;
    final phases = (selectedNames == null || selectedNames.isEmpty)
        ? allPhases
        : allPhases.where((p) => selectedNames.contains(p.name)).toList();
    final completed = project.completedActivityKeys ?? [];
    String? activePhase;
    if (project.selectedPhases != null && project.selectedPhases!.isNotEmpty) {
      for (final p in project.selectedPhases!) {
        if (p.activities.any((a) => !a.completed)) {
          activePhase = p.phaseName;
          break;
        }
      }
    } else {
      for (final p in phases) {
        final keys = p.allActivities.map((a) => a.key).toList();
        if (keys.any((k) => !completed.contains(k))) {
          activePhase = p.name;
          break;
        }
      }
    }
    final util = project.budgetUtilization;
    final utilColor = util >= 1.0
        ? Bt.redBright
        : util >= 0.8
        ? Bt.amberBright
        : Bt.ink;
    final hasClient = project.clientName != null && project.clientName!.isNotEmpty;
    final hasFloors = project.floors != null && project.floors!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _RingStat(
                value: progress.clamp(0.0, 1.0).toDouble(),
                color: statusColor,
                center: '${(progress * 100).toStringAsFixed(0)}%',
                title: 'Work done',
                subtitle: totalCount > 0 ? '$doneCount of $totalCount' : '$pct% complete',
              ),
            ),
            if (RoleManager.canViewProjectBudget) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _RingStat(
                  value: util.clamp(0.0, 1.0).toDouble(),
                  color: utilColor,
                  center: '${(util * 100).toStringAsFixed(0)}%',
                  title: 'Budget used',
                  subtitle: project.formattedSpent,
                ),
              ),
            ],
          ],
        ),
        if (activePhase != null || hasClient || hasFloors) ...[
          const SizedBox(height: 10),
          BtCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall completion · $pct% · $doneCount/$totalCount activities',
                  style: BtText.num(BtText.caption(context)),
                ),
                if (activePhase != null || hasClient) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (activePhase != null) BtBadge(label: 'Now: $activePhase', tone: BtTone.brand),
                      if (hasClient) BtBadge(label: 'Client · ${project.clientName!}'),
                    ],
                  ),
                ],
                if (hasFloors) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: project.floors!.map((f) => BtBadge(label: f, dot: false)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Small card with an animated ring + label (Overview "Work done" / "Budget used").
class _RingStat extends StatelessWidget {
  const _RingStat({required this.value, required this.color, required this.center, required this.title, required this.subtitle});
  final double value;
  final Color color;
  final String center, title, subtitle;
  @override
  Widget build(BuildContext context) {
    return BtCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          BtRing(
            value: value,
            size: 56,
            stroke: 6,
            color: color,
            child: Text(center, style: BtText.num(BtText.caption(context, color: Bt.ink, weight: FontWeight.w700).copyWith(fontSize: 12))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.caption(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact label/value tile used across the Details tab.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.icon});
  final String label, value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return BtCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: Bt.ink3), const SizedBox(width: 5)],
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context).copyWith(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.body(context, weight: FontWeight.w600).copyWith(fontSize: 15))),
        ],
      ),
    );
  }
}

/// Lays tiles out two per row.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _ProjectInfoCard extends StatelessWidget {
  const _ProjectInfoCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final people = <_InfoRow>[
      if (project.clientName?.isNotEmpty == true)
        _InfoRow(Icons.person_outline, 'Client', project.clientName!),
      if (project.contractorName?.isNotEmpty == true)
        _InfoRow(Icons.engineering_outlined, 'Contractor', project.contractorName!),
      if (project.siteEngineer?.isNotEmpty == true)
        _InfoRow(Icons.construction_outlined, 'Engineer', project.siteEngineer!),
    ];
    final hasContact = project.contactNumber?.isNotEmpty == true;
    final status = project.projectStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (people.isNotEmpty || hasContact) ...[
          const BtSectionHeader(title: 'People'),
          BtGroup(
            children: [
              for (final r in people)
                BtRow(
                  leading: BtAvatar(name: r.value, size: 40),
                  title: r.value,
                  subtitle: r.label,
                  titleWeight: FontWeight.w600,
                ),
              if (hasContact)
                BtRow(
                  leading: const BtTile(icon: Icons.phone_outlined, size: 40),
                  title: project.contactNumber!,
                  subtitle: 'Contact',
                  titleWeight: FontWeight.w600,
                ),
            ],
          ),
          const SizedBox(height: 26),
        ],
        const BtSectionHeader(title: 'Project information'),
        BtGroup(
          insetDividers: false,
          children: [
            if (project.projectCode?.isNotEmpty == true)
              BtValueRow(
                label: 'Project code',
                value: '',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Bt.noir, borderRadius: BorderRadius.circular(10)),
                  child: Text(project.projectCode!.toUpperCase(), style: BtText.mono(context, color: Bt.bone, size: 12)),
                ),
              ),
            if (project.mapAddress?.isNotEmpty == true)
              BtValueRow(label: 'Map address', value: project.mapAddress!),
            if (status?.isNotEmpty == true)
              BtValueRow(label: 'Status', value: '', trailing: BtBadge(label: status!, tone: BtBadge.toneFor(status))),
            BtValueRow(label: 'Location', value: project.location),
          ],
        ),
      ],
    );
  }
}
class _InfoRow {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
}
class _BuildingTypeCard extends StatelessWidget {
  const _BuildingTypeCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final raw = project.projectType ?? '';
    final parts = raw.split(' → ');
    final mainType = parts.isNotEmpty ? parts[0].trim() : raw;
    final subType = parts.length > 1 ? parts[1].trim() : null;
    final IconData mainIcon = _iconForType(mainType);
    return _TileGrid(
      children: [
        _StatTile(label: 'Main type', value: mainType, icon: mainIcon),
        if (subType != null) _StatTile(label: 'Sub type', value: subType, icon: Icons.category_outlined),
      ],
    );
  }
  IconData _iconForType(String type) {
    switch (type) {
      case 'Residential':
        return Icons.home_rounded;
      case 'Educational':
        return Icons.school_rounded;
      case 'Institutional':
        return Icons.account_balance_rounded;
      case 'Business / Commercial':
        return Icons.store_rounded;
      case 'Industrial':
        return Icons.factory_rounded;
      default:
        return Icons.apartment_rounded;
    }
  }
}
class _LandFloorsCard extends StatelessWidget {
  const _LandFloorsCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final hasLand = project.landArea != null && project.landArea!.isNotEmpty;
    final hasFloors = project.floors != null && project.floors!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TileGrid(
          children: [
            if (hasLand)
              _StatTile(label: 'Total land area', value: '${project.landArea} ${project.landUnit ?? ""}'.trim(), icon: Icons.landscape_outlined),
            if (hasFloors)
              _StatTile(label: 'Floors included', value: '${project.floors!.length}', icon: Icons.layers_outlined),
          ],
        ),
        if (hasFloors) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: project.floors!.map((f) => BtBadge(label: f, dot: false)).toList(),
          ),
        ],
      ],
    );
  }
}
class _RoomsBathsCard extends StatelessWidget {
  const _RoomsBathsCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final rooms = <String, int?>{
      '1 BHK': project.room1BHK,
      '2 BHK': project.room2BHK,
      '3 BHK': project.room3BHK,
      'Custom': project.roomCustom,
    };
    final baths = <String, int?>{
      'Western': project.bathWestern,
      'Indian': project.bathIndian,
      'Common': project.bathCommon,
      'Attached': project.bathAttached,
    };
    Widget tile(String label, int? count) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Bt.fill,
        borderRadius: BorderRadius.circular(Bt.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: BtText.caption(context, color: Bt.ink2)),
          Text('${count ?? 0}', style: BtText.num(BtText.title(context, size: 16))),
        ],
      ),
    );
    final roomTiles = rooms.entries
        .where((e) => (e.value ?? 0) > 0)
        .map((e) => tile(e.key, e.value))
        .toList();
    final bathTiles = baths.entries
        .where((e) => (e.value ?? 0) > 0)
        .map((e) => tile(e.key, e.value))
        .toList();
    return BtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roomTiles.isNotEmpty) ...[
            Text('ROOMS', style: BtText.mono(context)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: roomTiles),
            if (bathTiles.isNotEmpty) const SizedBox(height: 16),
          ],
          if (bathTiles.isNotEmpty) ...[
            Text('BATHROOMS', style: BtText.mono(context)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: bathTiles),
          ],
        ],
      ),
    );
  }
}
const _kAddlConfig = [
  'Balcony',
  'Car Parking',
  'Lift',
  'Terrace Access',
  'Interior Work',
  'Compound Wall',
  'Parapet Wall',
  'Waterproofing',
  'Putty',
  'False Ceiling',
  'Modular Kitchen',
  'Wardrobes',
  'Sump',
  'Septic Tank',
  'Rainwater',
  'Borewell',
  'Solar',
  'Generator',
  'CCTV',
  'Intercom',
  'Landscaping',
  'Paving',
  'Water Tanks',
  'Stairs',
  'Security Room',
  'Cladding',
  'Elevation',
  'Gates',
  'Grills',
  'Aluminium',
  'Glass',
];
const _kUtility = [
  'Main Electricity',
  'Temporary Connection',
  'Generator Backup',
  'Water Connection',
  'Borewell Motor',
  'Sump Motor',
];
const _kGas = ['Piped Gas', 'Cylinder Bank', 'Gas Pipeline Routing'];
const _kKitchen = [
  'Granite Counter',
  'Quartz Counter',
  'Stainless Steel Sink',
  'Chimney Provision',
  'Exhaust Fan Provision',
];
const _kElectrical = [
  'Concealed Wiring',
  'Open Wiring',
  '3-Phase Connection',
  'AC Points',
  'Geyser Points',
];
const _kTerrace = [
  'Weathering Course',
  'Cool Roof Paint',
  'Overhead Tank',
  'Solar Panels',
];
List<String> _grp(List<String> all, List<String> opts) =>
    all.where(opts.contains).toList();
class _FeatureGroupCard extends StatefulWidget {
  const _FeatureGroupCard({
    required this.icon,
    required this.title,
    required this.features,
  });
  final IconData icon;
  final String title;
  final List<String> features;
  @override
  State<_FeatureGroupCard> createState() => _FeatureGroupCardState();
}
class _FeatureGroupCardState extends State<_FeatureGroupCard> {
  bool _open = true;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rCard),
        boxShadow: Bt.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      BtTile(icon: widget.icon, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                            Text('${widget.features.length} selected', style: BtText.caption(context)),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: Bt.fast,
                        curve: Bt.ease,
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.ink3, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: Bt.medium,
              curve: Bt.ease,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.features.map((f) => BtBadge(label: f, dot: false)).toList(),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
class _ProjectTimelineCard extends StatelessWidget {
  const _ProjectTimelineCard({required this.project});
  final ProjectModel project;
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  @override
  Widget build(BuildContext context) {
    final status = project.projectStatus;
    final start = project.startDate;
    final end = project.expectedEndDate;
    final now = DateTime.now();
    double? elapsed;
    int? daysLeft;
    if (end != null && end.isAfter(start)) {
      final total = end.difference(start).inMinutes;
      elapsed = (now.difference(start).inMinutes / total).clamp(0.0, 1.0).toDouble();
      daysLeft = end.difference(DateTime(now.year, now.month, now.day)).inDays;
    }
    final accent = context.bt.accent;
    return BtCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Timeline & status', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
              if (status != null) BtBadge(label: status, tone: BtBadge.toneFor(status)),
            ],
          ),
          if (elapsed != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 30,
              child: LayoutBuilder(
                builder: (context, c) {
                  final x = c.maxWidth * elapsed!;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: BtProgress(value: elapsed, thin: true, color: Bt.ink),
                      ),
                      Positioned(
                        left: (x - 1).clamp(0.0, c.maxWidth - 2),
                        top: 0,
                        child: Container(width: 2, height: 30, color: accent),
                      ),
                      Positioned(
                        left: (x - 20).clamp(0.0, c.maxWidth - 40),
                        top: -18,
                        child: Text('TODAY', style: BtText.mono(context, color: context.bt.accentInk, size: 9.5)),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            if (daysLeft != null && project.actualEndDate == null)
              Text(
                daysLeft >= 0 ? '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left' : '${-daysLeft} ${daysLeft == -1 ? 'day' : 'days'} past expected end',
                style: BtText.num(BtText.caption(context, color: daysLeft >= 0 ? Bt.ink3 : Bt.red)),
              ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Bt.line),
          _row(context, 'Start date', _fmt(start)),
          if (end != null) _row(context, 'Expected end', _fmt(end)),
          if (project.actualEndDate != null) _row(context, 'Actual end date', _fmt(project.actualEndDate!), color: Bt.green),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Text(label, style: BtText.subhead(context)),
            const Spacer(),
            Text(value, style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: color ?? Bt.ink))),
          ],
        ),
      );
}
class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    if (!RoleManager.canViewProjectBudget) return _spentOnly(context);
    final bt = context.bt;
    final util = project.budgetUtilization;
    final over = project.spentAmount > project.totalBudget;
    final bMat = project.budgetMaterial ?? 0;
    final bLab = project.budgetLabour ?? 0;
    final bEq = project.budgetEquipment ?? 0;
    final bMisc = project.budgetMisc ?? 0;
    final hasBrk = bMat + bLab + bEq + bMisc > 0;
    final utilColor = util >= 1.0
        ? Bt.redBright
        : util >= 0.8
        ? Bt.amberBright
        : bt.accent;
    final brkTotal = bMat + bLab + bEq + bMisc;
    Widget cat(String label, double amount, Color c, IconData icon) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Icon(icon, size: 15, color: Bt.ink3),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, style: BtText.subhead(context))),
                  Text(formatCurrency(amount), style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
                ],
              ),
              const SizedBox(height: 6),
              BtProgress(value: brkTotal > 0 ? amount / brkTotal : 0, thin: true, color: c),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('FINANCIAL OVERVIEW', style: BtText.mono(context)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Budget used', style: BtText.caption(context)),
                        BtCountUp(
                          value: util * 100,
                          format: (v) => '${v.toStringAsFixed(0)}%',
                          style: BtText.num(BtText.d2(context, color: util >= 1.0 ? Bt.red : Bt.ink)),
                        ),
                      ],
                    ),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: project.formattedSpent, style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: over ? Bt.red : Bt.ink))),
                      TextSpan(text: ' of ${project.formattedBudget}', style: BtText.num(BtText.subhead(context))),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BtBricks(value: util.clamp(0.0, 1.0).toDouble(), color: utilColor),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Bt.line),
              const SizedBox(height: 4),
              _frow(context, 'Total budget', project.formattedBudget, Bt.ink),
              _frow(context, 'Spent amount', project.formattedSpent, over ? Bt.red : Bt.ink),
              _frow(context, 'Remaining', project.formattedRemaining, project.remainingBudget >= 0 ? Bt.green : Bt.red),
            ],
          ),
        ),
        if (hasBrk) ...[
          const SizedBox(height: 12),
          BtCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Budget breakdown', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                if (bMat > 0) cat('Material', bMat, bt.series[0], Icons.inventory_2_outlined),
                if (bLab > 0) cat('Labour', bLab, bt.series[1], Icons.groups_outlined),
                if (bEq > 0) cat('Equipment', bEq, bt.series[2], Icons.local_shipping_outlined),
                if (bMisc > 0) cat('Miscellaneous', bMisc, Bt.amberBright, Icons.more_horiz_rounded),
              ],
            ),
          ),
        ],
      ],
    );
  }
  /// Users without "Project budget" access see what was spent, never the
  /// budget, budget used or remaining.
  Widget _spentOnly(BuildContext context) {
    return BtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SPENDING', style: BtText.mono(context)),
          const SizedBox(height: 10),
          Text('Spent so far', style: BtText.caption(context)),
          BtCountUp(
            value: project.spentAmount,
            format: (v) => formatCurrency(v),
            style: BtText.num(BtText.d2(context)),
          ),
          const SizedBox(height: 8),
          Text('Budget figures are visible to admins and people given Project budget access.', style: BtText.caption(context)),
        ],
      ),
    );
  }
  Widget _frow(BuildContext context, String label, String value, Color color) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Text(label, style: BtText.subhead(context)),
            const Spacer(),
            Text(value, style: BtText.num(BtText.body(context, weight: FontWeight.w600, color: color))),
          ],
        ),
      );
}
class _RecentEntriesSection extends StatelessWidget {
  const _RecentEntriesSection({
    required this.project,
    required this.provider,
    this.currentUserId,
  });
  final ProjectModel project;
  final ProjectProvider provider;
  final String? currentUserId;
  @override
  Widget build(BuildContext context) {
    final isAdmin = UserSession.isAdmin;
    final isSupervisor = UserSession.isSupervisor || RoleManager.isSupervisor;
    final hasProjectAccess = UserSession.hasProjectAccess(project.id);
    final allEntries = provider.entriesForProject(project.id).toList();
    final filtered = allEntries.where((e) {
      if (e.approvalStatus.toLowerCase().trim() != 'approved') return false;
      if (isAdmin || isSupervisor || hasProjectAccess) return true;
      if (currentUserId != null && currentUserId!.isNotEmpty && e.createdBy == currentUserId) {
        return true;
      }
      return false;
    }).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    final entries = filtered.take(3).toList();
    final canAddEntry = logEntryKinds.any((k) => logKindAllowed(k.$1));
    // Stretch: with `start`, the empty-state card shrank to its content and sat
    // off to the left.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(
          title: 'Recent activity',
          action: entries.isEmpty ? null : 'View all',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _AllProjectEntriesScreen(
                  project: project,
                  provider: provider,
                  currentUserId: currentUserId,
                  isAdmin: isAdmin,
                ),
              ),
            );
          },
        ),
        if (entries.isEmpty)
          BtCard(
            padding: EdgeInsets.zero,
            child: BtEmpty(
              icon: Icons.history_toggle_off_rounded,
              title: 'No entries yet',
              message: 'Material, labour and equipment logged for this project will show up here.',
              action: canAddEntry ? 'Add entry' : null,
              onAction: canAddEntry ? () => _showAddEntrySheet(context, project: project) : null,
            ),
          )
        else
          BtGroup(children: [for (final e in entries) _EntryTile(entry: e)]),
      ],
    );
  }
}
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final EntryModel entry;
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  void _navigateToDetailFallback(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/entry-detail',
      arguments: {
        'id': entry.id,
        'title': entry.description.isEmpty
            ? entry.type.label
            : entry.description,
        'ref': entry.id.length > 4
            ? '#${entry.id.substring(entry.id.length - 4)}'
            : '#${entry.id}',
        'amount': '+${entry.amount}',
        'date': entry.date.toIso8601String(),
        'isPositive': true,
        'type': entry.type.name,
        'name': entry.description.isEmpty
            ? entry.type.label
            : entry.description,
        'projectId': entry.projectId,
        'status': 'pending',
        'paymentStatus': PaymentStatus.pending,
        'billAmount': entry.amount,
        'paidAmount': 0.0,
      },
    ).then((_) {
      if (context.mounted) {
        context.read<ProjectProvider>().load();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final d = entry.date;
    final dateStr = '${d.day} ${_months[d.month - 1]} ${d.year}';
    // A plain list row inside a BtGroup (like the rest of the app) instead of
    // a separate floating card per entry.
    return BtRow(
      leading: BtTypeTile(type: entry.type.name),
      title: entry.description.isEmpty ? entry.type.label : entry.description,
      subtitle: '${entry.type.label} · $dateStr',
      trailing: Text(
        formatCurrency(entry.amount),
        style: BtText.num(BtText.body(context, weight: FontWeight.w600)),
      ),
      onTap: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (lCtx) => const Center(
            child: CircularProgressIndicator(color: Bt.bone),
          ),
        );
        try {
          final response = await ApiService.get('/transactions');
          if (context.mounted) Navigator.pop(context);
          if (response.statusCode == 200) {
            final decoded = json.decode(response.body);
            List<dynamic> raw = [];
            if (decoded is List) {
              raw = decoded;
            } else if (decoded is Map) {
              raw =
                  (decoded['transactions'] ??
                          decoded['data'] ??
                          decoded['items'] ??
                          [])
                      as List<dynamic>;
            }
            Map<String, dynamic>? matched;
            for (final t in raw) {
              final tId = t['_id']?.toString() ?? '';
              if (tId == entry.id) {
                matched = Map<String, dynamic>.from(t);
                break;
              }
            }
            if (matched != null) {
              String? statusStr = matched['paymentStatus']?.toString();
              PaymentStatus payStatus = PaymentStatus.pending;
              if (statusStr != null) {
                final lower = statusStr.trim().toLowerCase();
                if (lower == 'paid') payStatus = PaymentStatus.paid;
                if (lower == 'partial') payStatus = PaymentStatus.partial;
                if (lower == 'overdue') payStatus = PaymentStatus.overdue;
              }
              final String rawCat = (matched['category'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              final String rawType = (matched['type'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              String category = 'material';
              if (rawCat == 'labour' ||
                  rawCat == 'wages' ||
                  rawCat == 'labor' ||
                  rawCat.contains('labour') ||
                  rawType == 'wages' ||
                  rawType == 'labour') {
                category = 'labour';
              } else if (rawCat == 'equipment' ||
                  rawCat == 'machinery' ||
                  rawCat == 'expense' ||
                  rawType == 'expense' ||
                  rawType == 'equipment') {
                category = 'equipment';
              }
              bool isPositive = true;
              if (matched['subType']?.toString().toLowerCase() ==
                  'consumption') {
                isPositive = false;
              }
              final String tId = matched['_id']?.toString() ?? '';
              final String ref = tId.length > 4
                  ? '#${tId.substring(tId.length - 4)}'
                  : '#${tId.isNotEmpty ? tId : DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
              final Map<String, dynamic> mappedArgs = {
                ...matched,
                'id': tId,
                'title':
                    matched['title'] ?? matched['materialName'] ?? 'Unknown',
                'ref': ref,
                'amount':
                    '${isPositive ? "+" : "-"}${matched['quantity'] ?? 0}',
                'date': matched['date'] ?? '',
                'isPositive': isPositive,
                'type': category,
                'name':
                    matched['title'] ?? matched['materialName'] ?? 'Unknown',
                'receipt':
                    (matched['attachments'] is List &&
                        matched['attachments'].isNotEmpty)
                    ? matched['attachments'].first?.toString()
                    : null,
                'attachment': null,
                'createdBy': matched['createdBy'] ?? '',
                'projectId': entry.projectId,
                'status': matched['status'] ?? 'pending',
                'paymentStatus': payStatus,
                'billAmount': (matched['amount'] ?? 0).toDouble(),
                'paidAmount': (matched['paidAmount'] ?? 0).toDouble(),
                'supplier': matched['supplier'] ?? '',
                'paymentMethod': matched['paymentMode'] ?? '',
                'lastUpdated': matched['updatedAt'] ?? matched['date'] ?? '',
                'paymentHistory': matched['paymentHistory'],
                'rate': (matched['rate'] ?? 0).toDouble(),
                'brand': matched['brand'] ?? '',
                'notes': matched['notes'] ?? '',
                'remarks': matched['remarks'] ?? '',
                'categoryName': matched['category'] ?? '',
                'quantity': (matched['quantity'] ?? 0).toDouble(),
                'overtime': (matched['overtime'] ?? 0).toDouble(),
                'subType': matched['subType'] ?? '',
                'materialType': matched['materialType'] ?? '',
              };
              if (context.mounted) {
                Navigator.pushNamed(
                  context,
                  '/entry-detail',
                  arguments: mappedArgs,
                ).then((_) {
                  if (context.mounted) {
                    context.read<ProjectProvider>().load();
                  }
                });
              }
            } else {
              if (context.mounted) _navigateToDetailFallback(context);
            }
          } else {
            if (context.mounted) _navigateToDetailFallback(context);
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
            _navigateToDetailFallback(context);
          }
        }
      },
    );
  }
}
/// Entry point to the project insights screen (budgets, forecast, spend, cash).
class _InsightsEntryCard extends StatelessWidget {
  const _InsightsEntryCard({required this.project});
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: 'Project insights. Phase budgets, forecast, spend & cash',
      excludeSemantics: true,
      child: BtCard(
        variant: BtCardVariant.ink,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectInsightsScreen(projectId: project.id, projectName: project.name),
          ),
        ),
        child: Row(
          children: [
            BtTile(icon: Icons.insights_rounded, bg: Colors.white.withValues(alpha: .08), fg: bt.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Project insights', style: BtText.body(context, weight: FontWeight.w600, color: Bt.bone)),
                  Text('Phase budgets, forecast, spend & cash', style: BtText.caption(context, color: Bt.onNoir2)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Bt.onNoir3, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final canAddEntry = RoleManager.canManageExpenses;
    final canEdit = RoleManager.canEditProject;
    if (!canAddEntry && !canEdit) {
      return BtCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Bt.ink3, size: 18),
            const SizedBox(width: 10),
            Text('No project actions permitted', style: BtText.subhead(context, color: Bt.ink3)),
          ],
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canAddEntry)
          _QuickAction(
            icon: Icons.add_rounded,
            label: 'Add entry',
            highlight: true,
            onTap: () => Navigator.pushNamed(context, '/add-entry'),
          ),
        if (canEdit)
          _QuickAction(
            icon: Icons.edit_outlined,
            label: 'Edit project',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProjectScreen(project: project),
                ),
              ).then((_) => context.read<ProjectProvider>().load());
            },
          ),
      ],
    );
  }
}

/// Round-square quick action with a label underneath (Overview).
class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.highlight = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BtPressable(
        onTap: onTap,
        scale: .94,
        child: SizedBox(
          width: 96,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: highlight ? Bt.noir : Bt.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: Bt.shadow,
                ),
                child: Icon(icon, size: 24, color: highlight ? bt.accent : Bt.ink),
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
class _AllProjectEntriesScreen extends StatelessWidget {
  const _AllProjectEntriesScreen({
    required this.project,
    required this.provider,
    this.currentUserId,
    this.isAdmin = false,
  });
  final ProjectModel project;
  final ProjectProvider provider;
  final String? currentUserId;
  final bool isAdmin;
  @override
  Widget build(BuildContext context) {
    final isSupervisor = UserSession.isSupervisor || RoleManager.isSupervisor;
    final hasProjectAccess = UserSession.hasProjectAccess(project.id);
    final allEntries = provider.entriesForProject(project.id).toList();
    final entries = allEntries.where((e) {
      if (e.approvalStatus.toLowerCase().trim() != 'approved') return false;
      if (isAdmin || isSupervisor || hasProjectAccess) return true;
      if (currentUserId != null && currentUserId!.isNotEmpty && e.createdBy == currentUserId) {
        return true;
      }
      return false;
    }).toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    final canEdit = RoleManager.canEditProject;
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: project.name,
        subtitle: 'Recent activity',
        trailing: canEdit
            ? BtIconButton(
                icon: Icons.edit_outlined,
                semantic: 'Edit project',
                color: Bt.ink2,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProjectScreen(project: project),
                    ),
                  ).then((_) => context.read<ProjectProvider>().load());
                },
              )
            : null,
      ),
      body: entries.isEmpty
          ? const Center(
              child: BtEmpty(
                icon: Icons.history_toggle_off_rounded,
                title: 'No entries yet',
                message: 'Material, labour and equipment logged for this project will show up here.',
              ),
            )
          : ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                BtReveal(child: BtGroup(children: [for (final e in entries) _EntryTile(entry: e)])),
              ],
            ),
    );
  }
}
class _GalleryDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  const _GalleryDialog({required this.photos, required this.initialIndex});
  @override
  State<_GalleryDialog> createState() => _GalleryDialogState();
}
class _GalleryDialogState extends State<_GalleryDialog> {
  late int _currentIndex;
  late PageController _pageController;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withValues(alpha: 0.9),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              final photoUrl = widget.photos[index];
              Widget imageWidget;
              if (photoUrl.startsWith('data:image/') &&
                  photoUrl.contains(';base64,')) {
                try {
                  final base64String = photoUrl.split(';base64,').last;
                  final bytes = base64.decode(base64String);
                  imageWidget = Image.memory(bytes, fit: BoxFit.contain);
                } catch (e) {
                  imageWidget = const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 48,
                  );
                }
              } else {
                imageWidget = Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 48,
                    );
                  },
                );
              }
              return InteractiveViewer(
                maxScale: 4.0,
                minScale: 1.0,
                child: Center(child: imageWidget),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(Bt.rCard),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _CsvImportExportCard extends StatefulWidget {
  const _CsvImportExportCard({required this.project});
  final ProjectModel project;
  @override
  State<_CsvImportExportCard> createState() => _CsvImportExportCardState();
}
class _CsvImportExportCardState extends State<_CsvImportExportCard> {
  bool _isUploading = false;
  Future<void> _downloadTemplate() async {
    final List<List<dynamic>> csvRows = [
      [
        'Phase',
        'Sl.No',
        'Particular',
        'Total_Qty',
        'Unit',
        'Material_Rate',
        'Budget_Material_Amount',
        'Labour_Rate',
        'Budget_Labour_Amount',
        'Equipment_Rate',
        'Budget_Equipment_Amount',
        'Total_Amount',
      ],
    ];
    if (widget.project.selectedPhases != null &&
        widget.project.selectedPhases!.isNotEmpty) {
      for (final phase in widget.project.selectedPhases!) {
        int slNo = 1;
        for (final act in phase.activities) {
          final double matAmt = act.budgetMaterial ?? 0.0;
          final double labAmt = act.budgetLabour ?? 0.0;
          final double eqAmt = act.budgetEquipment ?? 0.0;
          final double totAmt = matAmt + labAmt + eqAmt;
          final double qty = act.qty ?? 1.0;
          final String unit = act.unit ?? '';
          final double matRate = act.materialRate ?? 0.0;
          final double labRate = act.labourRate ?? 0.0;
          final double eqRate = act.equipmentRate ?? 0.0;
          csvRows.add([
            phase.phaseName,
            slNo++,
            act.name,
            qty > 0 ? qty.toStringAsFixed(2) : '',
            unit,
            matRate > 0 ? matRate.toStringAsFixed(2) : '',
            matAmt > 0 ? matAmt.toStringAsFixed(2) : '',
            labRate > 0 ? labRate.toStringAsFixed(2) : '',
            labAmt > 0 ? labAmt.toStringAsFixed(2) : '',
            eqRate > 0 ? eqRate.toStringAsFixed(2) : '',
            eqAmt > 0 ? eqAmt.toStringAsFixed(2) : '',
            totAmt > 0 ? totAmt.toStringAsFixed(2) : '',
          ]);
        }
      }
    } else {
      final defaultPhases = buildDefaultPhases();
      for (final phase in defaultPhases) {
        int slNo = 1;
        for (final act in phase.allActivities) {
          final double matAmt = act.budgetMaterial ?? 0.0;
          final double labAmt = act.budgetLabour ?? 0.0;
          final double eqAmt = act.budgetEquipment ?? 0.0;
          final double totAmt = matAmt + labAmt + eqAmt;
          final double qty = act.qty ?? 1.0;
          final String unit = act.unit ?? '';
          final double matRate = act.materialRate ?? 0.0;
          final double labRate = act.labourRate ?? 0.0;
          final double eqRate = act.equipmentRate ?? 0.0;
          csvRows.add([
            phase.name,
            slNo++,
            act.name,
            qty > 0 ? qty.toStringAsFixed(2) : '',
            unit,
            matRate > 0 ? matRate.toStringAsFixed(2) : '',
            matAmt > 0 ? matAmt.toStringAsFixed(2) : '',
            labRate > 0 ? labRate.toStringAsFixed(2) : '',
            labAmt > 0 ? labAmt.toStringAsFixed(2) : '',
            eqRate > 0 ? eqRate.toStringAsFixed(2) : '',
            eqAmt > 0 ? eqAmt.toStringAsFixed(2) : '',
            totAmt > 0 ? totAmt.toStringAsFixed(2) : '',
          ]);
        }
      }
    }
    final csvContent = const ListToCsvConverter().convert(csvRows);
    final filename =
        '${widget.project.name.replaceAll(' ', '_')}_phases_template.csv';
    try {
      await saveAndShareCsv(
        csvContent: csvContent,
        filename: filename,
        shareText: 'Exported phase CSV for ${widget.project.name}',
      );
      if (mounted) {
        btToast(context, 'CSV exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Failed to export CSV: $e', error: true);
      }
    }
  }
  Future<void> _uploadCsv() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }
      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        throw Exception("Failed to read file data");
      }
      final csvString = utf8.decode(fileBytes);
      final List<List<dynamic>> parsedCsv = const CsvToListConverter().convert(
        csvString,
      );
      if (parsedCsv.isEmpty || parsedCsv.length <= 1) {
        throw Exception("CSV file is empty or missing headers");
      }
      final headers = parsedCsv.first
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final phaseIdx = headers.indexOf('phase');
      final particularIdx = headers.indexOf('particular');
      int qtyIdx = headers.indexOf('total_qty');
      if (qtyIdx == -1) qtyIdx = headers.indexOf('qty');
      final matRateIdx = headers.indexOf('material_rate');
      int matAmtIdx = headers.indexOf('budget_material_amount');
      if (matAmtIdx == -1) matAmtIdx = headers.indexOf('material_amount');
      final labRateIdx = headers.indexOf('labour_rate');
      int labAmtIdx = headers.indexOf('budget_labour_amount');
      if (labAmtIdx == -1) labAmtIdx = headers.indexOf('labour_amount');
      final eqRateIdx = headers.indexOf('equipment_rate');
      int eqAmtIdx = headers.indexOf('budget_equipment_amount');
      if (eqAmtIdx == -1) eqAmtIdx = headers.indexOf('equipment_amount');
      if (phaseIdx == -1 || particularIdx == -1) {
        throw Exception(
          "CSV is missing required 'Phase' or 'Particular' column headers",
        );
      }
      double? parseVal(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        final str = v.toString().trim();
        if (str.isEmpty) return null;
        final clean = str.replaceAll(RegExp(r'[^\d\.]'), '');
        return double.tryParse(clean);
      }
      List<ProjectPhase> updatedPhases = [];
      if (widget.project.selectedPhases != null &&
          widget.project.selectedPhases!.isNotEmpty) {
        updatedPhases = List<ProjectPhase>.from(widget.project.selectedPhases!);
      } else {
        final defaultPhases = buildDefaultPhases();
        updatedPhases = defaultPhases.map((cp) {
          return ProjectPhase(
            id: 'phase_${cp.name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
            phaseName: cp.name,
            isCustom: cp.isCustom,
            activities: cp.allActivities.map((ca) {
              return ProjectActivity(
                id: ca.key,
                name: ca.name,
                isCustom: ca.isCustom,
                completed: false,
                budgetMaterial: 0.0,
                budgetLabour: 0.0,
                budgetEquipment: 0.0,
              );
            }).toList(),
          );
        }).toList();
      }
      int updatedCount = 0;
      for (int i = 1; i < parsedCsv.length; i++) {
        final row = parsedCsv[i];
        final maxIdx = phaseIdx > particularIdx ? phaseIdx : particularIdx;
        if (row.length <= maxIdx) continue;
        final String phaseName = row[phaseIdx].toString().trim();
        final String activityName = row[particularIdx].toString().trim();
        if (phaseName.isEmpty || activityName.isEmpty) continue;
        final double? qty = qtyIdx != -1 && qtyIdx < row.length
            ? parseVal(row[qtyIdx])
            : null;
        final double? matRate = matRateIdx != -1 && matRateIdx < row.length
            ? parseVal(row[matRateIdx])
            : null;
        double? matAmt = matAmtIdx != -1 && matAmtIdx < row.length
            ? parseVal(row[matAmtIdx])
            : null;
        if (matAmt == null && matRate != null && qty != null) {
          matAmt = qty * matRate;
        }
        final double? labRate = labRateIdx != -1 && labRateIdx < row.length
            ? parseVal(row[labRateIdx])
            : null;
        double? labAmt = labAmtIdx != -1 && labAmtIdx < row.length
            ? parseVal(row[labAmtIdx])
            : null;
        if (labAmt == null && labRate != null && qty != null) {
          labAmt = qty * labRate;
        }
        final double? eqRate = eqRateIdx != -1 && eqRateIdx < row.length
            ? parseVal(row[eqRateIdx])
            : null;
        double? eqAmt = eqAmtIdx != -1 && eqAmtIdx < row.length
            ? parseVal(row[eqAmtIdx])
            : null;
        if (eqAmt == null && eqRate != null && qty != null) {
          eqAmt = qty * eqRate;
        }
        int phaseIndex = updatedPhases.indexWhere(
          (p) => p.phaseName.trim().toLowerCase() == phaseName.toLowerCase(),
        );
        if (phaseIndex == -1) {
          final newPhase = ProjectPhase(
            id: 'phase_${phaseName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
            phaseName: phaseName,
            isCustom: true,
            activities: [],
          );
          updatedPhases.add(newPhase);
          phaseIndex = updatedPhases.length - 1;
        }
        final phase = updatedPhases[phaseIndex];
        final activities = List<ProjectActivity>.from(phase.activities);
        final actIndex = activities.indexWhere(
          (a) => a.name.trim().toLowerCase() == activityName.toLowerCase(),
        );
        if (actIndex != -1) {
          final currentAct = activities[actIndex];
          activities[actIndex] = currentAct.copyWith(
            budgetMaterial: matAmt ?? currentAct.budgetMaterial,
            budgetLabour: labAmt ?? currentAct.budgetLabour,
            budgetEquipment: eqAmt ?? currentAct.budgetEquipment,
            qty: qty ?? currentAct.qty,
            materialRate: matRate ?? currentAct.materialRate,
            labourRate: labRate ?? currentAct.labourRate,
            equipmentRate: eqRate ?? currentAct.equipmentRate,
          );
        } else {
          final newAct = ProjectActivity(
            id: 'act_${activityName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
            name: activityName,
            isCustom: true,
            completed: false,
            budgetMaterial: matAmt ?? 0.0,
            budgetLabour: labAmt ?? 0.0,
            budgetEquipment: eqAmt ?? 0.0,
            qty: qty,
            materialRate: matRate,
            labourRate: labRate,
            equipmentRate: eqRate,
          );
          activities.add(newAct);
        }
        updatedPhases[phaseIndex] = phase.copyWith(activities: activities);
        updatedCount++;
      }
      double materialSum = 0;
      double labourSum = 0;
      double equipmentSum = 0;
      for (final phase in updatedPhases) {
        for (final act in phase.activities) {
          materialSum += act.budgetMaterial ?? 0.0;
          labourSum += act.budgetLabour ?? 0.0;
          equipmentSum += act.budgetEquipment ?? 0.0;
        }
      }
      final double totalSum =
          materialSum +
          labourSum +
          equipmentSum +
          (widget.project.budgetMisc ?? 0.0);
      final updatedProject = widget.project.copyWith(
        selectedPhases: updatedPhases,
        budgetMaterial: materialSum,
        budgetLabour: labourSum,
        budgetEquipment: equipmentSum,
        totalBudget: totalSum,
      );
      await context.read<ProjectProvider>().updateProject(updatedProject);
      if (mounted) {
        btToast(context, 'Successfully imported budget for $updatedCount activities!');
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Upload failed: $e', error: true);
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return BtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BtTile(icon: Icons.table_chart_outlined, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phases & budget configuration', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                    Text('Import/Export CSV budgets for all phases.', style: BtText.caption(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BtButton(
                  label: 'Export CSV',
                  icon: Icons.download_rounded,
                  small: true,
                  variant: BtButtonVariant.secondary,
                  onPressed: _downloadTemplate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BtButton(
                  label: 'Upload CSV',
                  icon: Icons.upload_file_rounded,
                  small: true,
                  variant: BtButtonVariant.secondary,
                  loading: _isUploading,
                  onPressed: _isUploading ? null : _uploadCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _SitePhotoCard extends StatelessWidget {
  final String photoUrl;
  const _SitePhotoCard({required this.photoUrl});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: Bt.noir3,
        borderRadius: BorderRadius.circular(Bt.rCard),
        boxShadow: Bt.shadow,
        image: DecorationImage(
          image: NetworkImage(
            photoUrl.startsWith('http') 
              ? photoUrl 
              : '${ApiService.baseUrl.replaceAll('/api', '')}$photoUrl'
          ),
          fit: BoxFit.cover,
        ),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0x990C0E12), borderRadius: BorderRadius.circular(10)),
        child: Text('SITE PHOTO', style: BtText.mono(context, color: Bt.bone)),
      ),
    );
  }
}

class _ProjectScopeCard extends StatelessWidget {
  final String scope;
  const _ProjectScopeCard({required this.scope});
  @override
  Widget build(BuildContext context) {
    return BtCard(
      child: Text(
        scope,
        style: BtText.subhead(context, color: Bt.ink).copyWith(height: 1.5),
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  final List<String> documents;
  const _DocumentsCard({required this.documents});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: documents.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final name = documents[i].split("/").last;
          final dot = name.lastIndexOf('.');
          final ext = dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toUpperCase() : 'FILE';
          return SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 88,
                  decoration: BoxDecoration(color: Bt.noir, borderRadius: BorderRadius.circular(Bt.rTile)),
                  child: Stack(
                    children: [
                      const Center(child: Icon(Icons.insert_drive_file_outlined, color: Bt.onNoir3, size: 30)),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(6)),
                          child: Text(ext.length > 4 ? ext.substring(0, 4) : ext, style: BtText.mono(context, color: Bt.bone, size: 9.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.ink, weight: FontWeight.w500)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Budget amount input for the activity budget sheet: empty with a "0" hint
/// when there is no budget, and the whole value selected on focus so a new
/// figure replaces it instead of being appended.
class _BudgetAmountField extends StatefulWidget {
  const _BudgetAmountField({required this.controller});
  final TextEditingController controller;
  @override
  State<_BudgetAmountField> createState() => _BudgetAmountFieldState();
}

class _BudgetAmountFieldState extends State<_BudgetAmountField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) return;
    final c = widget.controller;
    if (c.text.isEmpty) return;
    // After the tap has placed the caret, select everything.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus) return;
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: BtText.num(BtText.body(context)),
      decoration: btInput(context, hint: '0', prefixText: '₹ '),
    );
  }
}

/// "Add entry" from a project (optionally for one phase + activity): pick
/// Material / Labour / Equipment (same tiles and RoleManager gates as the log
/// sheet), then open the existing where-step with this project, phase and
/// activity already chosen so the user only confirms.
Future<void> _showAddEntrySheet(
  BuildContext context, {
  required ProjectModel project,
  ProjectPhase? phase,
  ProjectActivity? activity,
}) {
  final kinds = logEntryKinds.where((k) => logKindAllowed(k.$1)).toList();
  if (kinds.isEmpty) {
    btToast(context, 'You do not have permission to add entries.', error: true);
    return Future.value();
  }
  final floors = project.floors ?? const <String>[];
  final where = [if (phase != null) phase.phaseName, if (activity != null) activity.name].join(' · ');
  final nav = Navigator.of(context);
  return showBtSheet<void>(
    context,
    title: 'Add entry',
    subtitle: where.isNotEmpty ? where : project.name,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < kinds.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: BtReveal(
                  index: i,
                  child: LogKindTile(
                    type: kinds[i].$1,
                    title: kinds[i].$2,
                    subtitle: kinds[i].$3,
                    height: 160,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      nav.pushNamed('/execution-context', arguments: <String, dynamic>{
                        'type': kinds[i].$1,
                        'projectId': project.id,
                        if (phase != null) ...{
                          // Phases/activities aren't tied to a floor; prefill
                          // it only when the project has exactly one (otherwise
                          // the where-step keeps the last floor or asks).
                          if (floors.length == 1) 'floor': floors.first,
                          'phase': phase.phaseName,
                          'phaseId': phase.id,
                        },
                        if (activity != null) ...{
                          'activity': activity.name,
                          'activityId': activity.id,
                        },
                      });
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text('Tap a type to continue', textAlign: TextAlign.center, style: BtText.caption(ctx)),
      ],
    ),
  );
}
