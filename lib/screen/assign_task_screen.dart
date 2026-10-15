import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
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
      globalTooltipActions: [TooltipActionButton(type: TooltipDefaultActionType.skip, backgroundColor: Colors.transparent, textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), TooltipActionButton(type: TooltipDefaultActionType.next, backgroundColor: AppColors.primary, textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))], 
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
    final users = _users;
    String? userLabel;
    for (final u in users) {
      if (u['_id'].toString() == _selectedUserId) userLabel = '${u['name']} (${u['role']})';
    }
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Assign task',
        trailing: Showcase(
          key: _helpKey,
          description: 'Get help and understand how this screen works.',
          child: BtIconButton(
            icon: Icons.help_outline_rounded,
            semantic: 'Help',
            color: Bt.ink2,
            onTap: () {
              ShowCaseWidget.of(context).startShowCase([_helpKey]);
            },
          ),
        ),
      ),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 4))
          : Form(
              key: _formKey,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  EntryLabeled(
                    label: 'Task title',
                    required: true,
                    child: TextFormField(
                      style: BtText.body(context),
                      decoration: btInput(context, hint: 'e.g. Cast slab — first floor'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      onSaved: (val) => _title = val ?? '',
                    ),
                  ),
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
                  const SizedBox(height: 24),
                  EntryLabeled(
                    label: 'Assign to',
                    child: BtPickerField(
                      text: userLabel ?? 'Select a person',
                      placeholder: userLabel == null,
                      icon: Icons.expand_more_rounded,
                      leading: Icons.person_outline_rounded,
                      onTap: () async {
                        final picked = await showBtSheet<String>(
                          context,
                          title: 'Assign to',
                          builder: (sheetCtx) => users.isEmpty
                              ? const BtEmpty(icon: Icons.group_outlined, title: 'No team members yet')
                              : BtGroup(
                                  children: [
                                    for (final u in users)
                                      BtRow(
                                        leading: BtAvatar(name: '${u['name']}', size: 36),
                                        title: '${u['name']}',
                                        subtitle: '${u['role']}',
                                        trailing: u['_id'].toString() == _selectedUserId
                                            ? Icon(Icons.check_rounded, color: sheetCtx.bt.brand)
                                            : null,
                                        onTap: () => Navigator.pop(sheetCtx, u['_id'].toString()),
                                      ),
                                  ],
                                ),
                        );
                        if (picked != null) setState(() => _selectedUserId = picked);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  EntryLabeled(
                    label: 'Details',
                    child: TextFormField(
                      maxLines: 4,
                      minLines: 3,
                      style: BtText.body(context),
                      decoration: btInput(context, hint: 'Anything the team should know (optional)'),
                      onSaved: (val) => _description = val ?? '',
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : EntryBottomBar(
              child: BtButton(label: 'Assign Task', onPressed: _submit),
            ),
    );
  }
}
