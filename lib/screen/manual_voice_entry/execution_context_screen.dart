import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:flutter/material.dart';
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
      if (_selectedFloor == null || _selectedFloor!.isEmpty) {
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
    provider.selectFloor(_selectedFloor);
    provider.selectPhase(_selectedPhase, phaseId);
    provider.selectActivity(_selectedActivity, activityId);
    Navigator.pushNamed(
      context,
      '/choose-entry-mode',
      arguments: {
        'type': _entryType,
        'projectId': _selectedProjectId,
        'floor': _selectedFloor,
        'floorId': _selectedFloorId ?? _selectedFloor,
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
      backgroundColor: AppColors.gradientStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Execution Context',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _entryType == 'material'
                                ? Icons.category_outlined
                                : _entryType == 'labour'
                                ? Icons.people_outline
                                : Icons.precision_manufacturing_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_entryTypeLabel Entry',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Where is this\nwork happening?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        height: 1.2,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select the project context once — it applies to both voice and manual entry.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    ExecutionContextCard(
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
        ? const Color(0xFF22C55E)
        : active
        ? AppColors.primary
        : const Color(0xFFE5E7EB);
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
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: active
                ? AppColors.primary
                : done
                ? const Color(0xFF22C55E)
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
          color: done ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFEEEBF8), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canContinue)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF22C55E),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Context selected — ready to continue',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _canContinue
                      ? const LinearGradient(
                          colors: [Color(0xFF173EEA), Color(0xFF6C3AFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: _canContinue ? null : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _canContinue ? _onContinue : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _canContinue
                                ? Colors.white
                                : AppColors.textLight,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _canContinue
                              ? Colors.white
                              : AppColors.textLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
