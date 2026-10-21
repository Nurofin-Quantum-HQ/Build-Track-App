import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/screen/project_insights/insights_theme.dart';
import 'package:buildtrack_mobile/screen/project_insights/project_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Insights tab (Design V2): pick any project at the top and its insights
/// (Overview · Phases · Money — unchanged) show right below. No need to open
/// a project first.
class InsightsHubScreen extends StatefulWidget {
  const InsightsHubScreen({super.key});
  @override
  State<InsightsHubScreen> createState() => _InsightsHubScreenState();
}

class _InsightsHubScreenState extends State<InsightsHubScreen> {
  String? _projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!Navigator.of(context).canPop()) context.read<NavController>().markCurrent('/insights');
      final p = context.read<ProjectProvider>();
      if (!p.projectsLoaded) p.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final projects = provider.projects;
    final canPop = Navigator.of(context).canPop();
    final selectedId = (_projectId != null && projects.any((p) => p.id == _projectId))
        ? _projectId
        : (provider.selectedProject?.id ?? (projects.isNotEmpty ? projects.first.id : null));
    final selected = projects.where((p) => p.id == selectedId).firstOrNull;

    return Scaffold(
      backgroundColor: Ins.bg,
      bottomNavigationBar: canPop ? null : AppBottomNav(),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BtHero(
          overlap: 0,
          padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + 12, Bt.gutter, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (canPop) ...[
                BtIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 18, color: Bt.bone, background: Colors.white.withValues(alpha: .09), semantic: 'Back', onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PROJECT INSIGHTS', style: BtText.mono(context, color: Bt.onNoir2)),
                  const SizedBox(height: 4),
                  BtReveal(child: Text('Insights', style: BtText.d1(context, color: Bt.bone))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            if (projects.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = projects[i];
                    return BtChip(
                      label: p.name,
                      onDark: true,
                      selected: p.id == selectedId,
                      icon: p.id == selectedId ? Icons.apartment_rounded : null,
                      onTap: () => setState(() => _projectId = p.id),
                    );
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: selected == null
              ? (provider.projectsLoaded
                  ? const Center(child: BtEmpty(title: 'No projects yet', message: 'Add a project to see its budgets, forecast, spend and cash here.', icon: Icons.insights_rounded))
                  : const BtPageLoader(label: 'Loading projects…'))
              : AnimatedSwitcher(
                  duration: Bt.medium,
                  switchInCurve: Bt.ease,
                  child: ProjectInsightsScreen(key: ValueKey(selected.id), projectId: selected.id, projectName: selected.name, embedded: true),
                ),
        ),
      ]),
    );
  }
}
