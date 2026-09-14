import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';

class AssignTaskScreen extends StatelessWidget {
  final ProjectModel? initialProject;
  const AssignTaskScreen({super.key, this.initialProject});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      globalTooltipActions: const [TooltipActionButton(type: TooltipDefaultActionType.skip, backgroundColor: Colors.transparent, textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), TooltipActionButton(type: TooltipDefaultActionType.next, backgroundColor: AppColors.primary, textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))], 
      enableAutoScroll: true,
      onFinish: () => UserSession.markModuleVisited('AssignTaskScreen'),
      builder: (context) => _AssignTaskScreenContent(initialProject: initialProject),
    );
  }
}

class _AssignTaskScreenContent extends StatefulWidget {
  final ProjectModel? initialProject;
  const _AssignTaskScreenContent({this.initialProject});
  @override
  State<_AssignTaskScreenContent> createState() => _AssignTaskScreenContentState();
}

class _AssignTaskScreenContentState extends State<_AssignTaskScreenContent> {
  final GlobalKey _helpKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
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
  String? _selectedUserId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProject?.id;
    _fetchUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedProjectId != null) {
        final provider = Provider.of<ProjectProvider>(context, listen: false);
        final project = provider.projects.cast<ProjectModel?>().firstWhere(
          (p) => p?.id == _selectedProjectId,
          orElse: () => null,
        );
        if (project != null) {
          provider.selectProject(project);
        }
      }
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('AssignTaskScreen')) {
        ShowCaseWidget.of(context).startShowCase([_helpKey]);
      }
    });
  }
  Future<void> _fetchUsers() async {
    try {
      final users = await TaskService.getAssignableUsers();
      if (mounted) {
        setState(() {
          _users = users;
        });
      }
    } catch (e) {
    }
  }
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
  Future<void> _submit() async {
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
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      final phaseId = _selectedPhaseId ?? _derivePhaseId(_selectedPhase);
      final activityId =
          _selectedActivityId ?? _deriveActivityId(_selectedActivity);
      await TaskService.createTask({
        'project': _selectedProjectId,
        'title': _title,
        'description': _description,
        'assignedTo': _selectedUserId,
        'floorId': _selectedFloorId ?? _selectedFloor,
        'floorName': _selectedFloor,
        'phaseId': phaseId,
        'phaseName': _selectedPhase,
        'activityId': activityId,
        'activityName': _selectedActivity,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              title: 'Assign Task',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
              rightWidget: Showcase(
                key: _helpKey,
                description: 'Get help and understand how this screen works.',
                child: IconButton(
                  icon: const Icon(Icons.help_outline, color: AppColors.primary),
                  onPressed: () {
                    ShowCaseWidget.of(context).startShowCase([_helpKey]);
                  },
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Task Context',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 24),
                            const Text(
                              'Task Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Task Title',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Enter task title',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                        ? 'Required'
                                        : null,
                                    onSaved: (val) => _title = val ?? '',
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Description (Optional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Details about the task',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onSaved: (val) => _description = val ?? '',
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Assign To',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedUserId,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Select a user',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    items: _users
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u['_id'].toString(),
                                            child: Text(
                                              '${u['name']} (${u['role']})',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedUserId = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Assign Task',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
