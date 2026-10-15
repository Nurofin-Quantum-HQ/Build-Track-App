import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/screen/projects/add_project.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
enum _ProjectStatus {
  planning,
  inProgress,
  onHold,
  completed,
  cancelled;
  static _ProjectStatus fromString(String? raw) {
    switch ((raw ?? '').toLowerCase().replaceAll(' ', '').replaceAll('_', '')) {
      case 'planning':
        return _ProjectStatus.planning;
      case 'inprogress':
        return _ProjectStatus.inProgress;
      case 'onhold':
        return _ProjectStatus.onHold;
      case 'completed':
        return _ProjectStatus.completed;
      case 'cancelled':
        return _ProjectStatus.cancelled;
      default:
        return _ProjectStatus.inProgress;
    }
  }
  String get label {
    switch (this) {
      case _ProjectStatus.planning:
        return 'Planning';
      case _ProjectStatus.inProgress:
        return 'In Progress';
      case _ProjectStatus.onHold:
        return 'On Hold';
      case _ProjectStatus.completed:
        return 'Completed';
      case _ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }
  BtTone get tone {
    switch (this) {
      case _ProjectStatus.planning:
        return BtTone.neutral;
      case _ProjectStatus.inProgress:
        return BtTone.brand;
      case _ProjectStatus.onHold:
        return BtTone.amber;
      case _ProjectStatus.completed:
        return BtTone.green;
      case _ProjectStatus.cancelled:
        return BtTone.red;
    }
  }
}
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.statusRaw});
  final String? statusRaw;
  @override
  Widget build(BuildContext context) {
    final status = _ProjectStatus.fromString(statusRaw);
    return BtBadge(label: status.label, tone: status.tone);
  }
}
class ProjectsScreen extends StatelessWidget {
  ProjectsScreen({super.key});
  final GlobalKey<ShowCaseWidgetState> _showcaseKey = GlobalKey<ShowCaseWidgetState>();

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      key: _showcaseKey,
      globalTooltipActions: [
        TooltipActionButton(
          type: TooltipDefaultActionType.skip, 
          backgroundColor: Colors.transparent, 
          textStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          onTap: () {
            UserSession.skipTour();
            _showcaseKey.currentState?.dismiss();
          }
        ), 
        TooltipActionButton(
          type: TooltipDefaultActionType.next, 
          backgroundColor: AppColors.primary, 
          textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        )
      ], 
      enableAutoScroll: true,
      onFinish: () {
        UserSession.markModuleVisited('ProjectsScreen');
        if (UserSession.globalTourActive) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              final nav = Provider.of<NavController>(context, listen: false);
              nav.setRoute('/add-entry', context);
            }
          });
        }
      },
      builder: (context) => const _ProjectsScreenContent(),
    );
  }
}

class _ProjectsScreenContent extends StatefulWidget {
  const _ProjectsScreenContent();
  @override
  State<_ProjectsScreenContent> createState() => _ProjectsScreenContentState();
}

class _ProjectsScreenContentState extends State<_ProjectsScreenContent> {
  final GlobalKey _fabKey = GlobalKey();

  List<GlobalKey> _tourKeys() {
    final projProvider = Provider.of<ProjectProvider>(context, listen: false);
    final keys = <GlobalKey>[];
    if (RoleManager.canAssignTasks) keys.add(ShowcaseKeys.projectsAssignRoleBtn);
    if (projProvider.projects.isEmpty) {
      if (RoleManager.canCreateProject) keys.add(_fabKey);
    } else {
      keys.add(ShowcaseKeys.projectsCard);
    }
    return keys;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projProvider = Provider.of<ProjectProvider>(context, listen: false);
      if (projProvider.projectsLoaded && !UserSession.hasSkippedTour && !UserSession.visitedModules.contains('ProjectsScreen')) {
        final keys = _tourKeys();
        if (keys.isNotEmpty) {
          ShowCaseWidget.of(context).startShowCase(keys);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final canCreate = RoleManager.canCreateProject;
    context.read<NavController>().markCurrent('/projects');
    return Scaffold(
      backgroundColor: Bt.ground,
      floatingActionButton: canCreate
          ? Showcase(
              key: _fabKey,
              title: 'Add Project',
              description: 'Tap here to create a new project.',
              child: FloatingActionButton.extended(
                heroTag: 'add-project',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProjectScreen()),
                ),
                backgroundColor: context.bt.brand,
                foregroundColor: context.bt.onAccent,
                elevation: 2,
                icon: const Icon(Icons.add_rounded),
                label: Text('New project', style: BtText.button(context, size: 15, color: context.bt.onAccent)),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BtLargeHeader(
              title: 'Projects',
              caption: provider.hasProjects ? '${provider.projects.length} ${provider.projects.length == 1 ? 'site' : 'sites'}' : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (RoleManager.canAssignTasks)
                    Showcase(
                      key: ShowcaseKeys.projectsAssignRoleBtn,
                      description: 'Click here to assign work/tasks to this project',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: BtIconButton(
                        icon: Icons.assignment_outlined,
                        semantic: 'Assign task',
                        color: Bt.ink2,
                        onTap: () => Navigator.pushNamed(context, '/assign-task'),
                      ),
                    ),
                  BtIconButton(
                    icon: Icons.help_outline_rounded,
                    semantic: 'App guidelines',
                    color: Bt.ink2,
                    onTap: () {
                      final keys = _tourKeys();
                      if (keys.isNotEmpty) {
                        ShowCaseWidget.of(context).startShowCase(keys);
                      }
                    },
                  ),
                  Semantics(
                    button: true,
                    label: 'Account',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 18)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, provider)),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }

  Widget _buildBody(BuildContext context, ProjectProvider provider) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: Bt.gutter),
        child: BtSkeletonList(count: 3),
      );
    }
    if (provider.error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Bt.gutter),
        child: Align(
          alignment: Alignment.topCenter,
          child: BtErrorCard(message: provider.error, onRetry: provider.load),
        ),
      );
    }
    if (!provider.hasProjects) {
      return BtEmpty(
        icon: Icons.folder_open_outlined,
        title: 'No projects yet',
        message: RoleManager.canCreateProject ? 'Tap New project to create your first project.' : null,
      );
    }
    return RefreshIndicator(
      color: context.bt.brand,
      onRefresh: provider.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Bt.gutter, 4, Bt.gutter, 100),
        itemCount: provider.projects.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = provider.projects[i];
          final card = _projectCard(context, p, provider);
          if (i != 0) return card;
          return Showcase(
            key: ShowcaseKeys.projectsCard,
            description: 'Tap on any project card to view detailed analytics and logs',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: card,
          );
        },
      ),
    );
  }

  Widget _projectCard(
    BuildContext context,
    ProjectModel p,
    ProjectProvider provider,
  ) {
    final bt = context.bt;
    void open() {
      provider.selectProject(p);
      Navigator.pushNamed(context, '/project-detail');
    }

    final pct = (p.progress * 100).toStringAsFixed(0);
    return Semantics(
      button: true,
      label: '${p.name}, $pct percent done. View details',
      child: BtCard(
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.headline(context),
                  ),
                ),
                const SizedBox(width: 8),
                ProjectStatusChip(statusRaw: p.projectStatus),
              ],
            ),
            if (p.location.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.place_outlined, size: 14, color: Bt.ink3),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(p.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
                ),
              ]),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Overall progress', style: BtText.subhead(context)),
                const Spacer(),
                Text('$pct%', style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
              ],
            ),
            const SizedBox(height: 6),
            BtProgress(value: p.progress.clamp(0.0, 1.0).toDouble(), work: true),
            const SizedBox(height: 12),
            Row(
              children: [
                if (UserSession.isAdmin)
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: p.formattedSpent, style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
                        TextSpan(text: ' of ${p.formattedBudget}', style: BtText.num(BtText.subhead(context))),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                Text('View details', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.brand)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: bt.brand),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
