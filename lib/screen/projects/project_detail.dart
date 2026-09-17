import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
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
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/screen/projects/edit_project.dart';
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
class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final Set<String> _expanded = {};
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
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.selectedProject;
    if (project == null) {
      return Scaffold(
        backgroundColor: AppColors.gradientStart,
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Project Detail',
                isSubScreen: true,
                leftIcon: Icons.arrow_back,
                onLeftTap: () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: AppEmptyState(
                  icon: Icons.folder_open_outlined,
                  message:
                      'No project selected.\nGo back and select a project.',
                ),
              ),
            ],
          ),
        ),
      );
    }
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
    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: project.name,
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
              rightWidget: RoleManager.canAssignTasks
                  ? IconButton(
                      icon: const Icon(
                        Icons.assignment_turned_in,
                        color: AppColors.primary,
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/assign-task'),
                    )
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(
                      project: project,
                      progress: progress,
                      doneCount: trackerDone,
                      totalCount: trackerTotal,
                    ),
                    const SizedBox(height: 14),
                    const AppSectionHeader(title: 'Project Information'),
                    _ProjectInfoCard(project: project),
                    const SizedBox(height: 14),
                    if (project.projectType != null &&
                        project.projectType!.isNotEmpty) ...[
                      const AppSectionHeader(title: 'Building Type'),
                      _BuildingTypeCard(project: project),
                      const SizedBox(height: 14),
                    ],
                    if ((project.landArea != null &&
                            project.landArea!.isNotEmpty) ||
                        (project.floors != null &&
                            project.floors!.isNotEmpty)) ...[
                      const AppSectionHeader(
                        title: 'Land & Floor Configuration',
                      ),
                      _LandFloorsCard(project: project),
                      const SizedBox(height: 14),
                    ],
                    if ((project.room1BHK ?? 0) +
                            (project.room2BHK ?? 0) +
                            (project.room3BHK ?? 0) +
                            (project.roomCustom ?? 0) +
                            (project.bathWestern ?? 0) +
                            (project.bathIndian ?? 0) +
                            (project.bathCommon ?? 0) +
                            (project.bathAttached ?? 0) >
                        0) ...[
                      const AppSectionHeader(title: 'Rooms & Bathrooms'),
                      _RoomsBathsCard(project: project),
                      const SizedBox(height: 14),
                    ],
                    if (project.selectedFeatures != null &&
                        project.selectedFeatures!.isNotEmpty)
                      ..._buildConfigSections(project.selectedFeatures!),
                    if (project.photo != null && project.photo!.isNotEmpty) ...[
                      const AppSectionHeader(title: 'Site Photo'),
                      _SitePhotoCard(photoUrl: project.photo!),
                      const SizedBox(height: 14),
                    ],
                    if (project.scope != null && project.scope!.isNotEmpty) ...[
                      const AppSectionHeader(title: 'Project Scope'),
                      _ProjectScopeCard(scope: project.scope!),
                      const SizedBox(height: 14),
                    ],
                    if (project.documents != null && project.documents!.isNotEmpty) ...[
                      const AppSectionHeader(title: 'Documents & Blueprints'),
                      _DocumentsCard(documents: project.documents!),
                      const SizedBox(height: 14),
                    ],
                    const AppSectionHeader(title: 'Timeline & Status'),
                    _ProjectTimelineCard(project: project),
                    const SizedBox(height: 14),
                    if (UserSession.isAdmin) ...[
                      const AppSectionHeader(title: 'Financial Overview'),
                      _FinancialCard(project: project),
                      const SizedBox(height: 14),
                    ],
                    _CsvImportExportCard(project: project),
                    const SizedBox(height: 14),
                    AppSectionHeader(
                      title: 'Execution Tracker',
                      actionLabel: hasNewTracker
                          ? '$trackerDone/$trackerTotal done'
                          : null,
                    ),
                    if (hasNewTracker) ...[
                      ...selectedPhases.map(
                        (phase) => _TrackerPhaseCard(
                          phase: phase,
                          project: project,
                          isExpanded: _expanded.contains(phase.id),
                          onToggleExpand: () => setState(() {
                            if (_expanded.contains(phase.id)) {
                              _expanded.remove(phase.id);
                            } else {
                              _expanded.add(phase.id);
                            }
                          }),
                          onToggleActivity: (activityId) {
                            context
                                .read<ProjectProvider>()
                                .toggleActivityCompletion(
                                  project.id,
                                  activityId,
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFEEF0F5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.checklist_rounded,
                              size: 40,
                              color: Color(0xFFCDD0DA),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No execution plan configured',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select phases & activities when creating a project.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _RecentEntriesSection(
                      project: project,
                      provider: provider,
                      currentUserId: UserSession.userId,
                    ),
                    const SizedBox(height: 14),
                    const AppSectionHeader(title: 'Actions'),
                    _ActionButtons(project: project),
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
    Widget sec(String t, List<String> items, IconData icon) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: t),
        _FeatureGroupCard(icon: icon, title: t, features: items),
        const SizedBox(height: 14),
      ],
    );
    return [
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
    ];
  }
}
class _TrackerPhaseCard extends StatelessWidget {
  const _TrackerPhaseCard({
    required this.phase,
    required this.project,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleActivity,
  });
  final ProjectPhase phase;
  final ProjectModel project;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(String activityId) onToggleActivity;
  @override
  Widget build(BuildContext context) {
    final done = phase.completedCount;
    final total = phase.totalCount;
    final pct = total > 0 ? done / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: phase.isCustom
                          ? const Color(0xFF7B3FE7).withValues(alpha: 0.10)
                          : AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      phase.isCustom
                          ? Icons.star_rounded
                          : Icons.construction_rounded,
                      color: phase.isCustom
                          ? const Color(0xFF7B3FE7)
                          : AppColors.primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phase.phaseName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$done of $total activities done',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: pct >= 1.0
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 3,
                  backgroundColor: const Color(0xFFEEF0F8),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 1.0 ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: Color(0xFFEEF0F5)),
                ...phase.activities.map(
                  (act) => _TrackerActivityRow(
                    activity: act,
                    project: project,
                    phaseName: phase.phaseName,
                    onToggle: () => onToggleActivity(act.id),
                  ),
                ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
class _TrackerActivityRow extends StatefulWidget {
  const _TrackerActivityRow({
    required this.activity,
    required this.project,
    required this.phaseName,
    required this.onToggle,
  });
  final ProjectActivity activity;
  final ProjectModel project;
  final String phaseName;
  final VoidCallback onToggle;
  @override
  State<_TrackerActivityRow> createState() => _TrackerActivityRowState();
}
class _TrackerActivityRowState extends State<_TrackerActivityRow> {
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

    final materialController = TextEditingController(
      text: (currentActivity.budgetMaterial ?? 0.0).toStringAsFixed(0),
    );
    final labourController = TextEditingController(
      text: (currentActivity.budgetLabour ?? 0.0).toStringAsFixed(0),
    );
    final equipmentController = TextEditingController(
      text: (currentActivity.budgetEquipment ?? 0.0).toStringAsFixed(0),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Budget Allocation: ${currentActivity.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Allocate activity budgets under Materials, Labour, and Equipment categories.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              _buildDialogTextField('Materials Budget (₹)', materialController),
              const SizedBox(height: 12),
              _buildDialogTextField('Labour Budget (₹)', labourController),
              const SizedBox(height: 12),
              _buildDialogTextField(
                'Equipment Budget (₹)',
                equipmentController,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Budget updated successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to update budget. Please try again.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Budget Allocation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildDialogTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDE0F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEF0F5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
        ),
      ],
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Budget Allocation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              GestureDetector(
                onTap: () => _openUpdateBudgetDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 10,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Update Budget',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBudgetItem(
            label: 'Materials',
            category: matCat,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildBudgetItem(
            label: 'Labour',
            category: labCat,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildBudgetItem(
            label: 'Equipment',
            category: equCat,
            color: const Color(0xFFF59E0B),
          ),
          const Divider(height: 16, color: Color(0xFFE5E7EB)),
          _buildBudgetItem(
            label: 'Total Budget',
            category: totalCat,
            color: const Color(0xFF7C3AED),
            isBold: true,
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
  }) {
    final spent = category.spent;
    final allocated = category.allocated;
    final remaining = category.remaining;
    final pct = category.progress;
    final isOver = spent > allocated && allocated > 0;
    final barColor = isOver ? const Color(0xFFEF4444) : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold
                    ? const Color(0xFF1F2937)
                    : const Color(0xFF4B5563),
              ),
            ),
            Text(
              '${formatCurrency(spent)} / ${formatCurrency(allocated)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: isOver
                    ? const Color(0xFFEF4444)
                    : (isBold
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF374151)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        if (isOver) ...[
          const SizedBox(height: 3),
          Text(
            'Exceeded by ${formatCurrency(spent - allocated)}',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF4444),
            ),
          ),
        ] else if (allocated > 0 && spent > 0) ...[
          const SizedBox(height: 3),
          Text(
            '${formatCurrency(remaining)} remaining',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final done = widget.activity.completed;
    final dateLabel = _completedDateLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: UserSession.isAdmin ? () => setState(() => _isBudgetExpanded = !_isBudgetExpanded) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: widget.onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: done ? AppColors.success : Colors.transparent,
                      border: Border.all(
                        color: done
                            ? AppColors.success
                            : const Color(0xFFCDD0DA),
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                          color: done
                              ? const Color(0xFF9CA3AF)
                              : AppColors.textDark,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: const Color(0xFF9CA3AF),
                        ),
                      ),
                      if (done && dateLabel != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 10,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Completed $dateLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success.withValues(alpha: 0.10)
                        : const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    done ? 'Done' : 'Pending',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: done ? AppColors.success : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _openUpdateProgress(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.20),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'ADD',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                if (done) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showActivityDetails(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'VIEW',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
                if (UserSession.isAdmin) ...[
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _isBudgetExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textLight,
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_isBudgetExpanded && UserSession.isAdmin) _buildBudgetSection(context),
      ],
    );
  }
  void _showActivityDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final maxH = MediaQuery.of(context).size.height * 0.75;
        final formattedDate = _completedDateLabel() ?? 'Completed';
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDE0F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.activity.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.phaseName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Completed on $formattedDate',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          if (widget.activity.notes != null &&
                              widget.activity.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Notes & Remarks',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                widget.activity.notes!,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if ((widget.activity.photos != null &&
                                  widget.activity.photos!.isNotEmpty) ||
                              (widget.activity.photo != null &&
                                  widget.activity.photo!.isNotEmpty)) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Progress Photos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildProgressPhotosList(context, widget.activity),
                          ],
                          if ((widget.activity.notes == null ||
                                  widget.activity.notes!.trim().isEmpty) &&
                              (widget.activity.photo == null ||
                                  widget.activity.photo!.isEmpty) &&
                              (widget.activity.photos == null ||
                                  widget.activity.photos!.isEmpty)) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.grey,
                                      size: 28,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No additional notes or photos recorded for this activity.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildThumbnailImage(String photoUrl) {
    Widget img;
    if (photoUrl.startsWith('data:image/') && photoUrl.contains(';base64,')) {
      try {
        final base64String = photoUrl.split(';base64,').last;
        final bytes = base64.decode(base64String);
        img = Image.memory(bytes, fit: BoxFit.cover, width: 80, height: 80);
      } catch (e) {
        img = Container(
          color: const Color(0xFFF3F4F6),
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.grey,
            size: 24,
          ),
        );
      }
    } else {
      img = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFF3F4F6),
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
              size: 24,
            ),
          );
        },
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: img);
  }
  Widget _buildProgressPhotosList(
    BuildContext context,
    ProjectActivity activity,
  ) {
    final photos = (activity.photos != null && activity.photos!.isNotEmpty)
        ? activity.photos!
        : [activity.photo!];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: photos.asMap().entries.map((entry) {
        final idx = entry.key;
        final url = entry.value;
        return GestureDetector(
          onTap: () => _openPhotoGallery(context, photos, idx),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEF0FF), width: 1.5),
            ),
            child: _buildThumbnailImage(url),
          ),
        );
      }).toList(),
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
  static Color _statusColor(String? status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'In Progress':
        return AppColors.primary;
      case 'On Hold':
        return AppColors.warning;
      case 'Cancelled':
        return AppColors.error;
      default:
        return const Color(0xFF6B7280);
    }
  }
  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(1);
    final rawStatus = project.projectStatus;
    final statusLabel = (rawStatus != null && rawStatus.isNotEmpty)
        ? rawStatus
        : (progress >= 1.0
              ? 'Completed'
              : progress >= 0.3
              ? 'In Progress'
              : 'Planning');
    final statusColor = _statusColor(rawStatus);
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
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: AppTheme.heading2.copyWith(letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(statusLabel, statusColor),
                        if (activePhase != null)
                          _chip(
                            activePhase,
                            AppColors.primary,
                            icon: Icons.play_circle_outline,
                            subtle: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow(Icons.location_on_outlined, project.location),
                    const SizedBox(height: 4),
                    _infoRow(
                      Icons.calendar_today_outlined,
                      'Started ${_fmt(project.startDate)}',
                    ),
                    if (project.expectedEndDate != null) ...[
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.event_available_outlined,
                        'Due ${_fmt(project.expectedEndDate!)}',
                      ),
                    ],
                    if (project.clientName != null &&
                        project.clientName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.person_outline, project.clientName!),
                    ],
                    if (project.projectCode != null &&
                        project.projectCode!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.qr_code_scanner_outlined,
                        project.projectCode!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (project.floors != null && project.floors!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: project.floors!
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEEF0F5), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Completion',
                style: AppTheme.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '$pct%  ($doneCount/$totalCount activities)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: const Color(0xFFE8ECF8),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
  Widget _chip(String label, Color c, {IconData? icon, bool subtle = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: subtle ? c.withValues(alpha: 0.07) : c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: subtle
              ? Border.all(color: c.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: AppColors.textLight, size: 14),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          style: AppTheme.caption.copyWith(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
class _ProjectInfoCard extends StatelessWidget {
  const _ProjectInfoCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[
      if (project.projectCode?.isNotEmpty == true)
        _InfoRow(
          Icons.qr_code_scanner_outlined,
          'Project Code',
          project.projectCode!,
        ),
      if (project.clientName?.isNotEmpty == true)
        _InfoRow(Icons.person_outline, 'Client', project.clientName!),
      if (project.contractorName?.isNotEmpty == true)
        _InfoRow(
          Icons.engineering_outlined,
          'Contractor',
          project.contractorName!,
        ),
      if (project.siteEngineer?.isNotEmpty == true)
        _InfoRow(
          Icons.construction_outlined,
          'Engineer',
          project.siteEngineer!,
        ),
      if (project.contactNumber?.isNotEmpty == true)
        _InfoRow(Icons.phone_outlined, 'Contact', project.contactNumber!),
      if (project.mapAddress?.isNotEmpty == true)
        _InfoRow(Icons.place_outlined, 'Map Address', project.mapAddress!),
      if (project.projectStatus?.isNotEmpty == true)
        _InfoRow(Icons.flag_outlined, 'Status', project.projectStatus!),
      _InfoRow(Icons.location_on_outlined, 'Location', project.location),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          if (project.projectCode?.isNotEmpty == true) ...[
            _buildProjectCodeChip(project.projectCode!),
            const AppDivider(verticalPadding: 10),
          ],
          ...rows
              .where((r) => r.label != 'Project Code')
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(r.icon, color: AppColors.primary, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.label,
                              style: AppTheme.caption.copyWith(
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              r.value,
                              style: AppTheme.body.copyWith(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
  Widget _buildProjectCodeChip(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_scanner_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project Code',
                  style: AppTheme.caption.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'Auto-generated',
                  style: AppTheme.caption.copyWith(
                    fontSize: 9,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
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
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(mainIcon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Main Type',
                      style: AppTheme.caption.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      mainType,
                      style: AppTheme.body.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (subType != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    subType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (subType != null) ...[
            const AppDivider(verticalPadding: 10),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.category_outlined,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub Type',
                        style: AppTheme.caption.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        subType,
                        style: AppTheme.body.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (project.landArea != null && project.landArea!.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.landscape_outlined,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Land Area',
                      style: AppTheme.caption.copyWith(fontSize: 10),
                    ),
                    Text(
                      '${project.landArea} ${project.landUnit ?? ""}',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (project.floors != null && project.floors!.isNotEmpty) ...[
            Text(
              'Floors Included',
              style: AppTheme.caption.copyWith(
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: project.floors!
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
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
    Widget tile(String label, int? count, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: AppTheme.caption.copyWith(
              fontSize: 12,
              color: AppColors.textMedium,
            ),
          ),
          Text(
            '${count ?? 0}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: c,
            ),
          ),
        ],
      ),
    );
    final roomTiles = rooms.entries
        .where((e) => (e.value ?? 0) > 0)
        .map((e) => tile(e.key, e.value, AppColors.primary))
        .toList();
    final bathTiles = baths.entries
        .where((e) => (e.value ?? 0) > 0)
        .map((e) => tile(e.key, e.value, const Color(0xFF00838F)))
        .toList();
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roomTiles.isNotEmpty) ...[
            Text(
              'ROOMS',
              style: AppTheme.caption.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: roomTiles),
            if (bathTiles.isNotEmpty) const SizedBox(height: 16),
          ],
          if (bathTiles.isNotEmpty) ...[
            Text(
              'BATHROOMS',
              style: AppTheme.caption.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${widget.features.length} selected',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: Color(0xFFEEF0F5)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.features
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
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
    final statusColor = status == 'Completed'
        ? AppColors.success
        : status == 'In Progress'
        ? AppColors.primary
        : status == 'On Hold'
        ? AppColors.warning
        : status == 'Cancelled'
        ? AppColors.error
        : const Color(0xFF6B7280);
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != null) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.flag_rounded, color: statusColor, size: 17),
                ),
                const SizedBox(width: 10),
                Text(
                  'Project Status',
                  style: AppTheme.body.copyWith(color: AppColors.textMedium),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const AppDivider(verticalPadding: 12),
          ],
          Text(
            'PROJECT TIMELINE',
            style: AppTheme.caption.copyWith(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dateBox(
                'Start Date',
                _fmt(project.startDate),
                Icons.play_circle_outline,
                AppColors.primary,
              ),
              if (project.expectedEndDate != null) ...[
                const SizedBox(width: 10),
                _dateBox(
                  'Expected End',
                  _fmt(project.expectedEndDate!),
                  Icons.event_outlined,
                  AppColors.warning,
                ),
              ],
            ],
          ),
          if (project.actualEndDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _dateBox(
                  'Actual End Date',
                  _fmt(project.actualEndDate!),
                  Icons.event_available_rounded,
                  AppColors.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _dateBox(String label, String val, IconData icon, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  val,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.project});
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    final util = project.budgetUtilization;
    final over = project.spentAmount > project.totalBudget;
    final bMat = project.budgetMaterial ?? 0;
    final bLab = project.budgetLabour ?? 0;
    final bEq = project.budgetEquipment ?? 0;
    final bMisc = project.budgetMisc ?? 0;
    final hasBrk = bMat + bLab + bEq + bMisc > 0;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL BUDGET',
                        style: AppTheme.caption.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textLight,
                        ),
                      ),
                      Text(
                        project.formattedBudget,
                        style: AppTheme.heading2.copyWith(
                          color: AppColors.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AppDivider(verticalPadding: 12),
          _frow(
            'Spent Amount',
            project.formattedSpent,
            over ? AppColors.error : AppColors.primary,
            Icons.payments_outlined,
          ),
          const AppDivider(verticalPadding: 8),
          _frow(
            'Remaining',
            project.formattedRemaining,
            project.remainingBudget >= 0 ? AppColors.success : AppColors.error,
            Icons.savings_outlined,
          ),
          if (hasBrk) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFEEF0F8), height: 1),
            const SizedBox(height: 10),
            Text(
              'BUDGET BREAKDOWN',
              style: AppTheme.caption.copyWith(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (bMat > 0) ...[
              _catRow(
                'Material',
                bMat,
                AppColors.primary,
                Icons.category_outlined,
              ),
              const AppDivider(verticalPadding: 6),
            ],
            if (bLab > 0) ...[
              _catRow(
                'Labour',
                bLab,
                AppColors.info,
                Icons.people_outline_rounded,
              ),
              const AppDivider(verticalPadding: 6),
            ],
            if (bEq > 0) ...[
              _catRow(
                'Equipment',
                bEq,
                const Color(0xFF7B3FE7),
                Icons.precision_manufacturing_outlined,
              ),
              const AppDivider(verticalPadding: 6),
            ],
            if (bMisc > 0)
              _catRow(
                'Miscellaneous',
                bMisc,
                AppColors.warning,
                Icons.more_horiz_rounded,
              ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Used',
                style: AppTheme.label.copyWith(
                  color: AppColors.textLight,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${(util * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: util >= 1.0
                      ? AppColors.error
                      : util >= 0.8
                      ? AppColors.warning
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LinearProgressIndicator(
              value: util.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFEEF0F8),
              valueColor: AlwaysStoppedAnimation<Color>(
                util >= 1.0
                    ? AppColors.error
                    : util >= 0.8
                    ? AppColors.warning
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _frow(String label, String value, Color color, IconData icon) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: AppTheme.body.copyWith(color: AppColors.textMedium),
        ),
      ),
      Text(
        value,
        style: AppTheme.bodyLarge.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );
  Widget _catRow(String label, double amount, Color c, IconData icon) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: c, size: 15),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: AppTheme.body.copyWith(
            color: AppColors.textMedium,
            fontSize: 13,
          ),
        ),
      ),
      Text(
        formatCurrency(amount),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c),
      ),
    ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Recent Activity',
          actionLabel: entries.isEmpty ? null : 'View All',
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
          const AppEmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No entries logged yet.',
          )
        else
          ...entries.map((e) => _EntryTile(entry: e)),
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
  (Color, IconData) _style(EntryType t) {
    switch (t) {
      case EntryType.material:
        return (AppColors.primary, Icons.category_outlined);
      case EntryType.labour:
        return (AppColors.info, Icons.people_outline);
      case EntryType.equipment:
        return (const Color(0xFF7B3FE7), Icons.construction_outlined);
    }
  }
  void _navigateToDetailFallback(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/entry-detail',
      arguments: {
        'id': entry.id,
        'title': entry.description.isEmpty
            ? entry.type.name.toUpperCase()
            : entry.description,
        'ref': entry.id.length > 4
            ? '#${entry.id.substring(entry.id.length - 4)}'
            : '#${entry.id}',
        'amount': '+${entry.amount}',
        'date': entry.date.toIso8601String(),
        'isPositive': true,
        'type': entry.type.name,
        'name': entry.description.isEmpty
            ? entry.type.name.toUpperCase()
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
    final (color, icon) = _style(entry.type);
    final d = entry.date;
    final dateStr = '${d.day} ${_months[d.month - 1]} ${d.year}';
    return GestureDetector(
      onTap: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (lCtx) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
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
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.description.isEmpty
                        ? entry.type.label.toUpperCase()
                        : entry.description,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(dateStr, style: AppTheme.caption),
                ],
              ),
            ),
            Text(
              formatCurrency(entry.amount),
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
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
      return AppCard(
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline,
              color: AppColors.textLight,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              'No project actions permitted',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (canAddEntry) ...[
          AppButton(
            label: 'Add Entry',
            icon: Icons.add_circle_outline,
            onPressed: () => Navigator.pushNamed(context, '/add-entry'),
          ),
          const SizedBox(height: 10),
        ],
        if (canEdit) ...[
          AppButton(
            label: 'Edit Project',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.outline,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProjectScreen(project: project),
                ),
              ).then((_) => context.read<ProjectProvider>().load());
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
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
      backgroundColor: AppColors.gradientStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: project.name,
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
              rightWidget: canEdit
                  ? IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
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
            Expanded(
              child: entries.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'No entries logged yet.',
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _EntryTile(entry: entries[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
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
                borderRadius: BorderRadius.circular(20),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV exported successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported budget for $updatedCount activities!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHASES & BUDGET CONFIGURATION',
                      style: AppTheme.caption.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textLight,
                      ),
                    ),
                    const Text(
                      'Import/Export CSV budgets for all phases.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(
                      color: Color(0xFFEEF0F5),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isUploading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _uploadCsv,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Upload CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(
            photoUrl.startsWith('http') 
              ? photoUrl 
              : '${ApiService.baseUrl.replaceAll('/api', '')}$photoUrl'
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _ProjectScopeCard extends StatelessWidget {
  final String scope;
  const _ProjectScopeCard({required this.scope});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        scope,
        style: const TextStyle(fontSize: 14, color: AppColors.textDark),
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  final List<String> documents;
  const _DocumentsCard({required this.documents});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: documents
            .map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc.split("/").last,
                          style: const TextStyle(fontSize: 14, color: AppColors.primary, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
