import 'package:buildtrack_mobile/models/construction_models.dart';
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
  /// Phase/activity came from the caller's prefill (e.g. "Add entry" on an
  /// activity). Picking the floor then keeps them — phases aren't per-floor —
  /// so the user only has to choose the floor.
  bool _phasePrefilled = false;
  /// Which numbered pick row is expanded (0 project · 1 floor · 2 phase · 3 activity).
  int? _open;
  bool _openInit = false;
  /// Where the entry form goes after saving (see finishEntrySave).
  String _entryExit = 'dock';
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
    // Optional prefill (e.g. "Add entry" on a project's activity): projectId,
    // floor, phase, phaseId, activity, activityId. Callers that only pass
    // {'type'} keep the provider-based behaviour above.
    if (args is Map) {
      String? str(String k) {
        final v = args[k]?.toString().trim();
        return (v == null || v.isEmpty) ? null : v;
      }
      final pid = str('projectId');
      // Started from a screen (project activity) → return there after saving.
      if (pid != null) _entryExit = 'origin';
      if (pid != null) {
        if (pid != _selectedProjectId) {
          _selectedFloor = null;
          _selectedFloorId = null;
          _selectedPhase = null;
          _selectedPhaseId = null;
          _selectedActivity = null;
          _selectedActivityId = null;
        }
        _selectedProjectId = pid;
        if (args.containsKey('floor')) {
          _selectedFloor = str('floor');
          _selectedFloorId = str('floorId') ?? _selectedFloor;
        }
        if (str('phase') != null) {
          _phasePrefilled = true;
          _selectedPhase = str('phase');
          _selectedPhaseId = str('phaseId');
          _selectedActivity = null;
          _selectedActivityId = null;
        }
        if (str('activity') != null) {
          _selectedActivity = str('activity');
          _selectedActivityId = str('activityId');
        }
      }
    }
    if (_selectedProjectId != null && _selectedProjectId!.isNotEmpty) {
      provider.refreshProject(_selectedProjectId!);
    }
  }
  /// Floors are only required when the selected project has floors (same rule
  /// as [_onContinue]). Previously a floor was always required here, so the
  /// Continue button stayed disabled for projects without floors.
  bool get _projectHasFloors {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final project = provider.projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _selectedProjectId,
      orElse: () => null,
    );
    return project?.floors != null && project!.floors!.isNotEmpty;
  }
  bool get _canContinue =>
      _selectedProjectId != null &&
      _selectedProjectId!.isNotEmpty &&
      (!_projectHasFloors ||
          (_selectedFloor != null && _selectedFloor!.isNotEmpty)) &&
      _selectedPhase != null &&
      _selectedPhase!.isNotEmpty; // Activity is optional (some phases have none).
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
    });
    if (!valid) return;
    final phaseId = _selectedPhaseId ?? _derivePhaseId(_selectedPhase);
    final activityId =
        _selectedActivityId ?? _deriveActivityId(_selectedActivity);
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    if (_selectedProjectId != provider.selectedProject?.id) {
      final project = provider.projects.cast<ProjectModel?>().firstWhere(
        (p) => p?.id == _selectedProjectId,
        orElse: () => null,
      );
      if (project == null) {
        btToast(context, 'This project is not loaded yet. Go back, refresh projects and try again.', error: true);
        return;
      }
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
        'entryExit': _entryExit,
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
  // Option lists — same derivation as ExecutionContextCard (entry_widgets.dart).
  _WhereOptions _options(ProjectProvider provider) {
    final projects = provider.projects;
    final ProjectModel? selProject = _selectedProjectId == null
        ? null
        : projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == _selectedProjectId,
            orElse: () => null,
          );
    final List<String> floors = (selProject?.floors?.isNotEmpty == true)
        ? List<String>.from(selProject!.floors!)
        : <String>[];
    if (floors.isNotEmpty &&
        _selectedFloor != null &&
        _selectedFloor!.isNotEmpty &&
        !floors.contains(_selectedFloor)) {
      floors.insert(0, _selectedFloor!);
    }
    final String? selPhaseName = _selectedPhase;
    final List<String> projectPhaseNames = (selProject?.selectedPhases ??
            const <ProjectPhase>[])
        .where((p) => p.activities.isNotEmpty)
        .map((p) => p.phaseName)
        .toList();
    final List<String> legacyPhaseNames =
        List<String>.from(selProject?.selectedPhaseNames ?? const []);
    final Set<String> mergedPhaseNames = <String>{
      ...projectPhaseNames,
      ...legacyPhaseNames,
    };
    if (mergedPhaseNames.isEmpty) {
      mergedPhaseNames.addAll(buildDefaultPhases().map((p) => p.name));
    }
    final List<String> visiblePhaseNames = mergedPhaseNames.toList();
    List<String> activities;
    final ProjectPhase? selPhase = selPhaseName != null
        ? (selProject?.selectedPhases ?? const <ProjectPhase>[])
              .cast<ProjectPhase?>()
              .firstWhere(
                (p) => p?.phaseName == selPhaseName,
                orElse: () => null,
              )
        : null;
    if (selPhase != null) {
      activities = selPhase.activities.map((a) => a.name).toList();
    } else {
      final ConstructionPhase? defaultSelPhase = selPhaseName != null
          ? buildDefaultPhases().cast<ConstructionPhase?>().firstWhere(
              (p) => p?.name == selPhaseName,
              orElse: () => null,
            )
          : null;
      activities = defaultSelPhase != null
          ? defaultSelPhase.allActivities.map<String>((a) => a.name).toList()
          : <String>[];
    }
    if (selPhaseName != null && !visiblePhaseNames.contains(selPhaseName)) {
      visiblePhaseNames.insert(0, selPhaseName);
    }
    if (_selectedActivity != null && !activities.contains(_selectedActivity)) {
      activities.insert(0, _selectedActivity!);
    }
    return _WhereOptions(
      projects: projects,
      selProject: selProject,
      floors: floors,
      phases: visiblePhaseNames,
      activities: activities,
      selPhaseName: selPhaseName,
    );
  }

  // ── handlers (unchanged behaviour; called by the chips) ──
  void _onProjectChanged(String? v) {
    _phasePrefilled = false;
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
  }

  void _onFloorChanged(String? v) {
    final keep = _phasePrefilled;
    setState(() {
      _selectedFloor = v;
      _selectedFloorId = v;
      if (!keep) {
        _selectedPhase = null;
        _selectedPhaseId = null;
        _selectedActivity = null;
        _selectedActivityId = null;
      }
      _floorError = null;
    });
    final provider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    provider.selectFloor(v);
    if (keep) {
      provider.selectPhase(_selectedPhase, _selectedPhaseId);
      provider.selectActivity(_selectedActivity, _selectedActivityId);
    }
  }

  void _onPhaseChanged(dynamic v) {
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
  }

  void _onActivityChanged(String? v) {
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
  }

  /// After a pick, open the next row that still needs an answer.
  void _advance(int from, _WhereOptions o) {
    int? next;
    for (var i = from + 1; i < 4; i++) {
      final enabled = _rowEnabled(i, o);
      if (enabled && !_rowDone(i, o)) {
        next = i;
        break;
      }
    }
    setState(() => _open = next);
  }

  bool _rowEnabled(int i, _WhereOptions o) {
    switch (i) {
      case 0:
        return true;
      case 1:
        return _selectedProjectId != null && o.floors.isNotEmpty;
      case 2:
        return (o.floors.isEmpty || _selectedFloor != null) && o.phases.isNotEmpty;
      default:
        return o.selPhaseName != null && o.activities.isNotEmpty;
    }
  }

  bool _rowDone(int i, _WhereOptions o) {
    switch (i) {
      case 0:
        return o.selProject != null;
      case 1:
        return o.floors.isNotEmpty && _selectedFloor != null && _selectedFloor!.isNotEmpty;
      case 2:
        return o.phases.contains(o.selPhaseName);
      default:
        return o.activities.contains(_selectedActivity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final o = _options(provider);
    if (!_openInit) {
      _openInit = true;
      for (var i = 0; i < 4; i++) {
        if (_rowEnabled(i, o) && !_rowDone(i, o)) {
          _open = i;
          break;
        }
      }
    }

    // Values shown in each row (null → placeholder/hint, same hints as before).
    final projectValue = o.selProject?.name;
    final floorValue = o.floors.isEmpty ? null : _selectedFloor;
    final floorHint = o.floors.isEmpty
        ? (_selectedProjectId == null ? 'Select project first' : 'No floors in this project')
        : (_selectedProjectId == null ? 'Select project first' : 'Select floor');
    final phaseValue = o.phases.contains(o.selPhaseName) ? o.selPhaseName : null;
    final phaseHint = (o.floors.isNotEmpty && _selectedFloor == null)
        ? 'Select floor first'
        : o.phases.isEmpty
            ? 'No phases configured for this project'
            : 'Select phase';
    final activityValue = o.activities.contains(_selectedActivity) ? _selectedActivity : null;
    final activityHint = o.selPhaseName == null
        ? 'Select phase first'
        : o.activities.isEmpty
            ? 'No activities in this phase'
            : 'Select activity';

    final rows = <Widget>[
      _PickRow(
        number: 1,
        label: 'Project',
        value: projectValue,
        hint: o.projects.isEmpty ? 'No projects available' : 'Select project',
        open: _open == 0,
        done: _rowDone(0, o),
        enabled: o.projects.isNotEmpty,
        error: _projectError,
        onToggle: () => setState(() => _open = _open == 0 ? null : 0),
        options: [
          for (final p in o.projects)
            _Opt(p.name, p.id == _selectedProjectId, () {
              if (p.id != _selectedProjectId) _onProjectChanged(p.id);
              _advance(0, _options(provider));
            }),
        ],
      ),
      _PickRow(
        number: 2,
        label: 'Floor / Zone',
        // Required whenever the project has floors (same rule as _onContinue).
        optional: o.floors.isEmpty,
        value: floorValue,
        hint: floorHint,
        open: _open == 1,
        done: _rowDone(1, o),
        enabled: _rowEnabled(1, o),
        error: o.floors.isEmpty ? null : _floorError,
        onToggle: () => setState(() => _open = _open == 1 ? null : 1),
        options: [
          for (final f in o.floors)
            _Opt(f, f == _selectedFloor, () {
              if (f != _selectedFloor) _onFloorChanged(f);
              _advance(1, _options(provider));
            }),
        ],
      ),
      _PickRow(
        number: 3,
        label: 'Phase',
        value: phaseValue,
        hint: phaseHint,
        open: _open == 2,
        done: _rowDone(2, o),
        enabled: _rowEnabled(2, o),
        error: _phaseError,
        onToggle: () => setState(() => _open = _open == 2 ? null : 2),
        options: [
          for (final n in o.phases)
            _Opt(n, n == o.selPhaseName, () {
              if (n != o.selPhaseName) _onPhaseChanged(n);
              _advance(2, _options(provider));
            }),
        ],
      ),
      _PickRow(
        number: 4,
        label: 'Activity',
        optional: true,
        value: activityValue,
        hint: activityHint,
        open: _open == 3,
        done: _rowDone(3, o),
        enabled: _rowEnabled(3, o),
        error: _activityError,
        onToggle: () => setState(() => _open = _open == 3 ? null : 3),
        options: [
          for (final a in o.activities)
            _Opt(a, a == _selectedActivity, () {
              if (a != _selectedActivity) _onActivityChanged(a);
              setState(() => _open = null);
            }),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(title: '$_entryTypeLabel entry', subtitle: 'Step 2 of 3'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(Bt.gutter, 6, Bt.gutter, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _StepBar(step: 2),
                    const SizedBox(height: 20),
                    BtReveal(child: Text('Where is this\nhappening?', style: BtText.d2(context))),
                    const SizedBox(height: 6),
                    BtReveal(
                      index: 1,
                      child: Text('Select the project context once — it applies to both voice and manual entry.', style: BtText.subhead(context)),
                    ),
                    const SizedBox(height: 20),
                    BtReveal(
                      index: 2,
                      child: BtCard(
                        padding: EdgeInsets.zero,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0) const Padding(padding: EdgeInsets.only(left: 16), child: Divider(height: 1, thickness: 1, color: Bt.line)),
                            rows[i],
                          ],
                        ]),
                      ),
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

  Widget _buildBottomBar() {
    return BtCtaBar(vertical: true, children: [
      AnimatedSize(
        duration: Bt.fast,
        curve: Bt.ease,
        child: _canContinue
            ? Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded, color: Bt.green, size: 16),
                  const SizedBox(width: 6),
                  Text('Context selected — ready to continue', style: BtText.caption(context, color: Bt.green, weight: FontWeight.w600)),
                ]),
              )
            : const SizedBox(width: double.infinity),
      ),
      BtButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: _canContinue ? _onContinue : null),
    ]);
  }
}

class _WhereOptions {
  const _WhereOptions({required this.projects, required this.selProject, required this.floors, required this.phases, required this.activities, required this.selPhaseName});
  final List<ProjectModel> projects;
  final ProjectModel? selProject;
  final List<String> floors;
  final List<String> phases;
  final List<String> activities;
  final String? selPhaseName;
}

class _Opt {
  const _Opt(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Numbered pick row (Where-Picker board): `01 · PROJECT · value ✓`; tapping
/// opens a tinted chip tray with the options.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.number,
    required this.label,
    required this.value,
    required this.hint,
    required this.open,
    required this.done,
    required this.enabled,
    required this.onToggle,
    required this.options,
    this.error,
    this.optional = false,
  });
  final int number;
  final String label;
  final String? value;
  final String hint;
  final bool open;
  final bool done;
  final bool enabled;
  final bool optional;
  final String? error;
  final VoidCallback onToggle;
  final List<_Opt> options;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final hasError = error != null;
    final showOpen = open && enabled;
    final tint = bt.accent.withValues(alpha: .08);
    final numColor = hasError ? Bt.red : showOpen ? bt.accentInk : done ? Bt.green : Bt.ink3;
    final labelColor = hasError ? Bt.red : showOpen ? bt.accentInk : Bt.ink3;
    return AnimatedContainer(
      duration: Bt.fast,
      curve: Bt.ease,
      color: showOpen ? tint : Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: enabled,
          label: '$label: ${value ?? hint}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onToggle : null,
            child: Opacity(
              opacity: enabled || done ? 1 : .5,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: Row(children: [
                    SizedBox(
                      width: 26,
                      child: Text(number.toString().padLeft(2, '0'), style: BtText.mono(context, color: numColor, size: 11)),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(optional ? '${label.toUpperCase()} · OPTIONAL' : label.toUpperCase(), style: BtText.mono(context, color: labelColor)),
                        const SizedBox(height: 3),
                        AnimatedSwitcher(
                          duration: Bt.fast,
                          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                          child: Text(
                            value ?? (showOpen ? 'Pick one' : hint),
                            key: ValueKey(value ?? hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BtText.body(context, weight: value != null ? FontWeight.w600 : FontWeight.w400, color: value != null ? Bt.ink : Bt.ink2),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: Bt.fast,
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: done && !showOpen
                          ? const Icon(Icons.check_rounded, key: ValueKey('done'), size: 20, color: Bt.green)
                          : AnimatedRotation(
                              key: const ValueKey('chev'),
                              turns: showOpen ? .5 : 0,
                              duration: Bt.fast,
                              child: Icon(Icons.expand_more_rounded, size: 22, color: enabled ? Bt.ink3 : Bt.placeholder),
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Bt.medium,
          curve: Bt.ease,
          alignment: Alignment.topCenter,
          child: showOpen && options.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(42, 0, 16, 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < options.length; i++)
                      i < 8
                          ? BtReveal(index: i, distance: 8, duration: const Duration(milliseconds: 420), child: BtChip(label: options[i].label, selected: options[i].selected, onTap: options[i].onTap))
                          : BtChip(label: options[i].label, selected: options[i].selected, onTap: options[i].onTap),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 0, 16, 12),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: Bt.red),
              const SizedBox(width: 4),
              Expanded(child: Text(error!, style: BtText.caption(context, color: Bt.red))),
            ]),
          ),
      ]),
    );
  }
}

/// Three-segment progress: Type ✓ · Where · How (shared look with the
/// choose-entry-mode screen).
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
