import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/screen/reports/save_helper_stub.dart'
    if (dart.library.html) 'package:buildtrack_mobile/screen/reports/save_helper_web.dart'
    if (dart.library.io) 'package:buildtrack_mobile/screen/reports/save_helper_mobile.dart';
class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});
  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}
class _AddProjectScreenState extends State<AddProjectScreen> {
  static const primaryBlue = AppColors.primary;
  static const bgColor = AppColors.gradientStart;
  static const textDark = AppColors.textDark;
  static const textGray = AppColors.textLight;
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _mapAddressCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _engineerCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  late final String _projectCode;
  String? _mainBuildingType;
  String? _buildingSubType;
  String? _buildingTypeError;
  final _customSubTypeCtrl = TextEditingController();
  bool _isCustomSubType = false;
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
    'Business / Commercial': [
      'Shop',
      'Office',
      'Complex',
      'Plaza',
      'Other (Custom)',
    ],
    'Industrial': ['Factory', 'Warehouse', 'Other (Custom)'],
  };
  DateTime? _startDate;
  DateTime? _expectedEndDate;
  final _budgetMaterialCtrl = TextEditingController();
  final _budgetLabourCtrl = TextEditingController();
  final _budgetEquipmentCtrl = TextEditingController();
  final _budgetMiscCtrl = TextEditingController();
  String _projectStatus = 'Planning';
  final List<String> _statusOptions = [
    'Planning',
    'In Progress',
    'On Hold',
    'Completed',
    'Cancelled',
  ];
  bool _cfgBasicInfoExpanded = true;
  bool _cfgBuildingTypeExpanded = true;
  bool _cfgLandExpanded = true;
  bool _cfgRoomsExpanded = false;
  bool _cfgAddlExpanded = false;
  bool _cfgUtilityExpanded = false;
  bool _cfgGasExpanded = false;
  bool _cfgKitchenExpanded = false;
  bool _cfgElectricalExpanded = false;
  bool _cfgTerraceExpanded = false;
  final _landAreaCtrl = TextEditingController();
  String _landUnit = 'Sq ft';
  final List<String> _selectedFloorChips = [];
  final List<String> _floorChipOptions = [
    'Ground',
    '1st',
    '2nd',
    '3rd',
    '4th',
    'Terrace',
    'Head Room',
  ];
  int _room1BHKCount = 0,
      _room2BHKCount = 0,
      _room3BHKCount = 0,
      _roomCustomCount = 0;
  int _bathWesternCount = 0,
      _bathIndianCount = 0,
      _bathCommonCount = 0,
      _bathAttachedCount = 0;
  final Set<String> _additionalConfigs = {};
  final List<String> _addlConfigOptions = [
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
  final List<String> _utilityOptions = [
    'Main Electricity',
    'Temporary Connection',
    'Generator Backup',
    'Water Connection',
    'Borewell Motor',
    'Sump Motor',
  ];
  final List<String> _gasOptions = [
    'Piped Gas',
    'Cylinder Bank',
    'Gas Pipeline Routing',
  ];
  final List<String> _kitchenOptions = [
    'Granite Counter',
    'Quartz Counter',
    'Stainless Steel Sink',
    'Chimney Provision',
    'Exhaust Fan Provision',
  ];
  final List<String> _electricalOptions = [
    'Concealed Wiring',
    'Open Wiring',
    '3-Phase Connection',
    'AC Points',
    'Geyser Points',
  ];
  final List<String> _terraceOptions = [
    'Weathering Course',
    'Cool Roof Paint',
    'Overhead Tank',
    'Solar Panels',
  ];
  bool _saving = false;
  late List<ConstructionPhase> _phases;
  final _customStageNameCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _phases = buildDefaultPhases();
    final year = DateTime.now().year;
    final rand = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000))
        .toString();
    _projectCode = 'CF-$year-$rand';
  }
  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _mapAddressCtrl.dispose();
    _clientCtrl.dispose();
    _contractorCtrl.dispose();
    _engineerCtrl.dispose();
    _contactCtrl.dispose();
    _budgetMaterialCtrl.dispose();
    _budgetLabourCtrl.dispose();
    _budgetEquipmentCtrl.dispose();
    _budgetMiscCtrl.dispose();
    _landAreaCtrl.dispose();
    _customStageNameCtrl.dispose();
    _customSubTypeCtrl.dispose();
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
  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a project name')),
      );
      return;
    }
    final subProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final maxProjects = subProvider.currentPlan.maxProjects;
    final currentCount = projectProvider.projects.length;
    if (maxProjects != -1 && currentCount >= maxProjects) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6CF7), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Project Limit Reached',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${subProvider.currentPlan.label} plan allows up to $maxProjects projects. '
                'Upgrade to create more.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/subscription');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View Plans',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_mainBuildingType == null) {
      setState(() => _buildingTypeError = 'Please select a Building Type');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
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
      final selectedPhaseNamesList = _phases
          .where((p) => p.isSelected)
          .map((p) => p.name)
          .toList();
      final trackedActivityKeysList = _phases
          .expand((p) => p.allActivities)
          .where((a) => a.isSelected)
          .map((a) => a.key)
          .toList();
      final finalFloors = _selectedFloorChips.isEmpty
          ? <String>['Ground']
          : List<String>.from(_selectedFloorChips);
      final locationStr = _mapAddressCtrl.text.trim().isNotEmpty
          ? _mapAddressCtrl.text.trim()
          : _cityCtrl.text.trim();
      final newProject = ProjectModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        sector: '',
        stage: ProjectStage.preConstruction,
        progress: 0.0,
        totalBudget: budgetTotal,
        spentAmount: 0.0,
        startDate: _startDate!,
        location: locationStr,
        projectCode: _projectCode,
        mapAddress: nn(_mapAddressCtrl.text),
        clientName: nn(_clientCtrl.text),
        contactNumber: nn(_contactCtrl.text),
        expectedEndDate: _expectedEndDate,
        floors: finalFloors,
        selectedPhaseNames: selectedPhaseNamesList,
        trackedActivityKeys: trackedActivityKeysList,
        completedActivityKeys: [],
        selectedPhases: _phases
            .where(
              (p) => p.isSelected && (p.isCustom || p.allActivities.any((a) => a.isSelected)),
            )
            .map(
              (p) => ProjectPhase(
                id: 'phase_${p.name.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
                phaseName: p.name,
                isCustom: p.isCustom,
                activities: p.allActivities
                    .where((a) => a.isSelected)
                    .map(
                      (a) => ProjectActivity(
                        id: a.key,
                        name: a.name,
                        isCustom: a.isCustom,
                        budgetMaterial: a.budgetMaterial,
                        budgetLabour: a.budgetLabour,
                        budgetEquipment: a.budgetEquipment,
                        qty: a.qty,
                        unit: a.unit,
                        materialRate: a.materialRate,
                        materialAmount: a.materialAmount,
                        labourRate: a.labourRate,
                        labourAmount: a.labourAmount,
                        equipmentRate: a.equipmentRate,
                        equipmentAmount: a.equipmentAmount,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
        contractorName: nn(_contractorCtrl.text),
        siteEngineer: nn(_engineerCtrl.text),
        landArea: nn(_landAreaCtrl.text),
        landUnit: _landUnit,
        projectType: buildingTypeStr,
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
        budgetMaterial: bMat > 0 ? bMat : null,
        budgetLabour: bLab > 0 ? bLab : null,
        budgetEquipment: bEq > 0 ? bEq : null,
        budgetMisc: bMisc > 0 ? bMisc : null,
        projectStatus: _projectStatus,
      );
      await projectProvider.addProject(newProject);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: textDark,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Project Setup',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSubscriptionWarning(context),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey<String>('add_project_scroll_key'),
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionCard(
                        title: 'Project Setup',
                        icon: Icons.business_center_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Project Name'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _nameCtrl,
                              hint: 'e.g. Skyline Towers',
                              icon: Icons.apartment_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _label('City'),
                            const SizedBox(height: 8),
                            _field(
                              controller: _cityCtrl,
                              hint: 'e.g. Bengaluru',
                              icon: Icons.location_city_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Basic Information',
                        isExpanded: _cfgBasicInfoExpanded,
                        onToggle: () => setState(
                          () => _cfgBasicInfoExpanded = !_cfgBasicInfoExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryBlue.withValues(alpha: 0.18),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Project Code',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: textGray.withValues(
                                              alpha: 0.7,
                                            ),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        Text(
                                          'Auto-generated',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: textGray.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryBlue,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _projectCode,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _label(
                              'Map Location / Address',
                              icon: Icons.location_on_rounded,
                            ),
                            const SizedBox(height: 8),
                            _field(
                              controller: _mapAddressCtrl,
                              hint: 'e.g. 12 Main St, Bengaluru',
                              icon: Icons.place_rounded,
                            ),
                            const SizedBox(height: 16),
                            _groupContainer(
                              icon: Icons.person_rounded,
                              title: 'Client Details',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _label('Client Name'),
                                        const SizedBox(height: 8),
                                        _field(
                                          controller: _clientCtrl,
                                          hint: 'Client / Owner',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _label('Contact Number'),
                                        const SizedBox(height: 8),
                                        _field(
                                          controller: _contactCtrl,
                                          hint: '+91 XXXXX XXXXX',
                                          icon: Icons.phone_outlined,
                                          maxLength: 10,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _groupContainer(
                              icon: Icons.engineering_rounded,
                              title: 'Site Team',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _label('Site Engineer'),
                                        const SizedBox(height: 8),
                                        _field(
                                          controller: _engineerCtrl,
                                          hint: 'Engineer in charge',
                                          icon: Icons.construction_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _label('Contractor Name'),
                                        const SizedBox(height: 8),
                                        _field(
                                          controller: _contractorCtrl,
                                          hint: 'Main contractor',
                                          icon: Icons.engineering_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Building Type',
                        isExpanded: _cfgBuildingTypeExpanded,
                        onToggle: () => setState(
                          () => _cfgBuildingTypeExpanded =
                              !_cfgBuildingTypeExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Main Type'),
                                      const SizedBox(height: 8),
                                      _buildDropdown(
                                        value: _mainBuildingType,
                                        hint: 'Select building type',
                                        items: _buildingSubTypes.keys.toList(),
                                        onChanged: (val) => setState(() {
                                          _mainBuildingType = val;
                                          _buildingSubType = null;
                                          _isCustomSubType = false;
                                          _customSubTypeCtrl.clear();
                                          _buildingTypeError = null;
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Sub Type'),
                                      const SizedBox(height: 8),
                                      _buildDropdown(
                                        value: _isCustomSubType
                                            ? 'Other (Custom)'
                                            : _buildingSubType,
                                        hint: _mainBuildingType == null
                                            ? 'Select main type first'
                                            : 'Select sub type',
                                        items: _mainBuildingType != null
                                            ? (_buildingSubTypes[_mainBuildingType!] ??
                                                  [])
                                            : [],
                                        onChanged: _mainBuildingType == null
                                            ? null
                                            : (val) => setState(() {
                                                if (val == 'Other (Custom)') {
                                                  _isCustomSubType = true;
                                                  _buildingSubType = null;
                                                } else {
                                                  _isCustomSubType = false;
                                                  _buildingSubType = val;
                                                  _customSubTypeCtrl.clear();
                                                }
                                              }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_isCustomSubType) ...[
                              const SizedBox(height: 12),
                              _label(
                                'Enter Custom Sub Type',
                                icon: Icons.edit_rounded,
                              ),
                              const SizedBox(height: 8),
                              _field(
                                controller: _customSubTypeCtrl,
                                hint: 'e.g. Duplex, Penthouse...',
                                icon: Icons.category_outlined,
                              ),
                            ],
                            if (_buildingTypeError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 14,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _buildingTypeError!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Land & Floors',
                        isExpanded: _cfgLandExpanded,
                        onToggle: () => setState(
                          () => _cfgLandExpanded = !_cfgLandExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Total Land Area'),
                                      const SizedBox(height: 8),
                                      _field(
                                        controller: _landAreaCtrl,
                                        hint: 'e.g. 2400',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(10),
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d*'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Unit'),
                                      const SizedBox(height: 8),
                                      _buildDropdown(
                                        value: _landUnit,
                                        hint: 'Unit',
                                        items: const [
                                          'Sq ft',
                                          'Sq m',
                                          'Acres',
                                          'Hectares',
                                        ],
                                        onChanged: (val) => setState(
                                          () => _landUnit = val ?? 'Sq ft',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _label('Floors Included'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _floorChipOptions
                                  .map(
                                    (f) => _buildSelectableChip(
                                      label: f,
                                      isSelected: _selectedFloorChips.contains(
                                        f,
                                      ),
                                      onTap: () => setState(
                                        () => _selectedFloorChips.contains(f)
                                            ? _selectedFloorChips.remove(f)
                                            : _selectedFloorChips.add(f),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Rooms & Bathrooms',
                        isExpanded: _cfgRoomsExpanded,
                        onToggle: () => setState(
                          () => _cfgRoomsExpanded = !_cfgRoomsExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('ROOM TYPES', uppercase: true),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              '1 BHK',
                              _room1BHKCount,
                              onInc: () => setState(() => _room1BHKCount++),
                              onDec: () => setState(
                                () => _room1BHKCount > 0 ? _room1BHKCount-- : 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              '2 BHK',
                              _room2BHKCount,
                              onInc: () => setState(() => _room2BHKCount++),
                              onDec: () => setState(
                                () => _room2BHKCount > 0 ? _room2BHKCount-- : 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              '3 BHK',
                              _room3BHKCount,
                              onInc: () => setState(() => _room3BHKCount++),
                              onDec: () => setState(
                                () => _room3BHKCount > 0 ? _room3BHKCount-- : 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              'Custom Room',
                              _roomCustomCount,
                              onInc: () => setState(() => _roomCustomCount++),
                              onDec: () => setState(
                                () => _roomCustomCount > 0
                                    ? _roomCustomCount--
                                    : 0,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: Color(0xFFEEF0F5),
                                height: 1,
                              ),
                            ),
                            _label('BATHROOM TYPES', uppercase: true),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              'Western Toilet',
                              _bathWesternCount,
                              onInc: () => setState(() => _bathWesternCount++),
                              onDec: () => setState(
                                () => _bathWesternCount > 0
                                    ? _bathWesternCount--
                                    : 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              'Indian Toilet',
                              _bathIndianCount,
                              onInc: () => setState(() => _bathIndianCount++),
                              onDec: () => setState(
                                () => _bathIndianCount > 0
                                    ? _bathIndianCount--
                                    : 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              'Common Bath',
                              _bathCommonCount,
                              onInc: () => setState(() => _bathCommonCount++),
                              onDec: () => setState(
                                () => _bathCommonCount > 0
                                    ? _bathCommonCount--
                                    : 0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildCounterRow(
                              'Attached Bath',
                              _bathAttachedCount,
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
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Additional Configuration',
                        isExpanded: _cfgAddlExpanded,
                        onToggle: () => setState(
                          () => _cfgAddlExpanded = !_cfgAddlExpanded,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final halfWidth = (constraints.maxWidth - 16) / 2;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _addlConfigOptions
                                  .map(
                                    (opt) => SizedBox(
                                      width: halfWidth,
                                      child: _buildCheckboxRow(
                                        opt,
                                        _additionalConfigs.contains(opt),
                                        (v) => setState(
                                          () => v == true
                                              ? _additionalConfigs.add(opt)
                                              : _additionalConfigs.remove(opt),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Utility & Services',
                        isExpanded: _cfgUtilityExpanded,
                        onToggle: () => setState(
                          () => _cfgUtilityExpanded = !_cfgUtilityExpanded,
                        ),
                        child: _buildConfigList(_utilityOptions),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Gas Connection',
                        isExpanded: _cfgGasExpanded,
                        onToggle: () =>
                            setState(() => _cfgGasExpanded = !_cfgGasExpanded),
                        child: _buildConfigList(_gasOptions),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Kitchen Requirements',
                        isExpanded: _cfgKitchenExpanded,
                        onToggle: () => setState(
                          () => _cfgKitchenExpanded = !_cfgKitchenExpanded,
                        ),
                        child: _buildConfigList(_kitchenOptions),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Electrical & Plumbing',
                        isExpanded: _cfgElectricalExpanded,
                        onToggle: () => setState(
                          () =>
                              _cfgElectricalExpanded = !_cfgElectricalExpanded,
                        ),
                        child: _buildConfigList(_electricalOptions),
                      ),
                      const SizedBox(height: 16),
                      _buildAccordionCard(
                        title: 'Terrace & Interior',
                        isExpanded: _cfgTerraceExpanded,
                        onToggle: () => setState(
                          () => _cfgTerraceExpanded = !_cfgTerraceExpanded,
                        ),
                        child: _buildConfigList(_terraceOptions),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Dates, Budget & Status',
                        icon: Icons.calendar_today_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('PROJECT TIMELINE', uppercase: true),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Start Date'),
                                      const SizedBox(height: 8),
                                      _datePicker(
                                        date: _startDate,
                                        hint: 'Select start date',
                                        onSelect: () => _pickDate(
                                          initial: _startDate ?? DateTime.now(),
                                          onPicked: (d) => _startDate = d,
                                        ),
                                        required: true,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Expected End'),
                                      const SizedBox(height: 8),
                                      _datePicker(
                                        date: _expectedEndDate,
                                        hint: 'dd/mm/yyyy',
                                        onSelect: () => _pickDate(
                                          initial:
                                              _expectedEndDate ??
                                              DateTime.now(),
                                          onPicked: (d) => _expectedEndDate = d,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: Color(0xFFEEF0F5),
                                height: 1,
                              ),
                            ),
                            _label('BUDGET BREAKDOWN', uppercase: true),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Material (₹)'),
                                      const SizedBox(height: 8),
                                      _field(
                                        controller: _budgetMaterialCtrl,
                                        hint: '₹ 0',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        maxLength: 10,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d*'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Labour (₹)'),
                                      const SizedBox(height: 8),
                                      _field(
                                        controller: _budgetLabourCtrl,
                                        hint: '₹ 0',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        maxLength: 10,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d*'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Equipment (₹)'),
                                      const SizedBox(height: 8),
                                      _field(
                                        controller: _budgetEquipmentCtrl,
                                        hint: '₹ 0',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        maxLength: 10,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d*'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Misc (₹)'),
                                      const SizedBox(height: 8),
                                      _field(
                                        controller: _budgetMiscCtrl,
                                        hint: '₹ 0',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        maxLength: 10,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d*'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: Color(0xFFEEF0F5),
                                height: 1,
                              ),
                            ),
                            _label('PROJECT STATUS', uppercase: true),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _statusOptions.map((opt) {
                                final isSelected = _projectStatus == opt;
                                final isCancelled = opt == 'Cancelled';
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _projectStatus = opt),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isCancelled
                                                ? const Color(0xFFFFF0F0)
                                                : primaryBlue.withValues(
                                                    alpha: 0.1,
                                                  ))
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isCancelled
                                                  ? Colors.red.withValues(
                                                      alpha: 0.5,
                                                    )
                                                  : primaryBlue)
                                            : const Color(0xFFEEF0F5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      opt,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? (isCancelled
                                                  ? Colors.red
                                                  : primaryBlue)
                                            : textGray,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCsvImportExportCard(),
                      const SizedBox(height: 16),
                      _buildConstructionPhasesCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_saving || _mainBuildingType == null)
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                disabledBackgroundColor: primaryBlue.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Add Project',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _groupContainer({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: primaryBlue),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
  Widget _buildConfigList(List<String> options) {
    return Column(
      children: options
          .map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCheckboxRow(
                opt,
                _additionalConfigs.contains(opt),
                (v) => setState(
                  () => v == true
                      ? _additionalConfigs.add(opt)
                      : _additionalConfigs.remove(opt),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
  Widget _buildAccordionCard({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: textGray,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFEEF0F5)),
                Padding(padding: const EdgeInsets.all(16), child: child),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF0F5)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
  Widget _label(String text, {IconData? icon, bool uppercase = false}) {
    final tw = Text(
      uppercase ? text.toUpperCase() : text,
      style: TextStyle(
        fontSize: uppercase ? 12 : 13,
        fontWeight: FontWeight.w800,
        color: uppercase ? textDark.withValues(alpha: 0.5) : textGray,
        letterSpacing: uppercase ? 1.2 : 0.3,
      ),
    );
    if (icon == null) return tw;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: primaryBlue),
        const SizedBox(width: 6),
        tw,
      ],
    );
  }
  Widget _field({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: textGray.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        counterText: '',
        prefixIcon: icon != null ? Icon(icon, size: 18, color: textGray) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEF0F5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      ),
    );
  }
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    ValueChanged<String?>? onChanged,
  }) {
    final bool disabled = onChanged == null;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF5F5F8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              color: disabled
                  ? textGray.withValues(alpha: 0.3)
                  : textGray.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: disabled ? textGray.withValues(alpha: 0.3) : textGray,
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          items: items
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? primaryBlue : const Color(0xFFEEF0F5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : textGray,
          ),
        ),
      ),
    );
  }
  Widget _buildCounterRow(
    String title,
    int value, {
    required VoidCallback onInc,
    required VoidCallback onDec,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onDec,
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.transparent,
                  child: const Icon(Icons.remove, size: 16, color: textGray),
                ),
              ),
              Container(
                width: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: Color(0xFFEEF0F5), width: 1.5),
                  ),
                ),
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onInc,
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.transparent,
                  child: const Icon(Icons.add, size: 16, color: primaryBlue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildCheckboxRow(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: Color(0xFFDDE0E8), width: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  Widget _datePicker({
    DateTime? date,
    String? hint,
    required VoidCallback onSelect,
    bool required = false,
  }) {
    final bool isEmpty = date == null;
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isEmpty && required)
                ? Colors.red.shade300
                : const Color(0xFFEEF0F5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                date != null
                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                    : (hint ?? 'Select'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: date != null
                      ? textDark
                      : (isEmpty && required
                            ? Colors.red.shade400
                            : textGray.withValues(alpha: 0.5)),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: (isEmpty && required)
                  ? Colors.red.shade300
                  : textGray.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildConstructionPhasesCard() {
    final int total = _phases.fold(0, (s, p) => s + p.allActivities.length);
    final int done = _phases.fold(0, (s, p) => s + p.selectedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'CONSTRUCTION PHASES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      for (var p in _phases) {
                        p.isSelected = true;
                        for (var a in p.allActivities) {
                          a.isSelected = true;
                        }
                      }
                    }),
                    child: const Text(
                      'Select All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '|',
                    style: TextStyle(
                      fontSize: 12,
                      color: textGray.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      for (var p in _phases) {
                        p.isSelected = false;
                        for (var a in p.allActivities) {
                          a.isSelected = false;
                        }
                      }
                    }),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textGray.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select phases and activities required.',
                style: TextStyle(
                  fontSize: 12,
                  color: textGray.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$done of $total activities selected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Column(
          children: List.generate(
            _phases.length,
            (i) => _buildPhaseAccordion(i, _phases[i]),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showAddCustomStageDialog,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '+ Add Custom Phase',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildPhaseAccordion(int index, ConstructionPhase phase) {
    return Container(
      key: ValueKey('phase_${phase.name}_$index'),
      margin: EdgeInsets.only(bottom: index < _phases.length - 1 ? 8 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => phase.isExpanded = !phase.isExpanded),
            borderRadius: phase.isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      phase.isSelected = !phase.isSelected;
                      for (var a in phase.allActivities) {
                        a.isSelected = phase.isSelected;
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: phase.isSelected
                            ? primaryBlue
                            : Colors.transparent,
                        border: Border.all(
                          color: phase.isSelected
                              ? primaryBlue
                              : const Color(0xFFCDD0DA),
                          width: 1.5,
                        ),
                      ),
                      child: phase.isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      phase.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: phase.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: textGray,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: Color(0xFFEEF0F5)),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (_, _) => Material(
                      color: Colors.transparent,
                      shadowColor: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  onReorder: (oldIndex, newIndex) => setState(() {
                    final list = phase.activities;
                    list.insert(newIndex, list.removeAt(oldIndex));
                  }),
                  itemCount: phase.allActivities.length,
                  itemBuilder: (_, idx) {
                    final act = phase.allActivities[idx];
                    return InkWell(
                      key: ValueKey(act.key),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: act.isSelected
                                    ? primaryBlue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: act.isSelected
                                      ? primaryBlue
                                      : const Color(0xFFCDD0DA),
                                  width: 1.5,
                                ),
                              ),
                              child: act.isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                act.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: act.isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: act.isSelected
                                      ? textDark
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: idx,
                              child: const Icon(
                                Icons.drag_indicator_rounded,
                                size: 20,
                                color: Color(0xFFDDE0E8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                GestureDetector(
                  onTap: () => _showAddCustomActivityDialog(phase),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryBlue.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '+ Add Custom Activity',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: phase.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
  void _showAddCustomStageDialog() {
    _customStageNameCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Custom Phase',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: textDark,
          ),
        ),
        content: TextField(
          controller: _customStageNameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDDE0E8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx);
            },
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
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx);
              setState(
                () {
                  final newPhase = ConstructionPhase(name: name, isCustom: true);
                  newPhase.isSelected = true;
                  newPhase.isExpanded = true;
                  _phases.add(newPhase);
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Custom Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: textDark,
          ),
        ),
        content: TextField(
          controller: ctrl,
          focusNode: focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDDE0E8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx);
            },
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
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx);
              setState(
                () => phase.activities.add(
                  ConstructionActivity(
                    key: '${phase.name}::Custom::$name',
                    name: name,
                    isCustom: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
  Widget _buildSubscriptionWarning(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final projectProvider = context.watch<ProjectProvider>();
    final plan = subProvider.currentPlan;
    final maxProjects = plan.maxProjects;
    final currentCount = projectProvider.projects.length;
    if (maxProjects == -1 || currentCount < maxProjects) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${plan.label} Plan Limit Reached: You have $currentCount/$maxProjects projects.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/subscription'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final defaultPhases = buildDefaultPhases();
    for (final phase in defaultPhases) {
      int slNo = 1;
      for (final act in phase.allActivities) {
        csvRows.add([
          phase.name,
          slNo++,
          act.name,
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ]);
      }
    }
    final csvContent = const ListToCsvConverter().convert(csvRows);
    const filename = 'project_phases_budget_template.csv';
    try {
      await saveAndShareCsv(
        csvContent: csvContent,
        filename: filename,
        shareText: 'Exported phase template',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download template: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported budget for $updatedCount activities!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }
  Widget _buildCsvImportExportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PHASES & BUDGET CONFIGURATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textGray,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Import/Export CSV budgets for all phases.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Template'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(
                      color: Color(0xFFEEF0F5),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    foregroundColor: primaryBlue,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isUploadingCsv
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _uploadCsv,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Upload CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
