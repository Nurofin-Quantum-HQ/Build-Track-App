import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
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
  static const primaryBlue = AppColors.primary;
  static const bgColor = AppColors.gradientStart;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
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
    _selectedProjectId = UserSession.projectId;
    final provider = context.read<ProjectProvider>();
    _completionProgress = provider.selectedProject?.progress ?? 0.0;
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
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
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
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            await TaskService.updateTask(task.id, {
                              'title': titleCtrl.text,
                              'description': descCtrl.text,
                            });
                            if (updatedStatus != null && updatedStatus != task.status) {
                              await TaskService.updateTaskStatus(task.id, updatedStatus!);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            onSave();
                          } catch (e) {
                            setDialogState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      final matchedAct = project.selectedPhases
          ?.expand((ph) => ph.activities)
          .cast<ProjectActivity?>()
          .firstWhere(
            (act) =>
                (_prefillActivityId != null && act?.id == _prefillActivityId) ||
                (_selectedActivityName != null &&
                    act?.name == _selectedActivityName),
            orElse: () => null,
          );
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
        _completedTaskIds.add(task.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final provider = context.read<ProjectProvider>();
          final project = provider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == task.project,
            orElse: () => null,
          );
          if (project != null) {
            setState(() {
              _completionProgress = project.progress;
              _loadActivityDetails();
            });
          }
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
        if (floor != null && floor.isNotEmpty) {
          _selectedFloor = floor;
        } else if (floors != null && floors.isNotEmpty) {
          _selectedFloor = floors.first;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final provider = context.read<ProjectProvider>();
          final project = provider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == projectId,
            orElse: () => null,
          );
          if (project != null) {
            setState(() {
              _completionProgress = project.progress;
              _loadActivityDetails();
            });
          }
        });
      }
    }
  }
  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
  List<String> _phasesFor(ProjectModel? project) {
    if (project == null) return [];
    if (project.selectedPhaseNames != null &&
        project.selectedPhaseNames!.isNotEmpty) {
      return project.selectedPhaseNames!;
    }
    return _catalogue.map((p) => p.name).toList();
  }
  List<String> _activitiesFor(String? phaseName) {
    if (phaseName == null) return [];
    final match = _catalogue.cast<ConstructionPhase?>().firstWhere(
      (p) => p?.name == phaseName,
      orElse: () => null,
    );
    if (match == null) return [];
    return match.allActivities.map((a) => a.name).toList();
  }
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: primaryBlue,
        letterSpacing: 0.4,
      ),
    ),
  );
  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: textDark,
        letterSpacing: -0.2,
      ),
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
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? (safe != null ? primaryBlue : const Color(0xFFE0E5FF))
                : const Color(0xFFE0E5FF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: safe,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? primaryBlue : textGray,
              size: 22,
            ),
            hint: Text(
              hint,
              style: const TextStyle(
                color: textGray,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            items: enabled ? items : <DropdownMenuItem<T>>[],
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: _launchedFromTracker
                  ? 'Progress Update'
                  : 'Update Progress',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Consumer<ProjectProvider>(
                builder: (context, provider, _) {
                  final projects = provider.projects;
                  final selProject = _selectedProjectId == null
                      ? null
                      : projects.cast<ProjectModel?>().firstWhere(
                          (p) => p?.id == _selectedProjectId,
                          orElse: () => null,
                        );
                  final floors = (selProject?.floors?.isNotEmpty ?? false)
                      ? List<String>.from(selProject!.floors!)
                      : [
                          'Basement',
                          'Ground Floor',
                          '1st Floor',
                          '2nd Floor',
                          'Terrace',
                        ];
                  if (_selectedFloor != null &&
                      !floors.contains(_selectedFloor)) {
                    floors.add(_selectedFloor!);
                  }
                  final phaseNames = _phasesFor(selProject);
                  final activityNames = _activitiesFor(_selectedPhaseName);
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_launchedFromTracker) ...[
                          _buildTrackerContextBanner(),
                          const SizedBox(height: 16),
                        ],
                        _buildContextCard(
                          projects: projects,
                          floors: floors,
                          phaseNames: phaseNames,
                          activityNames: activityNames,
                        ),
                        const SizedBox(height: 20),
                        if (_selectedPhaseName != null &&
                            _selectedFloor != null) ...[
                          _buildStageSummaryCard(),
                          const SizedBox(height: 20),
                        ],
                        _buildTaskChecklist(),
                        const SizedBox(height: 20),
                        _buildExecutionNotes(),
                        const SizedBox(height: 20),
                        _buildDateField(),
                        const SizedBox(height: 20),
                        _buildPhotoUpload(),
                        const SizedBox(height: 20),
                        _buildMaterialConsumption(context, provider),
                        const SizedBox(height: 32),
                        _buildSaveButton(context, provider),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildTrackerContextBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryBlue.withValues(alpha: 0.20),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.checklist_rounded,
              color: primaryBlue,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activity Progress Update',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedPhaseName ?? ""} › ${_selectedActivityName ?? ""}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textGray,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildContextCard({
    required List<ProjectModel> projects,
    required List<String> floors,
    required List<String> phaseNames,
    required List<String> activityNames,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: primaryBlue,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'EXECUTION CONTEXT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textGray,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Project'),
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
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedProjectId = val;
                    _selectedFloor = null;
                    _selectedPhaseName = null;
                    _selectedActivityName = null;
                    final p = projects.cast<ProjectModel?>().firstWhere(
                      (x) => x?.id == val,
                      orElse: () => null,
                    );
                    _completionProgress = p?.progress ?? 0.0;
                  }),
                ),
          const SizedBox(height: 16),
          _sectionLabel('Floor / Zone'),
          _dropdownCard<String>(
            value: _selectedFloor,
            hint: _selectedProjectId == null
                ? 'Select project first'
                : 'Select floor or zone',
            enabled: _selectedProjectId != null,
            items: floors
                .map((f) => DropdownMenuItem<String>(value: f, child: Text(f)))
                .toList(),
            onChanged: _selectedProjectId == null
                ? null
                : (val) => setState(() {
                    _selectedFloor = val;
                    if (!_launchedFromTracker) {
                      _selectedPhaseName = null;
                      _selectedActivityName = null;
                    }
                  }),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Phase'),
          _launchedFromTracker
              ? _lockedField(_selectedPhaseName ?? 'Phase')
              : _dropdownCard<String>(
                  value: _selectedPhaseName,
                  hint: _selectedFloor == null
                      ? 'Select floor first'
                      : 'Select phase',
                  enabled: _selectedFloor != null,
                  items: phaseNames
                      .map(
                        (n) =>
                            DropdownMenuItem<String>(value: n, child: Text(n)),
                      )
                      .toList(),
                  onChanged: _selectedFloor == null
                      ? null
                      : (val) => setState(() {
                          _selectedPhaseName = val;
                          _selectedActivityName = null;
                        }),
                ),
          const SizedBox(height: 16),
          _sectionLabel('Activity'),
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
                                child: Text(a),
                              ),
                            )
                            .toList(),
                  onChanged:
                      (_selectedPhaseName == null || activityNames.isEmpty)
                      ? null
                      : (val) => setState(() => _selectedActivityName = val),
                ),
        ],
      ),
    );
  }
  Widget _lockedField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryBlue.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 14, color: textGray),
        ],
      ),
    );
  }
  Widget _buildStageSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF0FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACTIVE EXECUTION CONTEXT',
              style: TextStyle(
                color: primaryBlue,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedPhaseName ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textDark,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          if (_selectedActivityName != null) ...[
            const SizedBox(height: 4),
            Text(
              _selectedActivityName!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: textGray, size: 13),
              const SizedBox(width: 4),
              Text(
                _selectedFloor ?? '',
                style: const TextStyle(
                  color: textGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OVERALL COMPLETION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textGray,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                '${(_completionProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 7,
              activeTrackColor: primaryBlue,
              inactiveTrackColor: const Color(0xFFE8ECF8),
              thumbColor: primaryBlue,
              overlayColor: primaryBlue.withValues(alpha: 0.10),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _completionProgress,
              onChanged: (v) => setState(() => _completionProgress = v),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTaskChecklist() {
    if (_isLoadingTasks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: primaryBlue)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Assigned Tasks'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E5FF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: relevantTasks.map((task) {
              final isCompleted = _completedTaskIds.contains(task.id);
              return CheckboxListTile(
                value: isCompleted,
                secondary: task.status != 'Completed'
                    ? IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditTaskDialog(context, task, () {
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isCompleted ? textGray : textDark,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: task.description.isNotEmpty
                    ? Text(
                        task.description,
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
                activeColor: primaryBlue,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  Widget _buildExecutionNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Execution Notes'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E5FF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
              ),
            ],
          ),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'What work was completed today?',
              hintStyle: TextStyle(color: textGray, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
            style: const TextStyle(fontSize: 14, color: textDark, height: 1.5),
          ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Update Date'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: primaryBlue,
                          onPrimary: Colors.white,
                          onSurface: textDark,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE0E5FF),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: primaryBlue,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          updateDateStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Completion Date'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _completionDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: primaryBlue,
                          onPrimary: Colors.white,
                          onSurface: textDark,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _completionDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE0E5FF),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available,
                        color: primaryBlue,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          completionDateStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _completionDate != null
                                ? textDark
                                : textGray,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Progress Photos'),
        if (_attachments.isEmpty)
          GestureDetector(
            onTap: () async {
              final result = await pickAttachmentDirect(context);
              if (result != null) {
                setState(() {
                  _attachments.add(PhotoAttachment.local(result));
                });
              }
            },
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCCCFE8), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to add site photos (Up to 4)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1D3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PNG, JPG, JPEG',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A90A8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final att = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEEF0FF),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: att.isImage
                            ? Image(
                                image: att.imageProvider,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: att.iconBg,
                                child: Center(
                                  child: Icon(
                                    att.icon,
                                    color: att.iconColor,
                                    size: 28,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _attachments.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_attachments.length < 4)
                GestureDetector(
                  onTap: () async {
                    final result = await pickAttachmentDirect(context);
                    if (result != null) {
                      setState(() {
                        _attachments.add(PhotoAttachment.local(result));
                      });
                    }
                  },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCCCFE8),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: primaryBlue,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
  Widget _buildMaterialConsumption(
    BuildContext context,
    ProjectProvider provider,
  ) {
    List<EntryModel> materials = [];
    if (_selectedProjectId != null && _selectedFloor != null) {
      materials = provider.entries
          .where(
            (e) =>
                e.type == EntryType.material &&
                e.projectId == _selectedProjectId &&
                e.floor == _selectedFloor,
          )
          .toList();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MATERIAL CONSUMPTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textGray,
                  letterSpacing: 0.7,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/add-material',
                  arguments: {'type': 'material'},
                ),
                child: const Text(
                  'ADD MATERIAL',
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No materials logged for this location yet.',
                style: TextStyle(
                  color: textGray,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            )
          else
            ...materials.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _materialTag(m.description, m.amount.toString()),
              ),
            ),
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
          decoration: const BoxDecoration(
            color: primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: textDark,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0FF),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            qty,
            style: const TextStyle(
              color: primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
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
    return GestureDetector(
      onTap: () async {
        final project =
            provider.selectedProject ??
            provider.projects.cast<ProjectModel?>().firstWhere(
              (p) => p?.id == _selectedProjectId,
              orElse: () => null,
            );
        String? targetActivityId = _prefillActivityId;
        if (targetActivityId == null &&
            _selectedActivityName != null &&
            project != null) {
          final matchedAct = project.selectedPhases
              ?.expand((ph) => ph.activities)
              .cast<ProjectActivity?>()
              .firstWhere(
                (act) => act?.name == _selectedActivityName,
                orElse: () => null,
              );
          if (matchedAct != null) {
            targetActivityId = matchedAct.id;
          }
        }
        final targetProjectId = _selectedProjectId ?? project?.id;
        bool success = false;
        if (_prefillActivityId != null) {
          await provider.markActivityComplete(
            _selectedProjectId!,
            _prefillActivityId!,
            _selectedDate,
          );
        }
        for (final taskId in _completedTaskIds) {
          try {
            await TaskService.updateTaskStatus(taskId, 'Completed');
          } catch (e) {
            debugPrint('Failed to complete task $taskId: $e');
          }
        }
        if (!mounted) return;
        if (targetProjectId != null && targetActivityId != null) {
          success = await provider.toggleActivityCompletion(
            targetProjectId,
            targetActivityId,
            completedAt: _completionDate ?? _selectedDate,
            notes: _notesCtrl.text.trim().isNotEmpty
                ? _notesCtrl.text.trim()
                : null,
            photo: _attachments.isNotEmpty ? _attachments.first.dataUri : null,
            photos: _attachments.map((a) => a.dataUri).toList(),
            manualProgress: _completionProgress,
          );
        } else if (targetProjectId != null) {
          success = await provider.updateProjectProgress(
            targetProjectId,
            _completionProgress,
          );
        }
        if (context.mounted) {
          if (success) {
            final months = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ];
            final dateLabel =
                '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _launchedFromTracker && _selectedActivityName != null
                            ? '${_selectedActivityName!} marked done · $dateLabel'
                            : 'Progress updated · $dateLabel',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.maybePop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Failed to save progress details. Please check network connection and try again.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _launchedFromTracker
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class PhotoAttachment {
  final PickedAttachment? localAttachment;
  final String? remoteUrl;
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
  ImageProvider get imageProvider {
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
    return const Color(0xFF6B7280);
  }
  Color get iconBg {
    if (localAttachment != null) return localAttachment!.iconBg;
    return const Color(0xFFF3F4F6);
  }
}
