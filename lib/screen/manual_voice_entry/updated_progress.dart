import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/models/task_model.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
class UpdateProgressScreen extends StatefulWidget {
  const UpdateProgressScreen({super.key});
  @override
  State<UpdateProgressScreen> createState() => _UpdateProgressScreenState();
}
class _UpdateProgressScreenState extends State<UpdateProgressScreen> {
  String? _selectedProjectId;
  String? _selectedFloor;
  String? _selectedPhaseName;
  String? _selectedActivityName;
  String? _prefillActivityId;
  bool _argsLoaded = false;
  bool _launchedFromTracker = false;
  final TextEditingController _notesCtrl = TextEditingController();
  late double _completionProgress;
  DateTime _selectedDate = DateTime.now();
  DateTime? _completionDate;
  List<PhotoAttachment> _attachments = [];
  late final List<ConstructionPhase> _catalogue;
  List<TaskModel> _dailyTasks = [];
  bool _isLoadingTasks = true;
  final Set<String> _completedTaskIds = {};
  bool _submitting = false;
  /// True once the user moves the slider. Only then is `progress` sent;
  /// otherwise the server derives it from completed / total activities.
  bool _progressTouched = false;
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  @override
  void initState() {
    super.initState();
    _catalogue = buildDefaultPhases();
    final provider = context.read<ProjectProvider>();
    // Default: the app's selected project (Home's current project), else the
    // only project. UserSession.projectId alone could be '' / not in the list.
    _selectedProjectId = provider.defaultProjectForForm?.id ??
        (UserSession.projectId.isNotEmpty ? UserSession.projectId : null);
    _completionProgress = provider.projectById(_selectedProjectId)?.progress ??
        provider.selectedProject?.progress ?? 0.0;
    _fetchDailyTasks();
  }
  Future<void> _fetchDailyTasks() async {
    try {
      final tasks = await TaskService.getDailyTasks();
      if (mounted) {
        setState(() {
          _dailyTasks = tasks.where((t) => t.status != 'Completed').toList();
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }
  Future<void> _showEditTaskDialog(
    BuildContext context,
    TaskModel task,
    VoidCallback onSave,
  ) async {
    String? updatedStatus = task.status;
    final TextEditingController titleCtrl = TextEditingController(
      text: task.title,
    );
    final TextEditingController descCtrl = TextEditingController(
      text: task.description,
    );
    bool saving = false;
    // Title/description: Admin, or the assigner who still holds assign_tasks
    // (PUT /tasks/:id returns 403 otherwise). Assignees may change the status.
    final bool canEditDetails = UserSession.isAdmin ||
        (RoleManager.canAssignTasks && task.createdBy != null && task.createdBy == UserSession.userId);
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Bt.ground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
              title: Text('Edit task', style: BtText.title(ctx, size: 20)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Title', style: BtText.subhead(ctx, weight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: titleCtrl,
                      enabled: canEditDetails,
                      style: BtText.body(ctx),
                      decoration: btInput(ctx),
                    ),
                    const SizedBox(height: 12),
                    Text('Description', style: BtText.subhead(ctx, weight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: descCtrl,
                      enabled: canEditDetails,
                      maxLines: 3,
                      style: BtText.body(ctx),
                      decoration: btInput(ctx),
                    ),
                    const SizedBox(height: 12),
                    Text('Status', style: BtText.subhead(ctx, weight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue:
                          [
                            'Not Started',
                            'In Progress',
                            'Completed',
                          ].contains(updatedStatus)
                          ? updatedStatus
                          : 'Not Started',
                      items: ['Not Started', 'In Progress', 'Completed']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          updatedStatus = v;
                        });
                      },
                      style: BtText.body(ctx),
                      decoration: btInput(ctx),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(foregroundColor: Bt.ink2, minimumSize: const Size(64, 44)),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Bt.ink,
                    foregroundColor: Bt.bone,
                    minimumSize: const Size(88, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            // Send only what changed: the details call is
                            // refused for assignees, which used to block the
                            // status change too.
                            final details = <String, dynamic>{
                              if (canEditDetails && titleCtrl.text.trim() != task.title) 'title': titleCtrl.text.trim(),
                              if (canEditDetails && descCtrl.text.trim() != task.description) 'description': descCtrl.text.trim(),
                            };
                            if (details.isNotEmpty) {
                              await TaskService.updateTask(task.id, details);
                            }
                            if (updatedStatus != null && updatedStatus != task.status) {
                              await TaskService.updateTaskStatus(task.id, updatedStatus!);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            onSave();
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              btToast(ctx, 'Could not save the task: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Bt.bone),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _loadActivityDetails() {
    if (_selectedProjectId == null || _selectedActivityName == null) return;
    final provider = context.read<ProjectProvider>();
    final project = provider.projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _selectedProjectId,
      orElse: () => null,
    );
    if (project != null) {
      final matchedAct = _resolveActivity(project);
      if (matchedAct != null) {
        setState(() {
          if (matchedAct.notes != null && matchedAct.notes!.trim().isNotEmpty) {
            _notesCtrl.text = matchedAct.notes!;
          } else {
            _notesCtrl.clear();
          }
          if (matchedAct.completedAt != null) {
            _selectedDate = matchedAct.completedAt!;
          } else {
            _selectedDate = DateTime.now();
          }
          if (matchedAct.photos != null && matchedAct.photos!.isNotEmpty) {
            _attachments = matchedAct.photos!
                .map((url) => PhotoAttachment.remote(url))
                .toList();
          } else if (matchedAct.photo != null && matchedAct.photo!.isNotEmpty) {
            _attachments = [PhotoAttachment.remote(matchedAct.photo!)];
          } else {
            _attachments = [];
          }
        });
      }
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final task = args['task'];
      if (task != null) {
        _launchedFromTracker = true;
        _selectedProjectId = task.project;
        if (task.floorName != null && task.floorName!.isNotEmpty) {
          _selectedFloor = task.floorName;
        }
        if (task.phaseName != null && task.phaseName!.isNotEmpty) {
          _selectedPhaseName = task.phaseName;
        }
        if (task.activityName != null && task.activityName!.isNotEmpty) {
          _selectedActivityName = task.activityName;
        }
        // The task names its activity by id — use it (name alone can match
        // the same activity name in another phase).
        if (task.activityId != null && task.activityId!.isNotEmpty) {
          _prefillActivityId = task.activityId;
        }
        _completedTaskIds.add(task.id);
        final String taskProjectId = task.project;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _hydrateProject(taskProjectId);
        });
        return; // Early return to skip other args if task is provided
      }
      final projectId = args['projectId'] as String?;
      final phaseName = args['phaseName'] as String?;
      final activityName = args['activityName'] as String?;
      final activityId = args['activityId'] as String?;
      final floor = args['floor'] as String?;
      final floors = args['projectFloors'] as List<String>?;
      if (projectId != null && phaseName != null && activityName != null) {
        _launchedFromTracker = true;
        _selectedProjectId = projectId;
        _selectedPhaseName = phaseName;
        _selectedActivityName = activityName;
        _prefillActivityId = activityId;
        if (floor != null && floor.isNotEmpty && (floors == null || floors.contains(floor))) {
          _selectedFloor = floor;
        } else if (floors != null && floors.isNotEmpty) {
          _selectedFloor = floors.first;
        } else {
          _selectedFloor = null;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _hydrateProject(projectId);
        });
      } else if (projectId != null && projectId.isNotEmpty) {
        // Partial context (project, maybe phase): pre-fill what was given and
        // leave the rest editable (not the locked tracker layout).
        _selectedProjectId = projectId;
        if (floor != null && floor.isNotEmpty) _selectedFloor = floor;
        if (phaseName != null && phaseName.isNotEmpty) _selectedPhaseName = phaseName;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _hydrateProject(projectId);
        });
      }
    }
  }

  /// Fill empty floor / phase / activity when the project has exactly one
  /// (build-safe: local fields only, no setState).
  void _autoPickSingles(ProjectModel? project) {
    if (_launchedFromTracker || project == null) return;
    final floors = project.floors ?? const <String>[];
    if (floors.length == 1 && _selectedFloor == null) _selectedFloor = floors.first;
    if (floors.isNotEmpty && _selectedFloor == null) return;
    if (_selectedPhaseName == null) {
      final phases = _phasesFor(project);
      if (phases.length == 1) _selectedPhaseName = phases.first;
    }
    if (_selectedPhaseName == null || _selectedActivityName != null) return;
    final acts = _activitiesFor(project, _selectedPhaseName);
    if (acts.length == 1) {
      _selectedActivityName = acts.first;
      _prefillActivityId = null;
    }
  }

  /// Finds the project for this update. A project reached only through an
  /// assigned task isn't in the user's local list, so it is fetched (the
  /// backend accepts updates from the task's assignee).
  Future<ProjectModel?> _projectById(String id) async {
    final provider = context.read<ProjectProvider>();
    final local = provider.projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == id,
      orElse: () => null,
    );
    return local ?? await provider.ensureProject(id);
  }

  Future<void> _hydrateProject(String id) async {
    final project = await _projectById(id);
    if (!mounted || project == null) return;
    setState(() => _completionProgress = project.progress);
    _loadActivityDetails();
  }

  /// The project activity this update is for: by id first; then by name in
  /// the selected phase; then by name anywhere only if exactly one matches.
  ProjectActivity? _resolveActivity(ProjectModel? project) {
    if (project == null) return null;
    final phases = project.selectedPhases ?? const <ProjectPhase>[];
    final all = phases.expand((ph) => ph.activities).toList();
    if (_prefillActivityId != null && _prefillActivityId!.isNotEmpty) {
      for (final a in all) {
        if (a.id == _prefillActivityId) return a;
      }
    }
    final name = _selectedActivityName;
    if (name == null || name.isEmpty) return null;
    for (final ph in phases) {
      if (ph.phaseName != _selectedPhaseName) continue;
      for (final a in ph.activities) {
        if (a.name == name) return a;
      }
    }
    final byName = all.where((a) => a.name == name).toList();
    return byName.length == 1 ? byName.first : null;
  }
  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
  List<String> _phasesFor(ProjectModel? project) {
    if (project == null) return [];
    // The project's own plan first (custom phases/activities live there).
    final planned = (project.selectedPhases ?? const <ProjectPhase>[])
        .where((ph) => ph.activities.isNotEmpty)
        .map((ph) => ph.phaseName)
        .toList();
    if (planned.isNotEmpty) return planned;
    if (project.selectedPhaseNames != null &&
        project.selectedPhaseNames!.isNotEmpty) {
      return project.selectedPhaseNames!;
    }
    return _catalogue.map((p) => p.name).toList();
  }
  List<String> _activitiesFor(ProjectModel? project, String? phaseName) {
    if (phaseName == null) return [];
    final planned = (project?.selectedPhases ?? const <ProjectPhase>[])
        .cast<ProjectPhase?>()
        .firstWhere((ph) => ph?.phaseName == phaseName, orElse: () => null);
    if (planned != null && planned.activities.isNotEmpty) {
      return planned.activities.map((a) => a.name).toSet().toList();
    }
    final match = _catalogue.cast<ConstructionPhase?>().firstWhere(
      (p) => p?.name == phaseName,
      orElse: () => null,
    );
    if (match == null) return [];
    return match.allActivities.map((a) => a.name).toList();
  }
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(text, style: BtText.subhead(context, weight: FontWeight.w500)),
  );
  Widget _sectionTitle(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: BtText.headline(context))),
        ?trailing,
      ],
    ),
  );
  Widget _dropdownCard<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    bool enabled = true,
  }) {
    final bool hasValue = items.any((i) => i.value == value);
    final T? safe = hasValue ? value : null;
    return AnimatedOpacity(
      duration: Bt.fast,
      opacity: enabled ? 1.0 : 0.45,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safe,
          isExpanded: true,
          borderRadius: BorderRadius.circular(Bt.rInput),
          dropdownColor: Bt.card,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? Bt.ink2 : Bt.placeholder,
            size: 22,
          ),
          hint: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BtText.body(context, color: Bt.placeholder),
          ),
          style: BtText.body(context, weight: FontWeight.w500),
          items: enabled ? items : <DropdownMenuItem<T>>[],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        final projects = provider.projects;
        final selProject = _selectedProjectId == null
            ? null
            : projects.cast<ProjectModel?>().firstWhere(
                (p) => p?.id == _selectedProjectId,
                orElse: () => null,
              );
        _autoPickSingles(selProject);
        final floors = (selProject?.floors?.isNotEmpty ?? false)
            ? List<String>.from(selProject!.floors!)
            : <String>[];
        if (floors.isNotEmpty &&
            _selectedFloor != null &&
            !floors.contains(_selectedFloor)) {
          floors.add(_selectedFloor!);
        }
        final phaseNames = _phasesFor(selProject);
        final activityNames = _activitiesFor(selProject, _selectedPhaseName);
        // Named sections. Each is keyed so a section appearing or going away
        // (stage card, "Your tasks") never hands another section's state —
        // e.g. the Notes field and its focus — to a different widget.
        final sections = <MapEntry<String, Widget>>[
          if (_launchedFromTracker) MapEntry('banner', _buildTrackerContextBanner(projects)),
          MapEntry('where', _buildContextCard(
            projects: projects,
            floors: floors,
            phaseNames: phaseNames,
            activityNames: activityNames,
          )),
          if (_selectedPhaseName != null &&
              (floors.isEmpty || _selectedFloor != null))
            MapEntry('stage', _buildStageSummaryCard()),
          MapEntry('tasks', _buildTaskChecklist()),
          MapEntry('notes', _buildExecutionNotes()),
          MapEntry('photos', _buildPhotoUpload()),
          MapEntry('materials', _buildMaterialConsumption(context, provider)),
          MapEntry('dates', _buildDateField()),
        ];
        final visible = sections.where((e) => e.value is! SizedBox).toList();
        return Scaffold(
          backgroundColor: Bt.ground,
          appBar: BtNavBar(
            title: _launchedFromTracker ? 'Progress update' : 'Daily update',
          ),
          // A plain (non-lazy) column: in a lazy ListView every section was
          // rebuilt — and its entrance animation replayed — each time it
          // scrolled back into view. Here each section reveals once.
          body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++)
                  Padding(
                    key: ValueKey('section-${visible[i].key}'),
                    padding: EdgeInsets.only(top: i > 0 ? 24 : 0),
                    child: BtReveal(index: i, child: visible[i].value),
                  ),
              ],
            ),
          ),
          // Lifted by the keyboard height so Submit stays visible while typing.
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: BtCtaBar(children: [Expanded(child: _buildSaveButton(context, provider))]),
          ),
        );
      },
    );
  }
  Widget _buildTrackerContextBanner(List<ProjectModel> projects) {
    final projectName = projects
        .cast<ProjectModel?>()
        .firstWhere((p) => p?.id == _selectedProjectId, orElse: () => null)
        ?.name;
    final where = [projectName, _selectedFloor, _selectedPhaseName, _selectedActivityName]
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: Bt.ink.withValues(alpha: .05), borderRadius: BorderRadius.circular(Bt.rTile)),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 16, color: Bt.ink2),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                if (where.isNotEmpty) TextSpan(text: where.first, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                if (where.length > 1) TextSpan(text: ' · ${where.skip(1).join(' · ')}', style: BtText.subhead(context)),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(formatDate(_selectedDate), style: BtText.num(BtText.caption(context))),
        ],
      ),
    );
  }

  /// One "Where" picker row: label on the left, picker on the right.
  Widget _whereRow(String label, Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(width: 84, child: Text(label, style: BtText.subhead(context))),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildContextCard({
    required List<ProjectModel> projects,
    required List<String> floors,
    required List<String> phaseNames,
    required List<String> activityNames,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Where'),
        BtGroup(
          insetDividers: false,
          children: [
            _whereRow(
              'Project',
              _launchedFromTracker
                  ? _lockedField(
                      projects
                              .cast<ProjectModel?>()
                              .firstWhere(
                                (p) => p?.id == _selectedProjectId,
                                orElse: () => null,
                              )
                              ?.name ??
                          'Project',
                    )
                  : _dropdownCard<String>(
                      value: _selectedProjectId,
                      hint: 'Select project',
                      items: projects
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() {
                        _selectedProjectId = val;
                        _selectedFloor = null;
                        _selectedPhaseName = null;
                        _selectedActivityName = null;
                        _prefillActivityId = null;
                        _progressTouched = false;
                        final p = projects.cast<ProjectModel?>().firstWhere(
                          (x) => x?.id == val,
                          orElse: () => null,
                        );
                        _completionProgress = p?.progress ?? 0.0;
                      }),
                    ),
            ),
            _whereRow(
              'Floor / Zone',
              _dropdownCard<String>(
                value: floors.isEmpty ? null : _selectedFloor,
                hint: _selectedProjectId == null
                    ? 'Select project first'
                    : (floors.isEmpty ? '' : 'Select floor or zone'),
                enabled: _selectedProjectId != null && floors.isNotEmpty,
                items: floors.isEmpty
                    ? <DropdownMenuItem<String>>[]
                    : floors
                        .map((f) => DropdownMenuItem<String>(value: f, child: Text(f)))
                        .toList(),
                onChanged: (_selectedProjectId == null || floors.isEmpty)
                    ? null
                    : (val) => setState(() {
                        _selectedFloor = val;
                        if (!_launchedFromTracker) {
                          _selectedPhaseName = null;
                          _selectedActivityName = null;
                          _prefillActivityId = null;
                        }
                      }),
              ),
            ),
            _whereRow(
              'Phase',
              _launchedFromTracker
                  ? _lockedField(_selectedPhaseName ?? 'Phase')
                  : _dropdownCard<String>(
                      value: _selectedPhaseName,
                      hint: _selectedProjectId == null
                          ? 'Select project first'
                          : (floors.isNotEmpty && _selectedFloor == null
                              ? 'Select floor first'
                              : 'Select phase'),
                      enabled: _selectedProjectId != null &&
                          (floors.isEmpty || _selectedFloor != null),
                      items: phaseNames
                          .map(
                            (n) =>
                                DropdownMenuItem<String>(value: n, child: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          )
                          .toList(),
                      onChanged: (_selectedProjectId == null ||
                              (floors.isNotEmpty && _selectedFloor == null))
                          ? null
                          : (val) => setState(() {
                              _selectedPhaseName = val;
                              _selectedActivityName = null;
                              _prefillActivityId = null;
                            }),
                    ),
            ),
            _whereRow(
              'Activity',
              _launchedFromTracker
                  ? _lockedField(_selectedActivityName ?? 'Activity')
                  : _dropdownCard<String>(
                      value: _selectedActivityName,
                      hint: _selectedPhaseName == null
                          ? 'Select phase first'
                          : 'Select activity',
                      enabled:
                          _selectedPhaseName != null && activityNames.isNotEmpty,
                      items: activityNames.isEmpty && _selectedPhaseName != null
                          ? [
                              const DropdownMenuItem<String>(
                                value: '__none',
                                child: Text('No activities configured'),
                              ),
                            ]
                          : activityNames
                                .map(
                                  (a) => DropdownMenuItem<String>(
                                    value: a,
                                    child: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                      onChanged:
                          (_selectedPhaseName == null || activityNames.isEmpty)
                          ? null
                          : (val) => setState(() {
                              _selectedActivityName = val;
                              _prefillActivityId = null;
                            }),
                    ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _lockedField(String value) {
    return Row(
      children: [
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w500, color: Bt.ink2))),
        const Icon(Icons.lock_outline_rounded, size: 16, color: Bt.ink3),
      ],
    );
  }

  Widget _buildStageSummaryCard() {
    final bt = context.bt;
    return BtCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT ACTIVITY', style: BtText.mono(context)),
          const SizedBox(height: 8),
          Text(_selectedPhaseName ?? '', style: BtText.d3(context)),
          if (_selectedActivityName != null) ...[
            const SizedBox(height: 2),
            Text(_selectedActivityName!, style: BtText.subhead(context, weight: FontWeight.w600, color: bt.accentInk)),
          ],
          if (_selectedFloor != null && _selectedFloor!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Bt.ink3, size: 14),
                const SizedBox(width: 4),
                Text(_selectedFloor!, style: BtText.caption(context)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('Overall completion', style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink))),
              Text(
                '${(_completionProgress * 100).toInt()}%',
                style: BtText.num(BtText.d3(context, color: bt.accentInk)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: bt.accent,
              inactiveTrackColor: Bt.ink.withValues(alpha: .09),
              thumbColor: Colors.white,
              overlayColor: bt.accent.withValues(alpha: 0.22),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: _completionProgress,
              onChanged: (v) => setState(() {
                _completionProgress = v;
                _progressTouched = true;
              }),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTaskChecklist() {
    if (_isLoadingTasks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: BtSkeletonList(count: 2),
      );
    }
    final relevantTasks = _dailyTasks.where((task) {
      if (_selectedProjectId != null && task.project != _selectedProjectId) {
        return false;
      }
      if (_selectedFloor != null && task.floorName != _selectedFloor) {
        return false;
      }
      if (_selectedPhaseName != null && task.phaseName != _selectedPhaseName) {
        return false;
      }
      if (_selectedActivityName != null &&
          task.activityName != _selectedActivityName) {
        return false;
      }
      return true;
    }).toList();
    if (relevantTasks.isEmpty) {
      return const SizedBox.shrink();
    }
    final bt = context.bt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Your tasks', trailing: Text('${relevantTasks.length}', style: BtText.num(BtText.subhead(context)))),
        BtGroup(
          insetDividers: false,
          children: relevantTasks.map((task) {
              final isCompleted = _completedTaskIds.contains(task.id);
              return CheckboxListTile(
                value: isCompleted,
                secondary: task.status != 'Completed'
                    ? BtIconButton(
                        icon: Icons.edit_outlined,
                        size: 20,
                        semantic: 'Edit task',
                        color: Bt.ink2,
                        onTap: () => _showEditTaskDialog(context, task, () {
                          if (context.mounted) _fetchDailyTasks();
                        }),
                      )
                    : null,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _completedTaskIds.add(task.id);
                      if (task.project.isNotEmpty) {
                        _selectedProjectId = task.project;
                      }
                      if (task.floorName != null &&
                          task.floorName!.isNotEmpty) {
                        _selectedFloor = task.floorName;
                      }
                      if (task.phaseName != null &&
                          task.phaseName!.isNotEmpty) {
                        _selectedPhaseName = task.phaseName;
                      }
                      if (task.activityName != null &&
                          task.activityName!.isNotEmpty) {
                        _selectedActivityName = task.activityName;
                        _prefillActivityId = (task.activityId != null && task.activityId!.isNotEmpty) ? task.activityId : null;
                      }

                      final provider = context.read<ProjectProvider>();
                      final project = provider.projects.cast<ProjectModel?>().firstWhere(
                        (p) => p?.id == _selectedProjectId,
                        orElse: () => null,
                      );
                      if (project != null) {
                        _completionProgress = project.progress;
                        _loadActivityDetails();
                      }
                    } else {
                      _completedTaskIds.remove(task.id);
                    }
                  });
                },
                title: Text(
                  task.title,
                  style: BtText.body(context, weight: FontWeight.w600, color: isCompleted ? Bt.ink3 : Bt.ink).copyWith(
                    fontSize: 15,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: task.description.isNotEmpty
                    ? Text(
                        task.description,
                        style: BtText.caption(context),
                      )
                    : null,
                activeColor: Bt.greenBright,
                checkColor: Colors.white,
                checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: const BorderSide(color: Bt.inputBorder, width: 1.5),
                overlayColor: WidgetStatePropertyAll(bt.accent.withValues(alpha: .12)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              );
            }).toList(),
        ),
      ],
    );
  }
  Widget _buildExecutionNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('What got done today?'),
        TextField(
          controller: _notesCtrl,
          maxLines: 5,
          minLines: 4,
          style: BtText.body(context),
          decoration: btInput(context, hint: 'What work was completed today?'),
        ),
      ],
    );
  }
  Widget _buildDateField() {
    final updateDateStr =
        '${_months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
    final completionDateStr = _completionDate != null
        ? '${_months[_completionDate!.month - 1]} ${_completionDate!.day}, ${_completionDate!.year}'
        : 'Select date';
    Theme pickerTheme(BuildContext ctx, Widget? child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: Bt.ink,
              onPrimary: Bt.bone,
              onSurface: Bt.ink,
            ),
          ),
          child: child!,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('Update date'),
              // The field handles the tap itself. Before, it sat inside
              // IgnorePointer under a GestureDetector: IgnorePointer removes the
              // child from hit-testing, so the (deferToChild) detector never
              // received the tap and the picker never opened.
              BtPickerField(
                text: updateDateStr,
                icon: Icons.calendar_today_outlined,
                onTap: () => _pickDate(
                  initial: _selectedDate,
                  theme: pickerTheme,
                  onPicked: (d) => _selectedDate = d,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel('Completion date'),
              BtPickerField(
                text: completionDateStr,
                placeholder: _completionDate == null,
                icon: Icons.calendar_today_outlined,
                onTap: () => _pickDate(
                  initial: _completionDate ?? DateTime.now(),
                  theme: pickerTheme,
                  onPicked: (d) => _completionDate = d,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  static final DateTime _firstPickable = DateTime(2020);
  static final DateTime _lastPickable = DateTime(2100);

  /// Opens the date picker. The initial date is clamped into the picker's
  /// range (an activity's stored completedAt can be outside it, which made
  /// showDatePicker throw), and any failure is shown instead of swallowed.
  Future<void> _pickDate({
    required DateTime initial,
    required Widget Function(BuildContext, Widget?) theme,
    required void Function(DateTime) onPicked,
  }) async {
    try {
      final safeInitial = initial.isBefore(_firstPickable)
          ? _firstPickable
          : (initial.isAfter(_lastPickable) ? _lastPickable : initial);
      final picked = await showDatePicker(
        context: context,
        initialDate: safeInitial,
        firstDate: _firstPickable,
        lastDate: _lastPickable,
        builder: theme,
      );
      if (picked != null && mounted) setState(() => onPicked(picked));
    } catch (e) {
      if (mounted) btToast(context, 'Could not open the date picker: $e', error: true);
    }
  }
  Future<void> _addPhoto() async {
    final result = await pickAttachmentDirect(context);
    if (result != null) {
      setState(() {
        _attachments.add(PhotoAttachment.local(result));
      });
    }
  }
  Widget _buildPhotoUpload() {
    Widget addTile({bool faded = false}) => Semantics(
          button: true,
          label: 'Add photo',
          excludeSemantics: true,
          child: BtPressable(
            onTap: _addPhoto,
            scale: .94,
            child: Opacity(
              opacity: faded ? .5 : 1,
              child: CustomPaint(
                painter: const _DashedBorderPainter(color: Bt.inputBorder, radius: Bt.rTile),
                child: const Center(child: Icon(Icons.add_a_photo_outlined, color: Bt.ink3, size: 24)),
              ),
            ),
          ),
        );
    final tiles = <Widget>[
      for (var index = 0; index < _attachments.length; index++)
        Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Bt.rTile),
              child: _attachments[index].isImage
                  ? Image(
                      image: _attachments[index].imageProvider,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Container(
                      color: _attachments[index].iconBg,
                      child: Center(
                        child: Icon(
                          _attachments[index].icon,
                          color: _attachments[index].iconColor,
                          size: 28,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: 'Remove photo ${index + 1}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _attachments.removeAt(index);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xB30C0E12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      if (_attachments.length < 4) addTile(),
      if (_attachments.length < 3) addTile(faded: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Photos',
          trailing: Text('${_attachments.length} of 4', style: BtText.num(BtText.caption(context))),
        ),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),
        if (_attachments.isEmpty) ...[
          const SizedBox(height: 8),
          Text('Tap to add site photos (up to 4) · PNG, JPG, jpeg', style: BtText.caption(context)),
        ],
      ],
    );
  }
  Widget _buildMaterialConsumption(
    BuildContext context,
    ProjectProvider provider,
  ) {
    List<EntryModel> materials = [];
    final selProject = _selectedProjectId == null
        ? null
        : provider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == _selectedProjectId,
            orElse: () => null,
          );
    final hasFloors = selProject?.floors?.isNotEmpty ?? false;
    if (_selectedProjectId != null && (!hasFloors || _selectedFloor != null)) {
      materials = provider.entries
          .where(
            (e) =>
                e.type == EntryType.material &&
                e.projectId == _selectedProjectId &&
                (!hasFloors || e.floor == _selectedFloor),
          )
          .toList();
    }
    final bt = context.bt;
    return BtCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BtTile(icon: Icons.inventory_2_outlined, bg: bt.accentSoft, fg: bt.accentInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Material consumption', style: BtText.body(context, weight: FontWeight.w600)),
                    Text(
                      materials.isEmpty ? 'No materials logged for this location yet.' : '${materials.length} logged here',
                      maxLines: 2,
                      style: BtText.caption(context),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/add-material',
                  arguments: {'type': 'material'},
                ),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
                child: Text('Add material', style: BtText.subhead(context, weight: FontWeight.w600, color: bt.accentInk)),
              ),
            ],
          ),
          if (materials.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Bt.line),
            const SizedBox(height: 4),
            ...materials.map(
              (m) => Padding(
                padding: const EdgeInsets.only(top: 8, right: 6),
                child: _materialTag(m.description, m.amount.toString()),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _materialTag(String label, String qty) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: context.bt.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: BtText.subhead(context, weight: FontWeight.w500, color: Bt.ink),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Bt.fill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            qty,
            style: BtText.num(BtText.caption(context, color: Bt.ink, weight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
  Widget _buildSaveButton(BuildContext context, ProjectProvider provider) {
    final label =
        (_launchedFromTracker && _prefillActivityId != null) ||
            _selectedActivityName != null
        ? 'Mark as Done & Submit'
        : 'Submit Progress Update';
    return BtButton(
      label: label,
      icon: _launchedFromTracker ? Icons.check_circle_rounded : Icons.check_circle_outline,
      loading: _submitting,
      onPressed: () async {
        if (_submitting) return;
        // Validate up front so a tap never silently does nothing.
        if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
          btToast(context, 'Select a project first.', error: true);
          return;
        }
        FocusScope.of(context).unfocus();
        setState(() => _submitting = true);
        try {
          final targetProjectId = _selectedProjectId!;
          final project = await _projectById(targetProjectId);
          if (!mounted) return;
          if (project == null) {
            btToast(context, 'Could not load this project. Check your connection and try again.', error: true);
            return;
          }
          final notes = _notesCtrl.text.trim();
          final hasDetails = notes.isNotEmpty || _attachments.isNotEmpty || _completionDate != null;
          final activity = _resolveActivity(project);
          if (_selectedActivityName != null && _selectedActivityName != '__none' && activity == null) {
            btToast(context, '"$_selectedActivityName" isn\'t in this project\'s plan. Pick an activity from the list.', error: true);
            return;
          }
          if (activity == null && hasDetails) {
            btToast(context, 'Pick an activity — notes, photos and the completion date are saved on an activity.', error: true);
            return;
          }
          if (activity == null && !_progressTouched) {
            btToast(context, 'Nothing to save yet — pick an activity, or move the progress slider.', error: true);
            return;
          }
          final bool success;
          if (activity != null) {
            // One save marks the activity done with its date, notes, photos
            // (and the progress only if the user set it).
            success = await provider.toggleActivityCompletion(
              targetProjectId,
              activity.id,
              completedAt: _completionDate ?? _selectedDate,
              notes: notes.isNotEmpty ? notes : null,
              photo: _attachments.isNotEmpty ? _attachments.first.dataUri : null,
              photos: _attachments.map((a) => a.dataUri).toList(),
              manualProgress: _progressTouched ? _completionProgress : null,
            );
          } else {
            success = await provider.updateProjectProgress(targetProjectId, _completionProgress);
          }
          if (!mounted) return;
          if (!success) {
            btToast(context, provider.lastSaveError ?? 'Could not save this update. Try again.', error: true);
            return;
          }
          // Tasks are closed only after the update itself was saved.
          var taskFailures = 0;
          for (final taskId in _completedTaskIds) {
            try {
              await TaskService.updateTaskStatus(taskId, 'Completed');
            } catch (e) {
              taskFailures++;
              debugPrint('Failed to complete task $taskId: $e');
            }
          }
          if (!context.mounted) return;
          if (taskFailures > 0) {
            btToast(context, 'Update saved, but $taskFailures ${taskFailures == 1 ? 'task' : 'tasks'} could not be marked completed.', error: true);
          }
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final dateLabel =
              '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
          await showBtSuccess(
            context,
            kind: BtSuccessKind.check,
            title: activity != null
                ? '${activity.name} marked done'
                : 'Progress updated',
            message: dateLabel,
            label: 'DAILY UPDATE',
          );
          if (!context.mounted) return;
          Navigator.maybePop(context);
        } catch (e) {
          debugPrint('Progress update failed: $e');
          if (context.mounted) {
            btToast(context, 'Could not save this update: $e', error: true);
          }
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
    );
  }
}

/// Dashed rounded outline for the "add photo" tiles.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(.75));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color || old.radius != radius;
}
class PhotoAttachment {
  final PickedAttachment? localAttachment;
  final String? remoteUrl;
  /// Built once: a new MemoryImage per build (base64 decoded again) missed
  /// the image cache, so every rebuild re-decoded every photo.
  ImageProvider? _imageProvider;
  PhotoAttachment.local(this.localAttachment) : remoteUrl = null;
  PhotoAttachment.remote(this.remoteUrl) : localAttachment = null;
  bool get isImage {
    if (localAttachment != null) {
      return localAttachment!.isImage;
    }
    final url = remoteUrl!.toLowerCase();
    return url.startsWith('data:image/') ||
        url.contains(';base64,') ||
        url.endsWith('.png') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.webp') ||
        url.endsWith('.gif');
  }
  String get dataUri {
    if (localAttachment != null) {
      return localAttachment!.dataUri;
    }
    return remoteUrl!;
  }
  ImageProvider get imageProvider => _imageProvider ??= _buildImageProvider();
  ImageProvider _buildImageProvider() {
    if (localAttachment != null) {
      return localAttachment!.imageProvider!;
    }
    final url = remoteUrl!;
    if (url.startsWith('data:image/') && url.contains(';base64,')) {
      final base64String = url.split(';base64,').last;
      return MemoryImage(base64.decode(base64String));
    }
    return NetworkImage(url);
  }
  IconData get icon {
    if (localAttachment != null) return localAttachment!.icon;
    return Icons.insert_drive_file_outlined;
  }
  Color get iconColor {
    if (localAttachment != null) return localAttachment!.iconColor;
    return const Color(0xFF667085);
  }
  Color get iconBg {
    if (localAttachment != null) return localAttachment!.iconBg;
    return const Color(0xFFEEF1F5);
  }
}
