import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:showcaseview/showcaseview.dart';
class ChooseEntryModeScreen extends StatefulWidget {
  const ChooseEntryModeScreen({super.key});
  @override
  State<ChooseEntryModeScreen> createState() => _ChooseEntryModeScreenState();
}
class _ChooseEntryModeScreenState extends State<ChooseEntryModeScreen> {
  String _entryType = 'material';
  Map<String, dynamic> _contextArgs = {};
  bool _argsLoaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _entryType = args['type']?.toString() ?? 'material';
      _contextArgs = Map<String, dynamic>.from(args);
    }
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    _contextArgs['projectId'] = projectProvider.selectedProject?.id;
    _contextArgs['projectName'] = projectProvider.selectedProject?.name;
    _contextArgs['floor'] = projectProvider.selectedFloor;
    _contextArgs['floorId'] = projectProvider.selectedFloor;
    _contextArgs['phase'] = projectProvider.selectedPhase;
    _contextArgs['phaseId'] = projectProvider.selectedPhaseId;
    _contextArgs['activity'] = projectProvider.selectedActivity;
    _contextArgs['activityId'] = projectProvider.selectedActivityId;
  }
  static const Map<String, String> _voiceRoutes = {
    'material': '/review-material',
    'labour': '/review-labour',
    'equipment': '/review-equipment',
  };
  static const Map<String, String> _manualRoutes = {
    'material': '/add-material',
    'labour': '/add-labour',
    'equipment': '/add-equipment',
  };
  void _goVoice() {
    final route = _voiceRoutes[_entryType];
    if (route != null) {
      Navigator.pushNamed(context, route, arguments: _contextArgs);
    }
  }
  void _goManual() {
    final route = _manualRoutes[_entryType];
    if (route != null) {
      Navigator.pushNamed(context, route, arguments: _contextArgs);
    }
  }
  String get _entryTypeLabel {
    switch (_entryType) {
      case 'labour':
        return 'Labour';
      case 'equipment':
        return 'Equipment';
      default:
        return 'Material';
    }
  }
  String get _projectName {
    final provider = Provider.of<ProjectProvider>(context);
    return provider.selectedProject?.name ??
        _contextArgs['projectName']?.toString() ??
        _contextArgs['projectId']?.toString() ??
        '—';
  }
  String get _floor =>
      Provider.of<ProjectProvider>(context).selectedFloor ??
      _contextArgs['floor']?.toString() ??
      '—';
  String get _phase =>
      Provider.of<ProjectProvider>(context).selectedPhase ??
      _contextArgs['phase']?.toString() ??
      '—';
  String get _activity =>
      Provider.of<ProjectProvider>(context).selectedActivity ??
      _contextArgs['activity']?.toString() ??
      '—';
  void _startTour(BuildContext context) {
    if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('AddEntryMode')) {
      ShowCaseWidget.of(context).startShowCase([ShowcaseKeys.addEntryVoiceTab, ShowcaseKeys.addEntryManualTab]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      globalTooltipActions: [TooltipActionButton(type: TooltipDefaultActionType.skip, backgroundColor: Colors.transparent, textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), TooltipActionButton(type: TooltipDefaultActionType.next, backgroundColor: AppColors.primary, textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))], 
      enableAutoScroll: true,
      onFinish: () => UserSession.markModuleVisited('AddEntryMode'),
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startTour(context);
        });
        return Scaffold(
          backgroundColor: Bt.ground,
          appBar: BtNavBar(title: '$_entryTypeLabel entry', subtitle: 'Step 3 of 3'),
          body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Bt.gutter, 6, Bt.gutter, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepBar(step: 3),
                const SizedBox(height: 20),
                BtReveal(child: Text('How do you want\nto add it?', style: BtText.d2(context))),
                const SizedBox(height: 6),
                BtReveal(index: 1, child: Text('Adding $_entryTypeLabel entry', style: BtText.subhead(context))),
                const SizedBox(height: 20),
                // Not wrapped in BtReveal: the tour measures these tiles on the first frame.
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Showcase(
                          key: ShowcaseKeys.addEntryVoiceTab,
                          description: 'Use voice to automatically log entries.',
                          tooltipBackgroundColor: Bt.ink,
                          textColor: Colors.white,
                          tooltipBorderRadius: BorderRadius.circular(16),
                          tooltipPadding: const EdgeInsets.all(16),
                          child: _HowTile(
                            ink: true,
                            semantic: 'Use Voice',
                            title: 'Speak it',
                            subtitle: 'Speak naturally — AI fills the form',
                            onTap: _goVoice,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Showcase(
                          key: ShowcaseKeys.addEntryManualTab,
                          description: 'Manually input entry details.',
                          tooltipBackgroundColor: Bt.ink,
                          textColor: Colors.white,
                          tooltipBorderRadius: BorderRadius.circular(16),
                          tooltipPadding: const EdgeInsets.all(16),
                          child: _HowTile(
                            ink: false,
                            semantic: 'Enter Manually',
                            title: 'Type it',
                            subtitle: 'Fill the form manually',
                            onTap: _goManual,
                          ),
                        ),
                      ),
                ]),
                const SizedBox(height: 28),
                BtReveal(index: 3, child: _buildContextBanner()),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildContextBanner() {
    final rows = [
      ('Project', _projectName),
      ('Floor', _floor),
      ('Phase', _phase),
      ('Activity', _activity),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Bt.green, size: 15),
          const SizedBox(width: 6),
          Text('EXECUTION CONTEXT SELECTED', style: BtText.mono(context, color: Bt.green)),
        ]),
      ),
      BtCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.only(left: 16), child: Divider(height: 1, thickness: 1, color: Bt.line)),
            Semantics(
              label: '${rows[i].$1}: ${rows[i].$2}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  SizedBox(width: 26, child: Text('0${i + 1}', style: BtText.mono(context, color: Bt.green, size: 11))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rows[i].$1.toUpperCase(), style: BtText.mono(context)),
                      const SizedBox(height: 3),
                      Text(rows[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_rounded, size: 20, color: Bt.green),
                ]),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}

/// Big "how" choice tile (Where-Picker board): ink "Speak it" with a pulsing
/// accent mic, white "Type it" card.
class _HowTile extends StatelessWidget {
  const _HowTile({required this.ink, required this.semantic, required this.title, required this.subtitle, required this.onTap});
  final bool ink;
  final String semantic;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final icon = ink
        ? BtPulse(
            size: 46,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle),
              child: Icon(Icons.mic_rounded, color: bt.onAccent, size: 24),
            ),
          )
        : const BtTile(icon: Icons.keyboard_alt_outlined, size: 46);
    return BtPressable(
      onTap: onTap,
      scale: .96,
      semanticLabel: semantic,
      child: Container(
        constraints: const BoxConstraints(minHeight: 164),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ink ? Bt.ink : Bt.card,
          borderRadius: BorderRadius.circular(Bt.rCard),
          boxShadow: ink ? Bt.shadowLg : Bt.shadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            icon,
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, size: 20, color: ink ? Bt.onNoir2 : Bt.ink3),
          ]),
          const SizedBox(height: 18),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: BtText.d3(context, color: ink ? Bt.bone : Bt.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: BtText.caption(context, color: ink ? Bt.onNoir2 : Bt.ink2)),
          ]),
        ]),
      ),
    );
  }
}

/// Three-segment progress: Type ✓ · Where ✓ · How (shared look with the
/// execution-context screen).
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step; // 1..3
  @override
  Widget build(BuildContext context) {
    const labels = ['Type', 'Where', 'How'];
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BtProgress(
              thin: true,
              value: i + 1 < step ? 1 : (i + 1 == step ? .6 : 0),
              color: i + 1 < step ? Bt.greenBright : null,
            ),
            const SizedBox(height: 6),
            Row(children: [
              if (i + 1 < step) ...[
                const Icon(Icons.check_rounded, size: 12, color: Bt.green),
                const SizedBox(width: 3),
              ],
              Text(
                labels[i].toUpperCase(),
                style: BtText.mono(context, color: i + 1 < step ? Bt.green : (i + 1 == step ? context.bt.accentInk : Bt.ink3)),
              ),
            ]),
          ]),
        ),
      ],
    ]);
  }
}
