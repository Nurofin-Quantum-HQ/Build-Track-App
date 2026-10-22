import 'package:buildtrack_mobile/common/tour_targets.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/screen/projects/add_project.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
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
              // Next tab this user can open (skips disabled tabs, ends the tour at the end).
              context.read<NavController>().continueTour(context, from: '/projects');
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
    // Only showcase widgets that are actually on screen for this user/state
    // (e.g. the project card isn't mounted while loading or on an error),
    // otherwise the tour jumps or stalls.
    return renderedTourKeys(context, keys);
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
    final company = UserSession.companyName.trim();
    final count = provider.projects.length;

    final hero = BtHero(
      overlap: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (company.isNotEmpty ? company : 'BuildTrack').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BtText.mono(context, color: Bt.onNoir2),
                ),
              ),
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
                    color: Bt.bone,
                    size: 20,
                    background: Colors.white.withValues(alpha: .08),
                    onTap: () => Navigator.pushNamed(context, '/assign-task'),
                  ),
                ),
              const SizedBox(width: 6),
              BtIconButton(
                icon: Icons.help_outline_rounded,
                semantic: 'App guidelines',
                color: Bt.bone,
                size: 20,
                background: Colors.white.withValues(alpha: .08),
                onTap: () {
                  final keys = _tourKeys();
                  if (keys.isNotEmpty) {
                    ShowCaseWidget.of(context).startShowCase(keys);
                  }
                },
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: 'Account',
                child: BtPressable(
                  scale: .92,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: const Padding(padding: EdgeInsets.all(4), child: ProfileAvatar(radius: 18)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BtReveal(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text('Projects', style: BtText.d1(context, color: Bt.bone))),
                if (canCreate)
                  Showcase(
                    key: _fabKey,
                    title: 'Add Project',
                    description: 'Tap here to create a new project.',
                    child: BtButton(
                      label: 'New',
                      icon: Icons.add_rounded,
                      small: true,
                      expand: false,
                      variant: BtButtonVariant.accent,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddProjectScreen()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (provider.hasProjects) ...[
            const SizedBox(height: 12),
            BtReveal(
              index: 1,
              child: Text(
                'Active builds · $count ${count == 1 ? 'project' : 'projects'}',
                style: BtText.subhead(context, color: Bt.onNoir2),
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Bt.ground,
      body: BtHeroScroll(
        hero: hero,
        onRefresh: provider.load,
        sheetPadding: const EdgeInsets.fromLTRB(Bt.gutter, 20, Bt.gutter, 120),
        children: _buildBody(context, provider),
      ),
      bottomNavigationBar: AppBottomNav(),
    );
  }

  List<Widget> _buildBody(BuildContext context, ProjectProvider provider) {
    if (provider.isLoading) {
      return const [BtSkeleton(height: 230, radius: 24), SizedBox(height: 12), BtSkeletonList(count: 3)];
    }
    if (provider.error.isNotEmpty) {
      return [BtErrorCard(message: provider.error, onRetry: provider.load)];
    }
    if (!provider.hasProjects) {
      return [
        BtEmpty(
          icon: Icons.folder_open_outlined,
          title: 'No projects yet',
          message: RoleManager.canCreateProject ? 'Tap New to create your first project.' : null,
        ),
      ];
    }
    final projects = provider.projects;
    final first = projects.first;
    return [
      BtReveal(
        index: 2,
        child: Showcase(
          key: ShowcaseKeys.projectsCard,
          description: 'Tap on any project card to view detailed analytics and logs',
          tooltipBackgroundColor: Bt.ink,
          textColor: Colors.white,
          tooltipBorderRadius: BorderRadius.circular(16),
          tooltipPadding: const EdgeInsets.all(16),
          child: _heroCard(context, first, provider),
        ),
      ),
      for (var i = 1; i < projects.length; i++) ...[
        const SizedBox(height: 10),
        i <= 7
            ? BtReveal(index: 2 + i, child: _miniCard(context, projects[i], provider))
            : _miniCard(context, projects[i], provider),
      ],
    ];
  }

  void _open(ProjectModel p, ProjectProvider provider) {
    provider.selectProject(p);
    Navigator.pushNamed(context, '/project-detail');
  }

  /// Big card for the first project: site photo (if any) with name overlaid.
  Widget _heroCard(BuildContext context, ProjectModel p, ProjectProvider provider) {
    final bt = context.bt;
    final progress = p.progress.clamp(0.0, 1.0).toDouble();
    final pct = (p.progress * 100).toStringAsFixed(0);
    final status = _ProjectStatus.fromString(p.projectStatus);
    final caption = [
      if (p.location.isNotEmpty) p.location,
      if (p.projectCode?.isNotEmpty == true) p.projectCode!,
    ].join(' · ');
    return Semantics(
      button: true,
      label: '${p.name}, $pct percent done. View details',
      child: BtPressable(
        scale: .98,
        onTap: () => _open(p, provider),
        child: Container(
          decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(24), boxShadow: Bt.shadow),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 158,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProjectPhoto(photo: p.photo),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x26080A0C), Color(0x10080A0C), Color(0xE0080A0C)],
                          stops: [0, .4, 1],
                        ),
                      ),
                    ),
                    Positioned(left: 12, top: 12, child: _GlassPill(label: status.label, tone: status.tone)),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.d3(context, color: Bt.bone)),
                          if (caption.isNotEmpty)
                            Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.onNoir2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Overall progress', style: BtText.subhead(context)),
                        const Spacer(),
                        Text('$pct%', style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BtBricks(value: progress, height: 9),
                    if (RoleManager.canViewProjectBudget) ...[
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: p.formattedSpent, style: BtText.num(BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
                          TextSpan(text: p.totalBudget > 0 ? ' of ${p.formattedBudget}' : ' spent · no budget set', style: BtText.num(BtText.subhead(context))),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('View details', style: BtText.subhead(context, weight: FontWeight.w500)),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Bt.ink3),
                        const Spacer(),
                        if (RoleManager.canAssignTasks)
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/assign-task'),
                            style: TextButton.styleFrom(minimumSize: const Size(44, 40), padding: const EdgeInsets.symmetric(horizontal: 8)),
                            child: Text('Assign task', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.accentInk)),
                          )
                        else
                          const SizedBox(height: 40),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact card for the rest of the projects.
  Widget _miniCard(BuildContext context, ProjectModel p, ProjectProvider provider) {
    final pct = (p.progress * 100).toStringAsFixed(0);
    final status = _ProjectStatus.fromString(p.projectStatus);
    final sub = RoleManager.canViewProjectBudget ? (p.totalBudget > 0 ? '$pct% · ${p.formattedSpent} of ${p.formattedBudget}' : '$pct% · ${p.formattedSpent} spent') : '$pct% · ${status.label}';
    return Semantics(
      button: true,
      label: '${p.name}, $pct percent done. View details',
      excludeSemantics: true,
      child: BtPressable(
        scale: .98,
        onTap: () => _open(p, provider),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(20), boxShadow: Bt.shadow),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 64, height: 64, child: _ProjectPhoto(photo: p.photo, small: true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    BtProgress(value: p.progress.clamp(0.0, 1.0).toDouble(), thin: true),
                    const SizedBox(height: 6),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.num(BtText.caption(context))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ProjectStatusChip(statusRaw: p.projectStatus),
            ],
          ),
        ),
      ),
    );
  }
}

/// The project's site photo (same URL resolution as the project detail
/// screen) or, when there is none, a noir blueprint placeholder.
class _ProjectPhoto extends StatelessWidget {
  const _ProjectPhoto({required this.photo, this.small = false});
  final String? photo;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final url = photo;
    if (url == null || url.isEmpty) return _placeholder(context);
    return Image.network(
      url.startsWith('http') ? url : '${ApiService.baseUrl.replaceAll('/api', '')}$url',
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final a = context.bt.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color.alphaBlend(a.withValues(alpha: .28), Bt.noir3), Bt.noir],
        ),
      ),
      child: Align(
        alignment: small ? Alignment.center : const Alignment(.82, -.55),
        child: Icon(Icons.apartment_rounded, size: small ? 26 : 54, color: Bt.bone.withValues(alpha: small ? .55 : .16)),
      ),
    );
  }
}

/// Status pill that sits on top of a photo.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label, required this.tone});
  final String label;
  final BtTone tone;
  @override
  Widget build(BuildContext context) {
    final Color dot;
    switch (tone) {
      case BtTone.green:
        dot = Bt.greenBright;
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
      decoration: BoxDecoration(color: const Color(0x990C0E12), borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: BtText.caption(context, color: Bt.bone, weight: FontWeight.w600).copyWith(fontSize: 12)),
      ]),
    );
  }
}
