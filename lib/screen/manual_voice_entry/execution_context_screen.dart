import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:provider/provider.dart';
class ExecutionContextScreen extends StatefulWidget {
  const ExecutionContextScreen({super.key});
  @override
  State<ExecutionContextScreen> createState() => _ExecutionContextScreenState();
}
class _ExecutionContextScreenState extends State<ExecutionContextScreen> {
  String _entryType = 'material';
  String? _selectedProjectId;
  String? _selectedFloor;
  String? _selectedFloorId;
  String? _selectedPhase;
  String? _selectedPhaseId;
  String? _selectedActivity;
  String? _selectedActivityId;
  String? _projectError;
  String? _floorError;
  String? _phaseError;
  String? _activityError;
  bool _argsLoaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _entryType = args['type']?.toString() ?? 'material';
    }
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    _selectedProjectId = provider.selectedProject?.id;
    _selectedFloor = provider.selectedFloor;
    _selectedFloorId = provider.selectedFloor;
    _selectedPhase = provider.selectedPhase;
    _selectedPhaseId = provider.selectedPhaseId;
    _selectedActivity = provider.selectedActivity;
    _selectedActivityId = provider.selectedActivityId;
    if (_selectedProjectId != null && _selectedProjectId!.isNotEmpty) {
      provider.refreshProject(_selectedProjectId!);
    }
  }
  bool get _canContinue =>
      _selectedProjectId != null &&
      _selectedProjectId!.isNotEmpty &&
      _selectedFloor != null &&
      _selectedFloor!.isNotEmpty &&
      _selectedPhase != null &&
      _selectedPhase!.isNotEmpty &&
      _selectedActivity != null &&
      _selectedActivity!.isNotEmpty;
  String? _derivePhaseId(String? phaseName) {
    if (phaseName == null || phaseName.isEmpty || _selectedProjectId == null) {
      return null;
    }
    final provider = context.read<ProjectProvider>();
    final project = provider.projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _selectedProjectId,
      orElse: () => null,
    );
    if (project?.selectedPhases == null) return null;
    for (final p in project!.selectedPhases!) {
      if (p.phaseName == phaseName) return p.id;
    }
    return null;
  }
  String? _deriveActivityId(String? activityName) {
    if (activityName == null ||
        activityName.isEmpty ||
        _selectedProjectId == null) {
      return null;
    }
    final provider = context.read<ProjectProvider>();
    final project = provider.projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _selectedProjectId,
      orElse: () => null,
    );
    if (project?.selectedPhases == null) return null;
    for (final phase in project!.selectedPhases!) {
      for (final act in phase.activities) {
        if (act.name == activityName) return act.id;
      }
    }
    return null;
  }
  void _onContinue() {
    bool valid = true;
    setState(() {
      _projectError = null;
      _floorError = null;
      _phaseError = null;
      _activityError = null;
      if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
        _projectError = 'Please select a project';
        valid = false;
      }
      final provider = Provider.of<ProjectProvider>(context, listen: false);
      final project = provider.projects.cast<ProjectModel?>().firstWhere(
        (p) => p?.id == _selectedProjectId,
        orElse: () => null,
      );
      final hasFloors = project?.floors != null && project!.floors!.isNotEmpty;
      if (hasFloors && (_selectedFloor == null || _selectedFloor!.isEmpty)) {
        _floorError = 'Please select a floor';
        valid = false;
      }
      if (_selectedPhase == null || _selectedPhase!.isEmpty) {
        _phaseError = 'Please select a phase';
        valid = false;
      }
      if (_selectedActivity == null || _selectedActivity!.isEmpty) {
        _activityError = 'Please select an activity';
        valid = false;
      }
    });
    if (!valid) return;
    final phaseId = _selectedPhaseId ?? _derivePhaseId(_selectedPhase);
    final activityId =
        _selectedActivityId ?? _deriveActivityId(_selectedActivity);
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    if (_selectedProjectId != provider.selectedProject?.id) {
      final project = provider.projects.firstWhere(
        (p) => p.id == _selectedProjectId,
      );
      provider.selectProject(project);
    }
    final effectiveFloor = (_selectedFloor != null &&
            (provider.selectedProject?.floors?.contains(_selectedFloor) ?? false))
        ? _selectedFloor
        : null;
    provider.selectFloor(effectiveFloor);
    provider.selectPhase(_selectedPhase, phaseId);
    provider.selectActivity(_selectedActivity, activityId);
    Navigator.pushNamed(
      context,
      '/choose-entry-mode',
      arguments: {
        'type': _entryType,
        'projectId': _selectedProjectId,
        'floor': effectiveFloor,
        'floorId': effectiveFloor != null
            ? (_selectedFloorId ?? effectiveFloor)
            : null,
        'phase': _selectedPhase,
        'phaseId': phaseId ?? '',
        'activity': _selectedActivity,
        'activityId': activityId ?? '',
      },
    );
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(title: '$_entryTypeLabel entry'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Where is this work happening?', style: BtText.title(context, size: 24)),
                    const SizedBox(height: 4),
                    Text('Select the project context once — it applies to both voice and manual entry.', style: BtText.subhead(context)),
                    const SizedBox(height: 20),
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    ExecutionContextCard(
                      showHeader: false,
                      selectedProjectId: _selectedProjectId,
                      selectedFloor: _selectedFloor,
                      selectedPhase: _selectedPhase,
                      selectedActivity: _selectedActivity,
                      projectError: _projectError,
                      floorError: _floorError,
                      phaseError: _phaseError,
                      activityError: _activityError,
                      onProjectChanged: (v) {
                        setState(() {
                          _selectedProjectId = v;
                          _selectedFloor = null;
                          _selectedFloorId = null;
                          _selectedPhase = null;
                          _selectedPhaseId = null;
                          _selectedActivity = null;
                          _selectedActivityId = null;
                          _projectError = null;
                        });
                        final provider = Provider.of<ProjectProvider>(
                          context,
                          listen: false,
                        );
                        if (v != null) {
                          final project = provider.projects.firstWhere(
                            (p) => p.id == v,
                          );
                          provider.selectProject(project);
                        }
                      },
                      onFloorChanged: (v) {
                        setState(() {
                          _selectedFloor = v;
                          _selectedFloorId = v;
                          _selectedPhase = null;
                          _selectedPhaseId = null;
                          _selectedActivity = null;
                          _selectedActivityId = null;
                          _floorError = null;
                        });
                        Provider.of<ProjectProvider>(
                          context,
                          listen: false,
                        ).selectFloor(v);
                      },
                      onPhaseChanged: (v) {
                        final phaseName = v?.toString();
                        final phaseId = phaseName != null
                            ? _derivePhaseId(phaseName)
                            : null;
                        setState(() {
                          _selectedPhase = phaseName;
                          _selectedPhaseId = phaseId;
                          _selectedActivity = null;
                          _selectedActivityId = null;
                          _phaseError = null;
                        });
                        Provider.of<ProjectProvider>(
                          context,
                          listen: false,
                        ).selectPhase(phaseName, phaseId);
                      },
                      onActivityChanged: (v) {
                        final activityName = v?.toString();
                        final activityId = activityName != null
                            ? _deriveActivityId(activityName)
                            : null;
                        setState(() {
                          _selectedActivity = activityName;
                          _selectedActivityId = activityId;
                          _activityError = null;
                        });
                        Provider.of<ProjectProvider>(
                          context,
                          listen: false,
                        ).selectActivity(activityName, activityId);
                      },
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, 'Entry Type', done: true),
        _stepLine(done: true),
        _stepDot(2, 'Context', active: true),
        _stepLine(),
        _stepDot(3, 'How to Add'),
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
  Widget _buildBottomBar() {
    return BtCtaBar(vertical: true, children: [
      if (_canContinue)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline, color: Bt.green, size: 16),
            const SizedBox(width: 6),
            Text('Context selected — ready to continue', style: BtText.caption(context, color: Bt.green, weight: FontWeight.w600)),
          ]),
        ),
      BtButton(label: 'Continue', onPressed: _canContinue ? _onContinue : null),
    ]);
  }
}
