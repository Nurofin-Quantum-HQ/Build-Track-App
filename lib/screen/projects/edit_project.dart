import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/screen/reports/save_helper_stub.dart'
    if (dart.library.html) 'package:buildtrack_mobile/screen/reports/save_helper_web.dart'
    if (dart.library.io) 'package:buildtrack_mobile/screen/reports/save_helper_mobile.dart';
class EditProjectScreen extends StatefulWidget {
  const EditProjectScreen({super.key, required this.project});
  final ProjectModel project;
  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}
class _EditProjectScreenState extends State<EditProjectScreen> {
  static const primaryBlue = Bt.ink;
  static const textDark = Bt.ink;
  static const textGray = Bt.ink2;
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _mapAddressCtrl;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _contractorCtrl;
  late final TextEditingController _engineerCtrl;
  late final TextEditingController _landAreaCtrl;
  late final TextEditingController _budgetMaterialCtrl;
  late final TextEditingController _budgetLabourCtrl;
  late final TextEditingController _budgetEquipmentCtrl;
  late final TextEditingController _budgetMiscCtrl;
  late final TextEditingController _customSubTypeCtrl;
  final _customStageNameCtrl = TextEditingController();
  late DateTime _startDate;
  DateTime? _expectedEndDate;
  late String _projectStatus;
  late String _landUnit;
  String? _mainBuildingType;
  String? _buildingSubType;
  bool _isCustomSubType = false;
  String? _buildingTypeError;
  late List<String> _selectedFloorChips;
  late int _room1BHKCount, _room2BHKCount, _room3BHKCount, _roomCustomCount;
  late int _bathWesternCount,
      _bathIndianCount,
      _bathCommonCount,
      _bathAttachedCount;
  late Set<String> _additionalConfigs;
  late ProjectModel _currentProject;
  late List<ConstructionPhase> _phases;
  Map<String, ProjectActivity> _existingActivityById = {};
  bool _saving = false;
  bool _loading = true;
  bool _addlExpanded = true;
  static const Map<String, List<String>> _buildingSubTypes = {
    'Residential': [
      '1 BHK',
      '2 BHK',
      '3 BHK',
      'Villa',
      'Apartment',
      'Other (Custom)',
    ],
    'Educational': ['School', 'College', 'Other (Custom)'],
    'Institutional': [
      'Church',
      'Presbytery',
      'Convention Hall',
      'Other (Custom)',
    ],
    'Commercial': ['Shop', 'Office', 'Complex', 'Plaza', 'Other (Custom)'],
    'Industrial': ['Factory', 'Warehouse', 'Other (Custom)'],
  };
  final List<String> _statusOptions = [
    'Planning',
    'In Progress',
    'On Hold',
    'Completed',
    'Cancelled',
  ];
  final List<String> _floorChipOptions = [
    'Ground',
    '1st',
    '2nd',
    '3rd',
    '4th',
    'Terrace',
    'Head Room',
  ];
  static const _kAddlConfigEdit = [
    'Balcony',
    'Car Parking',
    'Lift',
    'Terrace Access',
    'Interior Work',
    'Compound Wall',
    'Parapet Wall',
    'Waterproofing',
    'Putty',
    'False Ceiling',
    'Modular Kitchen',
    'Wardrobes',
    'Sump',
    'Septic Tank',
    'Rainwater',
    'Borewell',
    'Solar',
    'Generator',
    'CCTV',
    'Intercom',
    'Landscaping',
    'Paving',
    'Water Tanks',
    'Stairs',
    'Security Room',
    'Cladding',
    'Elevation',
    'Gates',
    'Grills',
    'Aluminium',
    'Glass',
  ];
  static const _kUtilityEdit = [
    'Main Electricity',
    'Temporary Connection',
    'Generator Backup',
    'Water Connection',
    'Borewell Motor',
    'Sump Motor',
  ];
  static const _kGasEdit = [
    'Piped Gas',
    'Cylinder Bank',
    'Gas Pipeline Routing',
  ];
  static const _kKitchenEdit = [
    'Granite Counter',
    'Quartz Counter',
    'Stainless Steel Sink',
    'Chimney Provision',
    'Exhaust Fan Provision',
  ];
  static const _kElectricalEdit = [
    'Concealed Wiring',
    'Open Wiring',
    '3-Phase Connection',
    'AC Points',
    'Geyser Points',
  ];
  static const _kTerraceEdit = [
    'Weathering Course',
    'Cool Roof Paint',
    'Overhead Tank',
    'Solar Panels',
  ];
  String _normalizeFloor(String f) {
    final lower = f.trim().toLowerCase();
    const shortLabels = [
      'Ground',
      '1st',
      '2nd',
      '3rd',
      '4th',
      'Terrace',
      'Head Room',
    ];
    for (final label in shortLabels) {
      if (f.trim() == label) return label;
    }
    if (lower.contains('ground')) return 'Ground';
    if (lower.startsWith('1') ||
        lower.contains('first') ||
        lower == '1st floor') {
      return '1st';
    }
    if (lower.startsWith('2') ||
        lower.contains('second') ||
        lower == '2nd floor') {
      return '2nd';
    }
    if (lower.startsWith('3') ||
        lower.contains('third') ||
        lower == '3rd floor') {
      return '3rd';
    }
    if (lower.startsWith('4') ||
        lower.contains('fourth') ||
        lower == '4th floor') {
      return '4th';
    }
    if (lower.contains('terrace')) return 'Terrace';
    if (lower.contains('head') || lower.contains('room')) return 'Head Room';
    return f.trim();
  }
  String _resolveStatus(String? raw) {
    if (raw == null || raw.isEmpty) return 'Planning';
    final lower = raw
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '');
    if (lower == 'active') return 'In Progress';
    if (lower == 'onhold') return 'On Hold';
    if (lower == 'completed') return 'Completed';
    if (lower == 'reviewneeded') return 'On Hold';
    if (lower == 'planning') return 'Planning';
    if (lower == 'inprogress') return 'In Progress';
    if (lower == 'cancelled') return 'Cancelled';
    if (lower.contains('progress') || lower.contains('active')) {
      return 'In Progress';
    }
    if (lower.contains('hold')) return 'On Hold';
    if (lower.contains('complet')) return 'Completed';
    if (lower.contains('cancel')) return 'Cancelled';
    if (lower.contains('plan')) return 'Planning';
    for (final opt in [
      'Planning',
      'In Progress',
      'On Hold',
      'Completed',
      'Cancelled',
    ]) {
      if (opt == raw.trim()) return opt;
    }
    return 'Planning';
  }
  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _mapAddressCtrl = TextEditingController();
    _clientCtrl = TextEditingController();
    _contactCtrl = TextEditingController();
    _contractorCtrl = TextEditingController();
    _engineerCtrl = TextEditingController();
    _landAreaCtrl = TextEditingController();
    _budgetMaterialCtrl = TextEditingController();
    _budgetLabourCtrl = TextEditingController();
    _budgetEquipmentCtrl = TextEditingController();
    _budgetMiscCtrl = TextEditingController();
    _customSubTypeCtrl = TextEditingController();
    _startDate = DateTime.now();
    _selectedFloorChips = [];
    _room1BHKCount = 0;
    _room2BHKCount = 0;
    _room3BHKCount = 0;
    _roomCustomCount = 0;
    _bathWesternCount = 0;
    _bathIndianCount = 0;
    _bathCommonCount = 0;
    _bathAttachedCount = 0;
    _additionalConfigs = {};
    _projectStatus = 'Planning';
    _landUnit = 'Sq ft';
    _currentProject = widget.project;
    _phases = buildDefaultPhases();
    _populateFrom(widget.project);
    _fetchFreshAndPopulate();
  }
  void _populateFrom(ProjectModel p) {
    _currentProject = p;
    _nameCtrl.text = p.name;
    _cityCtrl.text = p.city.isNotEmpty
        ? p.city
        : (p.location.isNotEmpty ? p.location : '');
    _mapAddressCtrl.text = p.mapAddress ?? '';
    _clientCtrl.text = p.clientName ?? '';
    _contactCtrl.text = p.contactNumber ?? '';
    _contractorCtrl.text = p.contractorName ?? '';
    _engineerCtrl.text = p.siteEngineer ?? '';
    _landAreaCtrl.text = p.landArea ?? '';
    _budgetMaterialCtrl.text = p.budgetMaterial != null && p.budgetMaterial! > 0
        ? p.budgetMaterial!.toStringAsFixed(0)
        : '';
    _budgetLabourCtrl.text = p.budgetLabour != null && p.budgetLabour! > 0
        ? p.budgetLabour!.toStringAsFixed(0)
        : '';
    _budgetEquipmentCtrl.text =
        p.budgetEquipment != null && p.budgetEquipment! > 0
        ? p.budgetEquipment!.toStringAsFixed(0)
        : '';
    _budgetMiscCtrl.text = p.budgetMisc != null && p.budgetMisc! > 0
        ? p.budgetMisc!.toStringAsFixed(0)
        : '';
    _startDate = p.startDate;
    _expectedEndDate = p.expectedEndDate;
    _projectStatus = _resolveStatus(p.projectStatus);
    _landUnit = p.landUnit ?? 'Sq ft';
    const landUnits = ['Sq ft', 'Sq m', 'Acres', 'Hectares'];
    if (!landUnits.contains(_landUnit)) _landUnit = 'Sq ft';
    _mainBuildingType = null;
    _buildingSubType = null;
    _isCustomSubType = false;
    _customSubTypeCtrl.clear();
    if (p.projectType != null && p.projectType!.isNotEmpty) {
      String raw = p.projectType!;
      if (raw.contains('Business / Commercial')) {
        raw = raw.replaceFirst('Business / Commercial', 'Commercial');
      } else if (raw.contains('Business/Commercial')) {
        raw = raw.replaceFirst('Business/Commercial', 'Commercial');
      }
      final sepIndex = raw.contains('→')
          ? raw.indexOf('→')
          : raw.contains('/')
          ? raw.indexOf('/')
          : -1;
      if (sepIndex != -1) {
        final mainPart = raw.substring(0, sepIndex).trim();
        final subPart = raw.substring(sepIndex + 1).trim();
        if (_buildingSubTypes.containsKey(mainPart)) {
          _mainBuildingType = mainPart;
          if (subPart.isNotEmpty && subPart != 'General') {
            final knownSubs = _buildingSubTypes[mainPart] ?? [];
            if (knownSubs.contains(subPart)) {
              _buildingSubType = subPart;
              _isCustomSubType = false;
            } else {
              _isCustomSubType = true;
              _customSubTypeCtrl.text = subPart;
            }
          }
        }
      } else {
        if (_buildingSubTypes.containsKey(raw.trim())) {
          _mainBuildingType = raw.trim();
        }
      }
    }
    // Keep the project's own floor names ("First", "Roof"…): renaming or
    // dropping a floor on save detaches every entry recorded on it. A preset chip
    // that means the same floor shows the project's name instead.
    final rawFloors = p.floors ?? [];
    _selectedFloorChips = [];
    for (final f in rawFloors) {
      final orig = f.trim();
      if (orig.isEmpty || _selectedFloorChips.contains(orig)) continue;
      final i = _floorChipOptions.indexOf(_normalizeFloor(orig));
      if (i != -1) {
        _floorChipOptions[i] = orig;
      } else if (!_floorChipOptions.contains(orig)) {
        _floorChipOptions.add(orig);
      }
      _selectedFloorChips.add(orig);
    }
    _room1BHKCount = p.room1BHK ?? 0;
    _room2BHKCount = p.room2BHK ?? 0;
    _room3BHKCount = p.room3BHK ?? 0;
    _roomCustomCount = p.roomCustom ?? 0;
    _bathWesternCount = p.bathWestern ?? 0;
    _bathIndianCount = p.bathIndian ?? 0;
    _bathCommonCount = p.bathCommon ?? 0;
    _bathAttachedCount = p.bathAttached ?? 0;
    _additionalConfigs = Set<String>.from(p.selectedFeatures ?? []);
    _existingActivityById = {};
    final existingPhaseNames = <String>{};
    for (final ph in p.selectedPhases ?? <ProjectPhase>[]) {
      existingPhaseNames.add(ph.phaseName);
      for (final act in ph.activities) {
        if (act.id.isNotEmpty) {
          _existingActivityById[act.id] = act;
        }
        final matchKey =
            '${ph.phaseName.trim().toLowerCase()}::${act.name.trim().toLowerCase()}';
        _existingActivityById[matchKey] = act;
      }
    }
    final freshPhases = buildDefaultPhases();
    for (final phase in freshPhases) {
      bool phaseHasSelection = false;
      for (final act in phase.allActivities) {
        final matchKey =
            '${phase.name.trim().toLowerCase()}::${act.name.trim().toLowerCase()}';
        if (_existingActivityById.containsKey(act.key) ||
            _existingActivityById.containsKey(matchKey)) {
          act.isSelected = true;
          phaseHasSelection = true;
          final prev =
              _existingActivityById[act.key] ?? _existingActivityById[matchKey];
          act.budgetMaterial = prev?.budgetMaterial;
          act.budgetLabour = prev?.budgetLabour;
          act.budgetEquipment = prev?.budgetEquipment;
          act.qty = prev?.qty;
          act.unit = prev?.unit;
          act.materialRate = prev?.materialRate;
          act.materialAmount = prev?.materialAmount;
          act.labourRate = prev?.labourRate;
          act.labourAmount = prev?.labourAmount;
          act.equipmentRate = prev?.equipmentRate;
          act.equipmentAmount = prev?.equipmentAmount;
        }
      }
      if (phaseHasSelection || existingPhaseNames.contains(phase.name)) {
        phase.isSelected = true;
        phase.isExpanded = true;
      }
    }
    for (final ph in p.selectedPhases ?? <ProjectPhase>[]) {
      final idx = freshPhases.indexWhere((cp) => cp.name == ph.phaseName);
      if (idx == -1) {
        final customPhase = ConstructionPhase(
          name: ph.phaseName,
          isCustom: true,
        );
        customPhase.isSelected = true;
        customPhase.isExpanded = true;
        for (final act in ph.activities) {
          final customAct = ConstructionActivity(
            key:
                '${ph.phaseName.trim().toLowerCase()}::${act.name.trim().toLowerCase()}',
            name: act.name,
            isCustom: true,
            budgetMaterial: act.budgetMaterial,
            budgetLabour: act.budgetLabour,
            budgetEquipment: act.budgetEquipment,
            qty: act.qty,
            unit: act.unit,
            materialRate: act.materialRate,
            materialAmount: act.materialAmount,
            labourRate: act.labourRate,
            labourAmount: act.labourAmount,
            equipmentRate: act.equipmentRate,
            equipmentAmount: act.equipmentAmount,
          );
          customAct.isSelected = true;
          customPhase.activities.add(customAct);
        }
        freshPhases.add(customPhase);
      } else {
        final matchPhase = freshPhases[idx];
        for (final act in ph.activities) {
          final alreadyThere = matchPhase.allActivities.any(
            (a) => a.name.trim().toLowerCase() == act.name.trim().toLowerCase(),
          );
          if (!alreadyThere) {
            final customAct = ConstructionActivity(
              key:
                  '${matchPhase.name.trim().toLowerCase()}::${act.name.trim().toLowerCase()}',
              name: act.name,
              isCustom: true,
              budgetMaterial: act.budgetMaterial,
              budgetLabour: act.budgetLabour,
              budgetEquipment: act.budgetEquipment,
              qty: act.qty,
              unit: act.unit,
              materialRate: act.materialRate,
              materialAmount: act.materialAmount,
              labourRate: act.labourRate,
              labourAmount: act.labourAmount,
              equipmentRate: act.equipmentRate,
              equipmentAmount: act.equipmentAmount,
            );
            customAct.isSelected = true;
            matchPhase.activities.add(customAct);
          }
        }
      }
    }
    for (final name in p.selectedPhaseNames ?? const <String>[]) {
      final nameKey = name.trim().toLowerCase();
      final alreadyRestored =
          freshPhases.any((cp) => cp.name.trim().toLowerCase() == nameKey);
      if (!alreadyRestored) {
        final customPhase = ConstructionPhase(name: name, isCustom: true);
        customPhase.isSelected = true;
        customPhase.isExpanded = true;
        freshPhases.add(customPhase);
      }
    }
    _phases = freshPhases;
  }
  Future<void> _fetchFreshAndPopulate() async {
    try {
      final fresh = await ApiService.fetchProjectById(widget.project.id);
      if (fresh != null && mounted) {
        setState(() {
          _populateFrom(fresh);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }
  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _mapAddressCtrl.dispose();
    _clientCtrl.dispose();
    _contactCtrl.dispose();
    _contractorCtrl.dispose();
    _engineerCtrl.dispose();
    _landAreaCtrl.dispose();
    _budgetMaterialCtrl.dispose();
    _budgetLabourCtrl.dispose();
    _budgetEquipmentCtrl.dispose();
    _budgetMiscCtrl.dispose();
    _customSubTypeCtrl.dispose();
    _customStageNameCtrl.dispose();
    super.dispose();
  }
  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final savedOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => onPicked(picked));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mainBuildingType == null) {
      setState(() => _buildingTypeError = 'Please select a Building Type');
      return;
    }
    setState(() => _saving = true);
    try {
      double parseBudget(TextEditingController c) =>
          double.tryParse(c.text) ?? 0.0;
      final bMat = parseBudget(_budgetMaterialCtrl);
      final bLab = parseBudget(_budgetLabourCtrl);
      final bEq = parseBudget(_budgetEquipmentCtrl);
      final bMisc = parseBudget(_budgetMiscCtrl);
      final budgetTotal = bMat + bLab + bEq + bMisc;
      String? nn(String s) => s.trim().isEmpty ? null : s.trim();
      String? effectiveSubType = _buildingSubType;
      if (_isCustomSubType && _customSubTypeCtrl.text.trim().isNotEmpty) {
        effectiveSubType = _customSubTypeCtrl.text.trim();
      }
      String? buildingTypeStr;
      if (_mainBuildingType != null) {
        buildingTypeStr = effectiveSubType != null
            ? '$_mainBuildingType → $effectiveSubType'
            : _mainBuildingType;
      }
      final finalFloors = List<String>.from(_selectedFloorChips);
      final selectedPhaseNamesList = _phases
          .where((ph) => ph.isSelected)
          .map((ph) => ph.name)
          .toList();
      final trackedActivityKeysList = _phases
          .expand((ph) => ph.allActivities)
          .where((a) => a.isSelected)
          .map((a) => a.key)
          .toList();
      final existingPhasesByName = <String, ProjectPhase>{
        for (final ph in _currentProject.selectedPhases ?? <ProjectPhase>[])
          ph.phaseName: ph,
      };
      final selectedPhasesList = _phases
          .where(
            (ph) => ph.isSelected && (ph.isCustom || ph.allActivities.any((a) => a.isSelected)),
          )
          .map((ph) {
            final existingId = existingPhasesByName[ph.name]?.id;
            return ProjectPhase(
              id:
                  existingId ??
                  'phase_${ph.name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
              phaseName: ph.name,
              isCustom: ph.isCustom,
              activities: ph.allActivities.where((a) => a.isSelected).map((a) {
                // Same lookup as _populateFrom (id, then phase::name), so an
                // activity matched by name keeps its id, completion and the
                // daily-update notes/photos ($set replaces selectedPhases).
                final prev = _existingActivityById[a.key] ??
                    _existingActivityById['${ph.name.trim().toLowerCase()}::${a.name.trim().toLowerCase()}'];
                return ProjectActivity(
                  id: (prev != null && prev.id.isNotEmpty) ? prev.id : a.key,
                  name: a.name,
                  isCustom: a.isCustom,
                  completed: prev?.completed ?? false,
                  completedAt: prev?.completedAt,
                  notes: prev?.notes,
                  photo: prev?.photo,
                  photos: prev?.photos,
                  budgetMaterial: a.budgetMaterial ?? prev?.budgetMaterial,
                  budgetLabour: a.budgetLabour ?? prev?.budgetLabour,
                  budgetEquipment: a.budgetEquipment ?? prev?.budgetEquipment,
                  qty: a.qty ?? prev?.qty,
                  unit: a.unit ?? prev?.unit,
                  materialRate: a.materialRate ?? prev?.materialRate,
                  materialAmount: a.materialAmount ?? prev?.materialAmount,
                  labourRate: a.labourRate ?? prev?.labourRate,
                  labourAmount: a.labourAmount ?? prev?.labourAmount,
                  equipmentRate: a.equipmentRate ?? prev?.equipmentRate,
                  equipmentAmount: a.equipmentAmount ?? prev?.equipmentAmount,
                );
              }).toList(),
            );
          })
          .toList();
      final completedActivityKeysList = selectedPhasesList
          .expand((ph) => ph.activities)
          .where((a) => a.completed)
          .map((a) => a.id)
          .toList();
      final updated = _currentProject.copyWith(
        name: _nameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        startDate: _startDate,
        sector: _currentProject.sector,
        mapAddress: nn(_mapAddressCtrl.text),
        clientName: nn(_clientCtrl.text),
        contactNumber: nn(_contactCtrl.text),
        contractorName: nn(_contractorCtrl.text),
        siteEngineer: nn(_engineerCtrl.text),
        landArea: nn(_landAreaCtrl.text),
        landUnit: _landUnit,
        floors: finalFloors,
        projectType: buildingTypeStr,
        expectedEndDate: _expectedEndDate,
        projectStatus: _projectStatus,
        budgetMaterial: bMat > 0 ? bMat : null,
        budgetLabour: bLab > 0 ? bLab : null,
        budgetEquipment: bEq > 0 ? bEq : null,
        budgetMisc: bMisc > 0 ? bMisc : null,
        totalBudget: budgetTotal > 0
            ? budgetTotal
            : _currentProject.totalBudget,
        room1BHK: _room1BHKCount > 0 ? _room1BHKCount : null,
        room2BHK: _room2BHKCount > 0 ? _room2BHKCount : null,
        room3BHK: _room3BHKCount > 0 ? _room3BHKCount : null,
        roomCustom: _roomCustomCount > 0 ? _roomCustomCount : null,
        bathWestern: _bathWesternCount > 0 ? _bathWesternCount : null,
        bathIndian: _bathIndianCount > 0 ? _bathIndianCount : null,
        bathCommon: _bathCommonCount > 0 ? _bathCommonCount : null,
        bathAttached: _bathAttachedCount > 0 ? _bathAttachedCount : null,
        selectedFeatures: _additionalConfigs.isEmpty
            ? null
            : _additionalConfigs.toList(),
        selectedPhaseNames: selectedPhaseNamesList,
        trackedActivityKeys: trackedActivityKeysList,
        selectedPhases: selectedPhasesList,
        completedActivityKeys: completedActivityKeysList,
      );
      await context.read<ProjectProvider>().updateProject(updated);
      if (mounted) {
        await showBtSuccess(
          context,
          kind: BtSuccessKind.check,
          title: 'Project updated',
          message: updated.name,
        );
        if (!mounted) return;
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Could not update the project: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  void _goStep(int i) {
    setState(() => _step = i);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Required fields live on earlier steps; jump back to them so errors are visible.
  void _finish() {
    if (_nameCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty) {
      _goStep(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _formKey.currentState?.validate());
      return;
    }
    _save();
  }

  static const _kStepLabels = ['BASICS', 'BUILDING', 'BUDGET', 'PHASES'];
  static const _kSteps = ['Basics', 'Building', 'Dates & budget', 'Phases'];

  @override
  Widget build(BuildContext context) {
    final int totalActs = _phases.fold(0, (s, p) => s + p.allActivities.length);
    final int doneActs = _phases.fold(0, (s, p) => s + p.selectedCount);
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Edit project',
        subtitle: (_currentProject.projectCode != null && _currentProject.projectCode!.isNotEmpty) ? _currentProject.projectCode! : null,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _StepBar(step: _step, labels: _kStepLabels, onTap: _goStep),
            ),
            AnimatedSize(
              duration: Bt.medium,
              curve: Bt.ease,
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.bt.accentSoft,
                          borderRadius: BorderRadius.circular(Bt.rTile),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: context.bt.accentInk),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Loading latest project data…',
                                style: BtText.caption(context, color: context.bt.accentInk, weight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Step 1 · Basics
                      _stepBlock(0, [
                        Text('Name the site.', style: BtText.d2(context)),
                        _section(
                          'PROJECT SETUP',
                          _InGroup(children: [
                            _inRow(
                              'Name',
                              required: true,
                              child: _bareField(
                                controller: _nameCtrl,
                                hint: 'e.g. Skyline Towers',
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            _inRow(
                              'City',
                              required: true,
                              child: _bareField(
                                controller: _cityCtrl,
                                hint: 'e.g. Bengaluru',
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            _inRow(
                              'Address',
                              trailing: Icon(Icons.place_outlined, size: 20, color: context.bt.accentInk),
                              child: _bareField(
                                controller: _mapAddressCtrl,
                                hint: 'Map location or address',
                              ),
                            ),
                          ]),
                        ),
                        _section(
                          'CLIENT',
                          _InGroup(children: [
                            _inRow(
                              'Name',
                              child: _bareField(controller: _clientCtrl, hint: 'Client / Owner'),
                            ),
                            _inRow(
                              'Contact',
                              child: _bareField(
                                controller: _contactCtrl,
                                hint: '+91 XXXXX XXXXX',
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ]),
                        ),
                        _section(
                          'SITE TEAM',
                          _InGroup(children: [
                            _inRow(
                              'Contractor',
                              child: _bareField(controller: _contractorCtrl, hint: 'Main contractor'),
                            ),
                            _inRow(
                              'Engineer',
                              child: _bareField(controller: _engineerCtrl, hint: 'Engineer in charge'),
                            ),
                          ]),
                        ),
                      ]),

                      // ── Step 2 · Building
                      _stepBlock(1, [
                        Text('What are we building?', style: BtText.d2(context)),
                        _buildingTypePicker(),
                        BtCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('LAND & FLOORS', style: BtText.mono(context)),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _landAreaCtrl,
                                keyboardType: TextInputType.number,
                                style: BtText.num(BtText.body(context)),
                                decoration: btInput(context, hint: 'Total land area, e.g. 2400'),
                              ),
                              const SizedBox(height: 10),
                              BtSegmented<String>(
                                segments: const {'Sq ft': 'Sq ft', 'Sq m': 'Sq m', 'Acres': 'Acres', 'Hectares': 'Hectares'},
                                value: _landUnit,
                                onChanged: (val) => setState(() => _landUnit = val),
                              ),
                              const SizedBox(height: 16),
                              Text('Floors included', style: BtText.subhead(context, weight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _floorChipOptions
                                    .map(
                                      (f) => BtChip(
                                        label: f,
                                        selected: _selectedFloorChips.contains(f),
                                        onTap: () => setState(
                                          () => _selectedFloorChips.contains(f)
                                              ? _selectedFloorChips.remove(f)
                                              : _selectedFloorChips.add(f),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (_selectedFloorChips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '${_selectedFloorChips.length} floor${_selectedFloorChips.length > 1 ? 's' : ''} selected: ${_selectedFloorChips.join(', ')}',
                                  style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                        BtCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('ROOMS & BATHROOMS', style: BtText.mono(context)),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Room types', style: BtText.caption(context)),
                                        _Counter(
                                          label: '1 BHK',
                                          value: _room1BHKCount,
                                          onInc: () => setState(() => _room1BHKCount++),
                                          onDec: () => setState(
                                            () => _room1BHKCount > 0 ? _room1BHKCount-- : 0,
                                          ),
                                        ),
                                        _Counter(
                                          label: '2 BHK',
                                          value: _room2BHKCount,
                                          onInc: () => setState(() => _room2BHKCount++),
                                          onDec: () => setState(
                                            () => _room2BHKCount > 0 ? _room2BHKCount-- : 0,
                                          ),
                                        ),
                                        _Counter(
                                          label: '3 BHK',
                                          value: _room3BHKCount,
                                          onInc: () => setState(() => _room3BHKCount++),
                                          onDec: () => setState(
                                            () => _room3BHKCount > 0 ? _room3BHKCount-- : 0,
                                          ),
                                        ),
                                        _Counter(
                                          label: 'Custom',
                                          value: _roomCustomCount,
                                          onInc: () => setState(() => _roomCustomCount++),
                                          onDec: () => setState(
                                            () => _roomCustomCount > 0
                                                ? _roomCustomCount--
                                                : 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Bathroom types', style: BtText.caption(context)),
                                        _Counter(
                                          label: 'Western',
                                          value: _bathWesternCount,
                                          onInc: () => setState(() => _bathWesternCount++),
                                          onDec: () => setState(
                                            () => _bathWesternCount > 0
                                                ? _bathWesternCount--
                                                : 0,
                                          ),
                                        ),
                                        _Counter(
                                          label: 'Indian',
                                          value: _bathIndianCount,
                                          onInc: () => setState(() => _bathIndianCount++),
                                          onDec: () => setState(
                                            () => _bathIndianCount > 0
                                                ? _bathIndianCount--
                                                : 0,
                                          ),
                                        ),
                                        _Counter(
                                          label: 'Common',
                                          value: _bathCommonCount,
                                          onInc: () => setState(() => _bathCommonCount++),
                                          onDec: () => setState(
                                            () => _bathCommonCount > 0
                                                ? _bathCommonCount--
                                                : 0,
                                          ),
                                        ),
                                        _Counter(
                                          label: 'Attached',
                                          value: _bathAttachedCount,
                                          onInc: () => setState(() => _bathAttachedCount++),
                                          onDec: () => setState(
                                            () => _bathAttachedCount > 0
                                                ? _bathAttachedCount--
                                                : 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _configSection(
                          'ADDITIONAL CONFIGURATION',
                          _kAddlConfigEdit,
                          expanded: _addlExpanded,
                          onToggle: () => setState(() => _addlExpanded = !_addlExpanded),
                        ),
                        _configSection('UTILITY & SERVICES', _kUtilityEdit),
                        _configSection('GAS CONNECTION', _kGasEdit),
                        _configSection('KITCHEN REQUIREMENTS', _kKitchenEdit),
                        _configSection('ELECTRICAL & PLUMBING', _kElectricalEdit),
                        _configSection('TERRACE & INTERIOR', _kTerraceEdit),
                      ]),

                      // ── Step 3 · Dates & budget
                      _stepBlock(2, [
                        Text('When, and how much?', style: BtText.d2(context)),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTile(
                                label: 'Start date',
                                required: false,
                                date: _startDate,
                                onTap: () => _pickDate(
                                  initial: _startDate,
                                  onPicked: (d) => _startDate = d,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded, size: 18, color: Bt.ink3),
                            ),
                            Expanded(
                              child: _DateTile(
                                label: 'Expected end',
                                required: false,
                                date: _expectedEndDate,
                                onTap: () => _pickDate(
                                  initial: _expectedEndDate ?? DateTime.now(),
                                  onPicked: (d) => _expectedEndDate = d,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _statusPicker(),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            _budgetMaterialCtrl,
                            _budgetLabourCtrl,
                            _budgetEquipmentCtrl,
                            _budgetMiscCtrl,
                          ]),
                          builder: (context, _) => _BudgetSummary(values: [
                            double.tryParse(_budgetMaterialCtrl.text) ?? 0,
                            double.tryParse(_budgetLabourCtrl.text) ?? 0,
                            double.tryParse(_budgetEquipmentCtrl.text) ?? 0,
                            double.tryParse(_budgetMiscCtrl.text) ?? 0,
                          ]),
                        ),
                        _section(
                          'BUDGET BREAKDOWN',
                          _InGroup(children: [
                            _budgetRow('Material', context.bt.accent, _budgetMaterialCtrl),
                            _budgetRow('Labour', Bt.steel, _budgetLabourCtrl),
                            _budgetRow('Equipment', Bt.slate, _budgetEquipmentCtrl),
                            _budgetRow('Misc', Bt.ink, _budgetMiscCtrl),
                          ]),
                        ),
                      ]),

                      // ── Step 4 · Phases
                      _stepBlock(3, [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phases & work', style: BtText.d2(context)),
                            const SizedBox(height: 4),
                            Text('Select phases and activities tracked for this project.', style: BtText.subhead(context)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_phases.length} phases · $doneActs of $totalActs activities selected',
                                maxLines: 2,
                                style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _link(
                              'Select all',
                              color: context.bt.accentInk,
                              onTap: () => setState(() {
                                for (var p in _phases) {
                                  p.isSelected = true;
                                  for (var a in p.allActivities) {
                                    a.isSelected = true;
                                  }
                                }
                              }),
                            ),
                            const SizedBox(width: 4),
                            _link(
                              'Clear',
                              color: Bt.ink2,
                              onTap: () => setState(() {
                                for (var p in _phases) {
                                  p.isSelected = false;
                                  for (var a in p.allActivities) {
                                    a.isSelected = false;
                                  }
                                }
                              }),
                            ),
                          ],
                        ),
                        _buildCsvImportExportCard(),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Bt.rCard),
                            boxShadow: Bt.shadow,
                          ),
                          child: Material(
                            color: Bt.card,
                            borderRadius: BorderRadius.circular(Bt.rCard),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: List.generate(
                                _phases.length,
                                (i) => _buildPhaseAccordion(i, _phases[i]),
                              ),
                            ),
                          ),
                        ),
                        BtButton(
                          label: 'Add custom phase',
                          icon: Icons.add_rounded,
                          variant: BtButtonVariant.secondary,
                          onPressed: _showAddCustomStageDialog,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BtCtaBar(
        children: [
          Expanded(
            child: _step < 3
                ? BtButton(
                    label: 'Next: ${_kSteps[_step + 1]}',
                    variant: BtButtonVariant.secondary,
                    onPressed: _saving ? null : () => _goStep(_step + 1),
                  )
                : BtButton(
                    label: 'Back',
                    variant: BtButtonVariant.secondary,
                    onPressed: _saving ? null : () => _goStep(_step - 1),
                  ),
          ),
          Expanded(
            child: BtButton(
              label: 'Save Changes',
              icon: Icons.check_rounded,
              variant: BtButtonVariant.accent,
              loading: _saving,
              onPressed: _saving
                  ? null
                  : () {
                      if (_mainBuildingType == null) {
                        // Was a silently disabled button.
                        btToast(context, 'Pick what you\'re building (Building step) before saving.', error: true);
                        _goStep(1);
                        return;
                      }
                      _finish();
                    },
            ),
          ),
        ],
      ),
    );
  }

  /// One wizard step. All steps stay mounted (Offstage) so the form can
  /// validate fields on earlier steps; the active one re-runs its entrance.
  Widget _stepBlock(int n, List<Widget> children) {
    final active = _step == n;
    return Offstage(
      offstage: !active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : (i == 1 ? 18 : 16)),
              child: BtReveal(
                key: ValueKey('np-$n-$i-$active'),
                index: i > 7 ? 7 : i,
                child: children[i],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String mono, Widget child, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(mono, style: BtText.mono(context))),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _inRow(String label, {required Widget child, bool required = false, Widget? leading, Widget? trailing}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            SizedBox(
              width: leading != null ? 82 : 96,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: label),
                  if (required) const TextSpan(text: ' *', style: TextStyle(color: Bt.red)),
                ]),
                style: BtText.subhead(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  /// Borderless input for grouped rows.
  Widget _bareField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    const none = InputBorder.none;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator: validator,
      style: BtText.num(BtText.body(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BtText.body(context, color: Bt.placeholder),
        prefixText: prefixText,
        prefixStyle: BtText.body(context, color: Bt.ink2),
        counterText: '',
        isDense: true,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        border: none,
        enabledBorder: none,
        focusedBorder: none,
        errorBorder: none,
        focusedErrorBorder: none,
        disabledBorder: none,
        errorStyle: BtText.caption(context, color: Bt.red),
      ),
    );
  }

  Widget _budgetRow(String label, Color dot, TextEditingController ctrl) {
    return _inRow(
      label,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(2)),
      ),
      child: _bareField(
        controller: ctrl,
        hint: '₹ 0',
        prefixText: '₹ ',
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _link(String text, {required Color color, required VoidCallback onTap}) {
    return BtPressable(
      onTap: onTap,
      semanticLabel: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            child: Text(text, style: BtText.subhead(context, color: color, weight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('resid')) return Icons.home_outlined;
    if (t.contains('educ')) return Icons.school_outlined;
    if (t.contains('instit')) return Icons.account_balance_outlined;
    if (t.contains('commer')) return Icons.storefront_outlined;
    if (t.contains('indus')) return Icons.factory_outlined;
    return Icons.apartment_outlined;
  }

  static String _typeLabel(String type) =>
      type;

  Widget _buildingTypePicker() {
    final subs = _mainBuildingType != null
        ? (_buildingSubTypes[_mainBuildingType!] ?? const <String>[])
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final type in _buildingSubTypes.keys) ...[
                if (type != _buildingSubTypes.keys.first) const SizedBox(width: 8),
                _TypeTile(
                  icon: _typeIcon(type),
                  label: _typeLabel(type),
                  selected: _mainBuildingType == type,
                  onTap: () => setState(() {
                    _mainBuildingType = type;
                    _buildingSubType = null;
                    _isCustomSubType = false;
                    _customSubTypeCtrl.clear();
                    _buildingTypeError = null;
                  }),
                ),
              ],
            ],
          ),
        ),
        if (_buildingTypeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Bt.red),
                const SizedBox(width: 6),
                Text(_buildingTypeError!, style: BtText.caption(context, color: Bt.red, weight: FontWeight.w500)),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text('Sub type', style: BtText.subhead(context, weight: FontWeight.w500)),
        const SizedBox(height: 8),
        if (_mainBuildingType == null)
          Text('Select main type first', style: BtText.caption(context))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subs.map((val) {
              final sel = val == 'Other (Custom)' ? _isCustomSubType : (!_isCustomSubType && _buildingSubType == val);
              return BtChip(
                label: val,
                selected: sel,
                onTap: () => setState(() {
                  if (val == 'Other (Custom)') {
                    _isCustomSubType = true;
                    _buildingSubType = null;
                  } else {
                    _isCustomSubType = false;
                    _buildingSubType = val;
                    _customSubTypeCtrl.clear();
                  }
                }),
              );
            }).toList(),
          ),
        if (_isCustomSubType) ...[
          const SizedBox(height: 10),
          _InGroup(children: [
            _inRow(
              'Custom',
              child: _bareField(
                controller: _customSubTypeCtrl,
                hint: 'e.g. Duplex, Penthouse...',
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _statusPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Project status', style: BtText.subhead(context, weight: FontWeight.w500)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final opt in _statusOptions) ...[
                if (opt != _statusOptions.first) const SizedBox(width: 6),
                BtChip(
                  label: opt,
                  selected: _projectStatus == opt,
                  onTap: () => setState(() => _projectStatus = opt),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// A configuration group as chips. Long groups show the first 8 (plus any
  /// selected) until expanded.
  Widget _configSection(String title, List<String> options, {bool expanded = true, VoidCallback? onToggle}) {
    final selCount = options.where(_additionalConfigs.contains).length;
    final collapsible = onToggle != null && options.length > 8;
    final showAll = !collapsible || expanded;
    final visible = showAll
        ? options
        : [
            for (var i = 0; i < options.length; i++)
              if (i < 8 || _additionalConfigs.contains(options[i])) options[i],
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: BtText.mono(context))),
            Text(
              selCount > 0 ? '$selCount selected' : 'None selected',
              style: BtText.caption(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: Bt.medium,
          curve: Bt.ease,
          alignment: Alignment.topCenter,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: visible
                .map(
                  (opt) => BtChip(
                    label: opt,
                    selected: _additionalConfigs.contains(opt),
                    onTap: () => setState(
                      () => _additionalConfigs.contains(opt)
                          ? _additionalConfigs.remove(opt)
                          : _additionalConfigs.add(opt),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (collapsible)
          Align(
            alignment: Alignment.centerLeft,
            child: _link(
              showAll ? 'Show less' : '+${options.length - visible.length} more',
              color: context.bt.accentInk,
              onTap: onToggle,
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseAccordion(int index, ConstructionPhase phase) {
    final sel = phase.selectedCount;
    final tot = phase.totalCount;
    final state = !phase.isSelected ? 0 : ((tot == 0 || sel == tot) ? 2 : 1);
    return Column(
      key: ValueKey('phase_${phase.name}_$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index > 0)
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(height: 1, thickness: 1, color: Bt.line),
          ),
        InkWell(
          onTap: () => setState(() => phase.isExpanded = !phase.isExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  checked: state == 2,
                  mixed: state == 1,
                  label: 'Select ${phase.name}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      if (phase.isSelected) {
                        final confirm = await btConfirm(
                          context,
                          title: 'Remove Phase?',
                          message: 'Are you sure you want to remove ${phase.name}? All data under this phase will be deleted when you save.',
                          confirmLabel: 'Remove',
                        );
                        if (!confirm) return;
                      }
                      if (!mounted) return;
                      setState(() {
                        phase.isSelected = !phase.isSelected;
                        for (var a in phase.allActivities) {
                          a.isSelected = phase.isSelected;
                        }
                      });
                    },
                    child: SizedBox(
                      width: 46,
                      height: 44,
                      child: Center(child: _TriCheck(state: state)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phase.name,
                        style: BtText.body(context, weight: FontWeight.w600, color: state == 0 ? Bt.ink2 : Bt.ink),
                      ),
                      Text(
                        state == 0 && sel == 0 ? 'None selected' : '$sel of $tot activities',
                        style: BtText.num(BtText.caption(context, color: state == 0 ? Bt.ink3 : Bt.ink2)),
                      ),
                    ],
                  ),
                ),
                BtIconButton(
                  icon: Icons.edit_outlined,
                  size: 18,
                  color: Bt.ink3,
                  semantic: 'Rename ${phase.name}',
                  onTap: () => _showRenamePhaseDialog(phase),
                ),
                AnimatedRotation(
                  turns: phase.isExpanded ? 0.5 : 0,
                  duration: Bt.fast,
                  curve: Bt.ease,
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.ink3, size: 22),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(58, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (_, _) => Material(
                      color: Colors.transparent,
                      shadowColor: Colors.transparent,
                      child: child,
                    ),
                  ),
                  onReorder: (oldIndex, newIndex) => setState(() {
                    final list = phase.activities;
                    list.insert(newIndex, list.removeAt(oldIndex));
                  }),
                  itemCount: phase.allActivities.length,
                  itemBuilder: (_, idx) {
                    final act = phase.allActivities[idx];
                    return Padding(
                      key: ValueKey(act.key),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ActivityPill(
                        name: act.name,
                        selected: act.isSelected,
                        onTap: () => setState(() {
                          act.isSelected = !act.isSelected;
                          if (act.isSelected) {
                            phase.isSelected = true;
                          } else {
                            if (!phase.allActivities.any((a) => a.isSelected)) {
                              phase.isSelected = false;
                            }
                          }
                        }),
                        handle: ReorderableDragStartListener(
                          index: idx,
                          child: const SizedBox(
                            width: 36,
                            height: 42,
                            child: Icon(Icons.drag_indicator_rounded, size: 18, color: Bt.ink3),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _link(
                    '+ Add custom activity',
                    color: context.bt.accentInk,
                    onTap: () => _showAddCustomActivityDialog(phase),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: phase.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: Bt.fast,
          sizeCurve: Bt.ease,
        ),
      ],
    );
  }
  void _showRenamePhaseDialog(ConstructionPhase phase) {
    final ctrl = TextEditingController(text: phase.name);
    final focusNode = FocusNode();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Bt.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
        title: const Text(
          'Edit Phase',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        content: TextField(
          controller: ctrl,
          focusNode: focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textGray.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final dup = _phases.any(
                (p) =>
                    p != phase &&
                    p.name.trim().toLowerCase() == name.toLowerCase(),
              );
              if (dup) return;
              setState(() {
                final idx = _phases.indexWhere((p) => p == phase);
                final renamed = ConstructionPhase(
                  name: name,
                  isCustom: true,
                  activities: List<ConstructionActivity>.of(phase.activities),
                  groups: List<ConstructionActivityGroup>.of(phase.groups),
                  isExpanded: phase.isExpanded,
                  isSelected: phase.isSelected,
                );
                if (idx != -1) {
                  _phases[idx] = renamed;
                } else {
                  _phases.add(renamed);
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      ctrl.dispose();
      focusNode.dispose();
    });
  }
  void _showAddCustomStageDialog() {
    _customStageNameCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Bt.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
        title: const Text(
          'Add Custom Phase',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        content: TextField(
          controller: _customStageNameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textGray.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _customStageNameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(
                () {
                  final newPhase = ConstructionPhase(name: name, isCustom: true);
                  newPhase.isSelected = true;
                  newPhase.isExpanded = true;
                  _phases.add(newPhase);
                },
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showAddCustomActivityDialog(ConstructionPhase phase) {
    final ctrl = TextEditingController();
    final focusNode = FocusNode();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Bt.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Bt.rCard)),
        title: const Text(
          'Add Custom Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        content: TextField(
          controller: ctrl,
          focusNode: focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textGray.withValues(alpha: 0.7),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              setState(
                () {
                  // A newly added activity is part of the plan: select it (and its
                  // phase). Unselected activities are dropped on save, so before
                  // this the new activity silently disappeared.
                  final act = ConstructionActivity(
                    key: '${phase.name}::Custom::$name',
                    name: name,
                    isCustom: true,
                  );
                  act.isSelected = true;
                  phase.activities.add(act);
                  phase.isSelected = true;
                },
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Add',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      ctrl.dispose();
      focusNode.dispose();
    });
  }
  bool _isUploadingCsv = false;
  Future<void> _downloadTemplate() async {
    final List<List<dynamic>> csvRows = [
      [
        'Phase',
        'Sl.No',
        'Particular',
        'Total_Qty',
        'Unit',
        'Material_Rate',
        'Budget_Material_Amount',
        'Labour_Rate',
        'Budget_Labour_Amount',
        'Equipment_Rate',
        'Budget_Equipment_Amount',
        'Total_Amount',
      ],
    ];
    for (final phase in _phases) {
      if (!phase.isSelected) continue;
      int slNo = 1;
      for (final act in phase.allActivities) {
        if (!act.isSelected) continue;
        final double matAmt = act.budgetMaterial ?? 0.0;
        final double labAmt = act.budgetLabour ?? 0.0;
        final double eqAmt = act.budgetEquipment ?? 0.0;
        final double totAmt = matAmt + labAmt + eqAmt;
        final double qty = act.qty ?? 1.0;
        final String unit = act.unit ?? '';
        final double matRate = act.materialRate ?? 0.0;
        final double labRate = act.labourRate ?? 0.0;
        final double eqRate = act.equipmentRate ?? 0.0;
        csvRows.add([
          phase.name,
          slNo++,
          act.name,
          qty > 0 ? qty.toStringAsFixed(2) : '',
          unit,
          matRate > 0 ? matRate.toStringAsFixed(2) : '',
          matAmt > 0 ? matAmt.toStringAsFixed(2) : '',
          labRate > 0 ? labRate.toStringAsFixed(2) : '',
          labAmt > 0 ? labAmt.toStringAsFixed(2) : '',
          eqRate > 0 ? eqRate.toStringAsFixed(2) : '',
          eqAmt > 0 ? eqAmt.toStringAsFixed(2) : '',
          totAmt > 0 ? totAmt.toStringAsFixed(2) : '',
        ]);
      }
    }
    final csvContent = const ListToCsvConverter().convert(csvRows);
    final filename =
        '${widget.project.name.replaceAll(' ', '_')}_phases_template.csv';
    try {
      await saveAndShareCsv(
        csvContent: csvContent,
        filename: filename,
        shareText: 'Exported CSV for ${widget.project.name}',
      );
      if (mounted) {
        btToast(context, 'CSV exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Failed to export CSV: $e', error: true);
      }
    }
  }
  Future<void> _uploadCsv() async {
    setState(() => _isUploadingCsv = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingCsv = false);
        return;
      }
      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        throw Exception("Failed to read file data");
      }
      final csvString = utf8.decode(fileBytes);
      final List<List<dynamic>> parsedCsv = const CsvToListConverter().convert(
        csvString,
      );
      if (parsedCsv.isEmpty || parsedCsv.length <= 1) {
        throw Exception("CSV file is empty or missing headers");
      }
      final headers = parsedCsv.first
          .map((h) => h.toString().trim().toLowerCase())
          .toList();
      final phaseIdx = headers.indexOf('phase');
      final particularIdx = headers.indexOf('particular');
      int qtyIdx = headers.indexOf('total_qty');
      if (qtyIdx == -1) qtyIdx = headers.indexOf('qty');
      final unitIdx = headers.indexOf('unit');
      final matRateIdx = headers.indexOf('material_rate');
      int matAmtIdx = headers.indexOf('budget_material_amount');
      if (matAmtIdx == -1) matAmtIdx = headers.indexOf('material_amount');
      final labRateIdx = headers.indexOf('labour_rate');
      int labAmtIdx = headers.indexOf('budget_labour_amount');
      if (labAmtIdx == -1) labAmtIdx = headers.indexOf('labour_amount');
      final eqRateIdx = headers.indexOf('equipment_rate');
      int eqAmtIdx = headers.indexOf('budget_equipment_amount');
      if (eqAmtIdx == -1) eqAmtIdx = headers.indexOf('equipment_amount');
      if (phaseIdx == -1 || particularIdx == -1) {
        throw Exception(
          "CSV is missing required 'Phase' or 'Particular' column headers",
        );
      }
      double? parseVal(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        final str = v.toString().trim();
        if (str.isEmpty) return null;
        final clean = str.replaceAll(RegExp(r'[^\d\.]'), '');
        return double.tryParse(clean);
      }
      int updatedCount = 0;
      double materialSum = 0.0;
      double labourSum = 0.0;
      double equipmentSum = 0.0;
      for (int i = 1; i < parsedCsv.length; i++) {
        final row = parsedCsv[i];
        final maxIdx = phaseIdx > particularIdx ? phaseIdx : particularIdx;
        if (row.length <= maxIdx) continue;
        final String phaseName = row[phaseIdx].toString().trim();
        final String activityName = row[particularIdx].toString().trim();
        if (phaseName.isEmpty || activityName.isEmpty) continue;
        final double? qty = qtyIdx != -1 && qtyIdx < row.length
            ? parseVal(row[qtyIdx])
            : null;
        final String unit = unitIdx != -1 && unitIdx < row.length
            ? row[unitIdx].toString().trim()
            : '';
        final double? matRate = matRateIdx != -1 && matRateIdx < row.length
            ? parseVal(row[matRateIdx])
            : null;
        double? matAmt = matAmtIdx != -1 && matAmtIdx < row.length
            ? parseVal(row[matAmtIdx])
            : null;
        final double? labRate = labRateIdx != -1 && labRateIdx < row.length
            ? parseVal(row[labRateIdx])
            : null;
        double? labAmt = labAmtIdx != -1 && labAmtIdx < row.length
            ? parseVal(row[labAmtIdx])
            : null;
        final double? eqRate = eqRateIdx != -1 && eqRateIdx < row.length
            ? parseVal(row[eqRateIdx])
            : null;
        double? eqAmt = eqAmtIdx != -1 && eqAmtIdx < row.length
            ? parseVal(row[eqAmtIdx])
            : null;
        int phaseIndex = _phases.indexWhere(
          (p) => p.name.trim().toLowerCase() == phaseName.toLowerCase(),
        );
        if (phaseIndex == -1) {
          final newPhase = ConstructionPhase(name: phaseName, isCustom: true);
          newPhase.isSelected = true;
          newPhase.isExpanded = true;
          _phases.add(newPhase);
          phaseIndex = _phases.length - 1;
        }
        final phase = _phases[phaseIndex];
        phase.isSelected = true;
        phase.isExpanded = true;
        final actIndex = phase.allActivities.indexWhere(
          (a) => a.name.trim().toLowerCase() == activityName.toLowerCase(),
        );
        if (actIndex != -1) {
          final act = phase.allActivities[actIndex];
          act.isSelected = true;
          if (matAmt != null) act.budgetMaterial = matAmt;
          if (labAmt != null) act.budgetLabour = labAmt;
          if (eqAmt != null) act.budgetEquipment = eqAmt;
          if (qty != null) act.qty = qty;
          if (unit.isNotEmpty) act.unit = unit;
          if (matRate != null) act.materialRate = matRate;
          if (matAmt != null) act.materialAmount = matAmt;
          if (labRate != null) act.labourRate = labRate;
          if (labAmt != null) act.labourAmount = labAmt;
          if (eqRate != null) act.equipmentRate = eqRate;
          if (eqAmt != null) act.equipmentAmount = eqAmt;
          updatedCount++;
          materialSum += matAmt ?? 0.0;
          labourSum += labAmt ?? 0.0;
          equipmentSum += eqAmt ?? 0.0;
        } else {
          final newAct = ConstructionActivity(
            key:
                '${phaseName.trim().toLowerCase()}::${activityName.trim().toLowerCase()}',
            name: activityName,
            isCustom: true,
            budgetMaterial: matAmt,
            budgetLabour: labAmt,
            budgetEquipment: eqAmt,
            qty: qty,
            unit: unit,
            materialRate: matRate,
            materialAmount: matAmt,
            labourRate: labRate,
            labourAmount: labAmt,
            equipmentRate: eqRate,
            equipmentAmount: eqAmt,
          );
          newAct.isSelected = true;
          phase.activities.add(newAct);
          updatedCount++;
          materialSum += matAmt ?? 0.0;
          labourSum += labAmt ?? 0.0;
          equipmentSum += eqAmt ?? 0.0;
        }
      }
      _budgetMaterialCtrl.text = materialSum > 0
          ? materialSum.toStringAsFixed(0)
          : '';
      _budgetLabourCtrl.text = labourSum > 0
          ? labourSum.toStringAsFixed(0)
          : '';
      _budgetEquipmentCtrl.text = equipmentSum > 0
          ? equipmentSum.toStringAsFixed(0)
          : '';
      setState(() {});
      if (mounted) {
        btToast(context, 'Successfully imported budget for $updatedCount activities!');
      }
    } catch (e) {
      if (mounted) {
        btToast(context, 'Upload failed: $e', error: true);
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }
  Widget _buildCsvImportExportCard() {
    return BtCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BtTile(icon: Icons.table_chart_outlined, bg: Bt.greenSoft, fg: Bt.green, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phases & budget configuration', style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
                    Text('Import/Export CSV budgets for all phases.', style: BtText.caption(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BtButton(
                  label: 'Export CSV',
                  icon: Icons.download_rounded,
                  variant: BtButtonVariant.secondary,
                  small: true,
                  onPressed: _downloadTemplate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BtButton(
                  label: 'Upload CSV',
                  icon: Icons.upload_file_rounded,
                  small: true,
                  loading: _isUploadingCsv,
                  onPressed: _isUploadingCsv ? null : _uploadCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── V2 private widgets
// (Project form only — kept private to this file so the shared design system
// stays untouched.)

/// Segmented 4-step progress bar with mono labels under each segment.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.labels, required this.onTap});
  final int step;
  final List<String> labels;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.bt.accent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: onTap != null,
              selected: i == step,
              label: '${labels[i]}, step ${i + 1} of ${labels.length}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap == null ? null : () => onTap!(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 6,
                          color: Bt.ink.withValues(alpha: .08),
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: i < step ? 1.0 : (i == step ? .55 : 0.0)),
                            duration: Bt.reduceMotion(context) ? Duration.zero : Bt.slow,
                            curve: Bt.ease,
                            builder: (_, v, _) => FractionallySizedBox(
                              widthFactor: v,
                              heightFactor: 1,
                              child: AnimatedContainer(
                                duration: Bt.fast,
                                decoration: BoxDecoration(
                                  color: i < step ? Bt.green : accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BtText.mono(context, color: i == step ? Bt.ink : Bt.ink3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// White grouped-input card: rows of label-left / input-right with inset hairlines.
class _InGroup extends StatelessWidget {
  const _InGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Bt.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Divider(height: 1, thickness: 1, color: Bt.line),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Building-type tile (icon + label). Selected = ink with accent icon.
class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: BtPressable(
        onTap: onTap,
        scale: .95,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          width: 106,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? Bt.ink : Bt.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Bt.ink : Bt.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: selected ? context.bt.accent : Bt.ink),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BtText.caption(context, color: selected ? Bt.bone : Bt.ink, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact − n + counter used for rooms / bathrooms.
class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.onInc, required this.onDec});
  final String label;
  final int value;
  final VoidCallback onInc;
  final VoidCallback onDec;

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap, String semantic, {bool dim = false}) {
    return BtPressable(
      onTap: onTap,
      scale: .9,
      semanticLabel: semantic,
      child: SizedBox(
        width: 36,
        height: 44,
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Bt.ink.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: dim ? Bt.ink3 : Bt.ink),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BtText.subhead(context, color: Bt.ink),
          ),
        ),
        _btn(context, Icons.remove_rounded, onDec, 'Decrease $label', dim: value == 0),
        SizedBox(
          width: 22,
          child: AnimatedSwitcher(
            duration: Bt.fast,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
            child: Text(
              '$value',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w700)),
            ),
          ),
        ),
        _btn(context, Icons.add_rounded, onInc, 'Increase $label'),
      ],
    );
  }
}

/// White date tile (caption + value). Shows a red edge when a required date is missing.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.onTap, required this.required});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final missing = required && date == null;
    return BtPressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Bt.fast,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Bt.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Bt.shadow,
          border: Border.all(color: missing ? Bt.red.withValues(alpha: .55) : Bt.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: label),
                      if (required) const TextSpan(text: ' *', style: TextStyle(color: Bt.red)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.caption(context, color: Bt.ink2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? formatDate(date) : 'Select',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.num(BtText.body(
                      context,
                      weight: FontWeight.w600,
                      color: date != null ? Bt.ink : (missing ? Bt.red : Bt.placeholder),
                    )),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 16, color: missing ? Bt.red : Bt.ink3),
          ],
        ),
      ),
    );
  }
}

/// Ink card: live total budget (rolls up) + stacked bar of the four categories.
class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.values});

  /// material, labour, equipment, misc
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final colors = [context.bt.accent, Bt.steel, Bt.slate, Bt.bone];
    return BtCard(
      variant: BtCardVariant.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL BUDGET', style: BtText.mono(context, color: Bt.onNoir2)),
          const SizedBox(height: 6),
          BtCountUp(
            value: total,
            format: (v) => formatInr(v, compact: true),
            style: BtText.d1(context, color: Bt.bone),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final nonZero = values.where((v) => v > 0).length;
              final avail = c.maxWidth - (nonZero > 1 ? 2.0 * (nonZero - 1) : 0);
              final segs = <Widget>[];
              for (var i = 0; i < values.length; i++) {
                if (values[i] <= 0 || total <= 0) continue;
                if (segs.isNotEmpty) segs.add(const SizedBox(width: 2));
                segs.add(AnimatedContainer(
                  duration: Bt.medium,
                  curve: Bt.ease,
                  width: (values[i] / total * avail).clamp(0.0, avail),
                  height: 10,
                  color: colors[i],
                ));
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 10,
                  color: Colors.white.withValues(alpha: .10),
                  child: Row(children: segs),
                ),
              );
            },
          ),
          if (total <= 0) ...[
            const SizedBox(height: 10),
            Text('Enter the split below — the total updates as you type.', style: BtText.caption(context, color: Bt.onNoir2)),
          ],
        ],
      ),
    );
  }
}

/// Tri-state check: 0 none, 1 some, 2 all.
class _TriCheck extends StatelessWidget {
  const _TriCheck({required this.state});
  final int state;

  @override
  Widget build(BuildContext context) {
    final bg = state == 2 ? Bt.green : (state == 1 ? Bt.ink : Colors.transparent);
    return AnimatedContainer(
      duration: Bt.fast,
      curve: Bt.ease,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: state == 0 ? Bt.inputBorder : bg, width: 1.6),
      ),
      child: state == 0
          ? null
          : Icon(state == 2 ? Icons.check_rounded : Icons.remove_rounded, size: 15, color: Colors.white),
    );
  }
}

/// Activity as a selectable chip-row (keeps the drag handle for reordering).
class _ActivityPill extends StatelessWidget {
  const _ActivityPill({required this.name, required this.selected, required this.onTap, required this.handle});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget handle;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      selected: selected,
      child: BtPressable(
        onTap: onTap,
        scale: .98,
        semanticLabel: name,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: selected ? bt.accentSoft : Bt.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? bt.accent.withValues(alpha: .45) : Bt.inputBorder),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 16, color: selected ? bt.accentInk : Bt.ink3),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    name,
                    style: BtText.subhead(context, weight: FontWeight.w500, color: selected ? bt.accentInk : Bt.ink2),
                  ),
                ),
              ),
              handle,
            ],
          ),
        ),
      ),
    );
  }
}
