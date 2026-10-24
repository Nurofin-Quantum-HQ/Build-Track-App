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
  // Controllers keep the typed text in State. The form lives in a lazily-built
  // ListView: when the keyboard opens, the field scrolled out of view was
  // disposed and an uncontrolled TextFormField lost its text (title went blank
  // while typing details, and vice versa).
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  String get _title => _titleCtrl.text.trim();
  String get _description => _descriptionCtrl.text.trim();
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
    // The pickers here are local to this form: they must not change the
    // app's selected project/floor/phase (that switched Project detail and
    // the Home/Reports context behind this screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('AssignTaskScreen')) {
        ShowCaseWidget.of(context).startShowCase([_helpKey]);
      }
    });
  }
  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
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
      // Floor is only required when the project has floors (otherwise the
      // picker is disabled and its error hidden, so the tap did nothing).
      final provider = context.read<ProjectProvider>();
      final project = provider.projects.cast<ProjectModel?>().firstWhere(
        (p) => p?.id == _selectedProjectId,
        orElse: () => null,
      );
      final hasFloors = project?.floors?.isNotEmpty ?? false;
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
    if (_title.isEmpty) {
      btToast(context, 'Please enter a task title', error: true);
      _formKey.currentState?.validate();
      return;
    }
    if (!valid) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;
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
        await showBtSuccess(
          context,
          kind: BtSuccessKind.check,
          title: 'Task assigned successfully',
          message: _title,
          label: 'ASSIGN TASK',
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Error: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final users = _users;
    String? userName;
    for (final u in users) {
      if (u['_id'].toString() == _selectedUserId) userName = '${u['name']}';
    }
    final firstName = userName?.trim().split(RegExp(r'\s+')).first;
    final sections = <Widget>[
      EntryLabeled(
        label: 'Task title',
        required: true,
        child: TextFormField(
          controller: _titleCtrl,
          textInputAction: TextInputAction.next,
          style: BtText.body(context, weight: FontWeight.w600).copyWith(fontSize: 18),
          decoration: btInput(context, hint: 'e.g. Cast slab — first floor'),
          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
        ),
      ),
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
        },
      ),
      EntryLabeled(
        label: 'Assign to',
        child: users.isEmpty
            ? const BtCard(
                padding: EdgeInsets.zero,
                child: BtEmpty(icon: Icons.group_outlined, title: 'No team members yet'),
              )
            : SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final id = u['_id'].toString();
                    return _PersonChip(
                      name: '${u['name']}',
                      role: '${u['role']}',
                      selected: id == _selectedUserId,
                      onTap: () => setState(() => _selectedUserId = id),
                    );
                  },
                ),
              ),
      ),
      EntryLabeled(
        label: 'Details',
        child: TextFormField(
          controller: _descriptionCtrl,
          maxLines: 4,
          minLines: 3,
          style: BtText.body(context),
          decoration: btInput(context, hint: 'Anything the team should know (optional)'),
        ),
      ),
    ];
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Assign task',
        close: true,
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
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 24),
                BtReveal(index: i, child: sections[i]),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BtCtaBar(
        children: [
          Expanded(
            child: BtButton(
              label: firstName != null && firstName.isNotEmpty ? 'Assign to $firstName' : 'Assign Task',
              loading: _isLoading,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar + name chip for picking who gets the task.
class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.name, required this.role, required this.selected, required this.onTap});
  final String name, role;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $role',
      excludeSemantics: true,
      child: BtPressable(
        onTap: onTap,
        scale: .94,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: Bt.fast,
                    curve: Bt.ease,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? bt.accent : Colors.transparent, width: 2),
                    ),
                    child: BtAvatar(name: name, size: 52),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: Bt.medium,
                      curve: Bt.spring,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle, border: Border.all(color: Bt.ground, width: 2)),
                        child: Icon(Icons.check_rounded, size: 13, color: bt.onAccent),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: selected ? Bt.ink : Bt.ink2, weight: selected ? FontWeight.w600 : FontWeight.w500)),
              Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context).copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
