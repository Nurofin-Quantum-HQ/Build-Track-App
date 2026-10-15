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
class _ChooseEntryModeScreenState extends State<ChooseEntryModeScreen>
    with SingleTickerProviderStateMixin {
  String _entryType = 'material';
  Map<String, dynamic> _contextArgs = {};
  bool _argsLoaded = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
  }
  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
          appBar: BtNavBar(title: '$_entryTypeLabel entry'),
          body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    Text('How do you want to add?', style: BtText.title(context, size: 24)),
                    const SizedBox(height: 4),
                    Text('Adding $_entryTypeLabel entry', style: BtText.subhead(context)),
                    const SizedBox(height: 20),
                    Showcase(
                      key: ShowcaseKeys.addEntryVoiceTab,
                      description: 'Use voice to automatically log entries.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: _VoiceChoice(onTap: _goVoice),
                    ),
                    const SizedBox(height: 12),
                    Showcase(
                      key: ShowcaseKeys.addEntryManualTab,
                      description: 'Manually input entry details.',
                      tooltipBackgroundColor: Bt.ink,
                      textColor: Colors.white,
                      tooltipBorderRadius: BorderRadius.circular(16),
                      tooltipPadding: const EdgeInsets.all(16),
                      child: BtGroup(children: [
                        BtRow(
                          leading: const BtTile(icon: Icons.edit_outlined),
                          title: 'Enter Manually',
                          subtitle: 'Fill the form manually.',
                          showChevron: true,
                          minHeight: 64,
                          onTap: _goManual,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    _buildContextBanner(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, 'Entry Type', done: true),
        _stepLine(done: true),
        _stepDot(2, 'Context', done: true),
        _stepLine(done: true),
        _stepDot(3, 'How to Add', active: true),
        _stepLine(),
        _stepDot(4, 'Entry'),
      ],
    );
  }
  Widget _stepDot(
    int step,
    String label, {
    bool done = false,
    bool active = false,
  }) {
    final Color bg = done
        ? const Color(0xFF067647)
        : active
        ? AppColors.primary
        : const Color(0xFFE4E7EC);
    final Color textColor = (done || active)
        ? Colors.white
        : AppColors.textLight;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? AppColors.primary
                : done
                ? const Color(0xFF067647)
                : AppColors.textLight,
          ),
        ),
      ],
    );
  }
  Widget _stepLine({bool done = false}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: done ? const Color(0xFF067647) : const Color(0xFFE4E7EC),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
  Widget _buildContextBanner() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, color: Bt.green, size: 16),
          const SizedBox(width: 6),
          Text('Execution Context Selected', style: BtText.caption(context, color: Bt.green, weight: FontWeight.w600)),
        ]),
      ),
      BtGroup(insetDividers: false, children: [
        BtValueRow(label: 'Project', value: _projectName),
        BtValueRow(label: 'Floor', value: _floor),
        BtValueRow(label: 'Phase', value: _phase),
        BtValueRow(label: 'Activity', value: _activity),
      ]),
    ]);
  }
}

class _VoiceChoice extends StatelessWidget {
  const _VoiceChoice({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: 'Use Voice',
      child: Container(
        decoration: BoxDecoration(gradient: bt.signature, borderRadius: BorderRadius.circular(Bt.rCard)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Bt.rCard),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), shape: BoxShape.circle),
                  child: Icon(Icons.mic_rounded, color: bt.onAccent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Use Voice', style: BtText.headline(context).copyWith(color: bt.onAccent)),
                    Text('Speak naturally and let AI capture the details.', style: BtText.subhead(context, color: bt.onAccent.withValues(alpha: .85))),
                  ]),
                ),
                Icon(Icons.arrow_forward_rounded, color: bt.onAccent),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractiveModeCard extends StatefulWidget {
  const _InteractiveModeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  State<_InteractiveModeCard> createState() => _InteractiveModeCardState();
}
class _InteractiveModeCardState extends State<_InteractiveModeCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final borderColor = _isHovered
        ? AppColors.primary
        : const Color(0xFFE8EBF5);
    final borderWidth = _isHovered ? 2.0 : 1.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Bt.rCard),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Bt.rCard),
            child: InkWell(
              borderRadius: BorderRadius.circular(Bt.rCard),
              onTapDown: (_) => _animationController.forward(),
              onTapUp: (_) => _animationController.reverse(),
              onTapCancel: () => _animationController.reverse(),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101828),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
