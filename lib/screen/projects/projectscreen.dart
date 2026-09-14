import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
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
  Color get bg {
    switch (this) {
      case _ProjectStatus.planning:
        return const Color(0xFFFFF8E1);
      case _ProjectStatus.inProgress:
        return const Color(0xFFE8F0FE);
      case _ProjectStatus.onHold:
        return const Color(0xFFFFF3E0);
      case _ProjectStatus.completed:
        return const Color(0xFFE8F5E9);
      case _ProjectStatus.cancelled:
        return const Color(0xFFFFEBEE);
    }
  }
  Color get border {
    switch (this) {
      case _ProjectStatus.planning:
        return const Color(0xFFFFC107);
      case _ProjectStatus.inProgress:
        return const Color(0xFF4A6CF7);
      case _ProjectStatus.onHold:
        return const Color(0xFFFF9800);
      case _ProjectStatus.completed:
        return const Color(0xFF43A047);
      case _ProjectStatus.cancelled:
        return const Color(0xFFE53935);
    }
  }
  Color get text {
    switch (this) {
      case _ProjectStatus.planning:
        return const Color(0xFFF57F17);
      case _ProjectStatus.inProgress:
        return const Color(0xFF3D5AFE);
      case _ProjectStatus.onHold:
        return const Color(0xFFE65100);
      case _ProjectStatus.completed:
        return const Color(0xFF2E7D32);
      case _ProjectStatus.cancelled:
        return const Color(0xFFC62828);
    }
  }
}
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({super.key, required this.statusRaw});
  final String? statusRaw;
  @override
  Widget build(BuildContext context) {
    final status = _ProjectStatus.fromString(statusRaw);
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: status.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.2,
        ),
      ),
    );
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
        const TooltipActionButton(
          type: TooltipDefaultActionType.next, 
          backgroundColor: AppColors.primary, 
          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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
  static const primaryBlue = AppColors.primary;
  static const bgColor = AppColors.gradientStart;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;

  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final _projProvider = Provider.of<ProjectProvider>(context, listen: false);
      if (_projProvider.projectsLoaded && !UserSession.hasSkippedTour && !UserSession.visitedModules.contains('ProjectsScreen')) {
        final keys = <GlobalKey>[];
        if (RoleManager.canAssignTasks) keys.add(ShowcaseKeys.projectsAssignRoleBtn);
        if (_projProvider.projects.isEmpty) {
          keys.add(_fabKey);
        } else {
          keys.add(ShowcaseKeys.projectsCard);
        }
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
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: canCreate
          ? Showcase(
              key: _fabKey,
              title: 'Add Project',
              description: 'Tap here to create a new project.',
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProjectScreen()),
                ),
                backgroundColor: primaryBlue,
                shape: const CircleBorder(),
                elevation: 4,
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'BuildTrack',
              rightWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (RoleManager.canAssignTasks)
                    Showcase(
                      key: ShowcaseKeys.projectsAssignRoleBtn,
                      description: 'Click here to assign work/tasks to this project',
                      tooltipBackgroundColor: const Color(0xFF1E1E2C),
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/assign-task'),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: AppColors.primary,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      final _projProvider = Provider.of<ProjectProvider>(context, listen: false);
                      final keys = <GlobalKey>[];
                      if (RoleManager.canAssignTasks) keys.add(ShowcaseKeys.projectsAssignRoleBtn);
                      if (_projProvider.projects.isEmpty) {
                        keys.add(_fabKey);
                      } else {
                        keys.add(ShowcaseKeys.projectsCard);
                      }
                      if (keys.isNotEmpty) {
                        ShowCaseWidget.of(context).startShowCase(keys);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        color: AppColors.primary,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: const ProfileAvatar(radius: 18),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, provider)),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
  Widget _buildBody(BuildContext context, ProjectProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (provider.error.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        message: provider.error,
        actionLabel: 'Retry',
        onAction: provider.load,
      );
    }
    if (!provider.hasProjects) {
      return const AppEmptyState(
        icon: Icons.folder_open_outlined,
        message: 'No projects yet.\nTap + to create your first project.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: provider.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'LIVE PIPELINE',
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Active Builds',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${provider.projects.length} Sites',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...provider.projects.asMap().entries.map(
              (entry) {
                final isFirst = entry.key == 0;
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: isFirst
                      ? Showcase(
                          key: ShowcaseKeys.projectsCard,
                          description: 'Tap on any project card to view detailed analytics and logs',
                          tooltipBackgroundColor: const Color(0xFF1E1E2C),
                          textColor: Colors.white,
                          tooltipBorderRadius: BorderRadius.circular(16),
                          tooltipPadding: const EdgeInsets.all(16),
                          child: _projectCard(context, p, provider),
                        )
                      : _projectCard(context, p, provider),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _projectCard(
    BuildContext context,
    ProjectModel p,
    ProjectProvider provider,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          provider.selectProject(p);
          Navigator.pushNamed(context, '/project-detail');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ProjectStatusChip(statusRaw: p.projectStatus),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                p.location,
                style: const TextStyle(
                  color: textGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${p.formattedSpent} of ${p.formattedBudget}',
                style: const TextStyle(
                  color: primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overall Progress',
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${(p.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: p.progress,
                  backgroundColor: const Color(0xFFE8ECF8),
                  valueColor: const AlwaysStoppedAnimation<Color>(primaryBlue),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    provider.selectProject(p);
                    Navigator.pushNamed(context, '/project-detail');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: primaryBlue, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

