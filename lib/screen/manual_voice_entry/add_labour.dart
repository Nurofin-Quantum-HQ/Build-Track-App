import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/autocomplete_name_field.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/upload_box.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/models/construction_models.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
class AddLabourScreen extends StatefulWidget {
  const AddLabourScreen({super.key});
  @override
  State<AddLabourScreen> createState() => _AddLabourScreenState();
}
class _AddLabourScreenState extends State<AddLabourScreen> {
  bool _requestEsign = false;
  final TextEditingController _clientEmailCtrl = TextEditingController();
  String? _selectedProjectId;
  String? _selectedFloor;
  String? _selectedFloorId;
  dynamic _selectedPhase;
  String? _selectedPhaseId;
  String? _selectedActivity;
  String? _selectedActivityId;
  Map<String, dynamic>? _duplicateContext;
  bool _isDuplicate = false;
  bool _fromReport = false;
  String? _sourceTransactionId;
  List<String> _floors = [];
  List<String> _phases = [];
  List<String> _activities = [];
  final _nameCtrl = TextEditingController();
  final _workTypeCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _overtimeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedUnit;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _editingTransactionId;
  bool _argsLoaded = false;
  PickedAttachment? _attachment;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _recentEntries = [];
  bool _isAddAndPay = false;
  bool _recordPaymentNow = false;
  Map<String, dynamic>? _paymentResult;
  List<Map<String, dynamic>> _paymentHistory = [];
  final _paymentAmountCtrl = TextEditingController();
  final _paymentNoteCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  double _existingPaidAmount = 0.0;
  final _scrollCtrl = ScrollController();
  String? _nameError;
  String? _qtyError;
  String? _rateError;
  String? _projectError;
  String? _floorError;
  String? _phaseError;
  String? _activityError;
  String? _unitError;
  String? _floorWarning;
  String? _phaseWarning;
  String? _activityWarning;
  String _safeString(dynamic val) {
    if (val == null) return '';
    if (val is String) return val.trim();
    if (val is Map) {
      return (val['name'] ??
              val['title'] ??
              val['phaseName'] ??
              val['id'] ??
              val['_id'] ??
              '')
          .toString()
          .trim();
    }
    return val.toString().trim();
  }
  String _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final val = data[key];
      if (val != null) {
        final str = _safeString(val);
        if (str.isNotEmpty) return str;
      }
    }
    for (final entry in data.entries) {
      final lowerKey = entry.key.toLowerCase();
      for (final searchKey in keys) {
        if (lowerKey == searchKey.toLowerCase()) {
          final str = _safeString(entry.value);
          if (str.isNotEmpty) return str;
        }
      }
    }
    return '';
  }
  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _isEditing = args['isEditing'] as bool? ?? false;
      if (_isEditing && (args['status'] as String?) == 'approved') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.maybePop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approved entries cannot be edited')),
          );
        });
        return;
      }
      if (_isEditing) {
        debugPrint('EDIT RECORD args');
        debugPrint(args.toString());
        _editingTransactionId = args['id']?.toString();
        final txId = _editingTransactionId!;
        final routeData = Map<String, dynamic>.from(args);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchAndRestoreEdit(txId, argsData: routeData);
        });
      } else {
        final projectProvider = Provider.of<ProjectProvider>(
          context,
          listen: false,
        );
        final preProjectId = projectProvider.selectedProject?.id;
        final preFloor = projectProvider.selectedFloor;
        final prePhase = projectProvider.selectedPhase;
        final preActivity = projectProvider.selectedActivity;
        if (preProjectId != null &&
            preProjectId.isNotEmpty &&
            preFloor != null &&
            preFloor.isNotEmpty &&
            prePhase != null &&
            prePhase.isNotEmpty &&
            preActivity != null &&
            preActivity.isNotEmpty) {
          _selectedProjectId = preProjectId;
          _selectedFloor = preFloor;
          _selectedFloorId = preFloor;
          _selectedPhase = prePhase;
          _selectedPhaseId = projectProvider.selectedPhaseId;
          _selectedActivity = preActivity;
          _selectedActivityId = projectProvider.selectedActivityId;
          debugPrint(
            '[AddLabour] Context injected from ProjectProvider: '
            'project=$_selectedProjectId floor=$_selectedFloor '
            'phase=$_selectedPhase activity=$_selectedActivity',
          );
        } else {
          final routeProjectId =
              args['projectId']?.toString() ?? UserSession.projectId;
          final routeFloor = args['floor']?.toString();
          final routePhase = args['phase']?.toString();
          final routeActivity = args['activity']?.toString();
          if (routeProjectId.isNotEmpty &&
              routeFloor != null &&
              routeFloor.isNotEmpty &&
              routePhase != null &&
              routePhase.isNotEmpty &&
              routeActivity != null &&
              routeActivity.isNotEmpty) {
            _selectedProjectId = routeProjectId;
            _selectedFloor = routeFloor;
            _selectedFloorId = args['floorId']?.toString() ?? routeFloor;
            _selectedPhase = routePhase;
            _selectedPhaseId = args['phaseId']?.toString();
            _selectedActivity = routeActivity;
            _selectedActivityId = args['activityId']?.toString();
          } else {
            _selectedProjectId = routeProjectId;
          }
        }
        _isDuplicate = args['isDuplicate'] as bool? ?? false;
        _fromReport = args['fromReport'] as bool? ?? false;
        _sourceTransactionId = args['sourceTransactionId']?.toString();
        final prefill = args['prefill'] as String?;
        if (prefill != null) _nameCtrl.text = prefill;
        if (_isDuplicate && _sourceTransactionId != null) {
          final txId = _sourceTransactionId!;
          final routeData = Map<String, dynamic>.from(args);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fetchAndRestoreDuplicate(txId, argsData: routeData);
          });
        }
      }
      if (args['openPayment'] == true) {
        _isAddAndPay = true;
      }
    } else {
      _selectedProjectId ??= UserSession.projectId;
    }
    if (_selectedProjectId != null && !_isEditing) {
      _loadRecentEntries();
    }
    if (_duplicateContext != null) {
      final contextToRestore = Map<String, dynamic>.from(_duplicateContext!);
      _duplicateContext = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreDuplicateEntry(contextToRestore);
      });
    }
  }
  Future<void> _selectProject(String? projectId) async {
    _selectedProjectId = projectId;
    setState(() {});
  }
  Future<void> _loadFloors(String? projectId) async {
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final ProjectModel? project = projectId == null
        ? null
        : projectProvider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == projectId,
            orElse: () => null,
          );
    const List<String> defaultFloors = [
      'Basement',
      'Ground Floor',
      '1st Floor',
      '2nd Floor',
      '3rd Floor',
      'Terrace',
    ];
    if (project != null) {
      _floors = (project.floors?.isNotEmpty == true)
          ? List<String>.from(project.floors!)
          : defaultFloors;
    } else {
      _floors = [];
    }
  }
  Future<void> _loadPhases(String? floor) async {
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    if (_selectedProjectId != null && _selectedProjectId!.isNotEmpty) {
      await projectProvider.refreshProject(_selectedProjectId!);
    }
    final ProjectModel? project = _selectedProjectId == null
        ? null
        : projectProvider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == _selectedProjectId,
            orElse: () => null,
          );
    if (project == null) {
      _phases = [];
      return;
    }
    final List<String> projectPhaseNames = (project.selectedPhases ??
            const <ProjectPhase>[])
        .where((p) => p.activities.isNotEmpty)
        .map((p) => p.phaseName)
        .toList();
    final List<String> legacyPhaseNames =
        List<String>.from(project.selectedPhaseNames ?? const []);
    final Set<String> mergedPhaseNames = <String>{
      ...projectPhaseNames,
      ...legacyPhaseNames,
    };
    if (mergedPhaseNames.isEmpty) {
      mergedPhaseNames.addAll(buildDefaultPhases().map((p) => p.name));
    }
    _phases = mergedPhaseNames.toList();
  }
  Future<void> _loadActivities(dynamic phase) async {
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final ProjectModel? project = _selectedProjectId == null
        ? null
        : projectProvider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == _selectedProjectId,
            orElse: () => null,
          );
    if (project == null || phase == null) {
      _activities = [];
      return;
    }
    final String phaseName = phase is String
        ? phase
        : (phase is Map
              ? (phase['phaseName'] ?? phase['name'] ?? phase['id'])
                        ?.toString() ??
                    ''
              : phase.toString());
    final List<ProjectPhase>? projectPhases = project.selectedPhases;
    final ProjectPhase? selPhase = phaseName.isEmpty
        ? null
        : (projectPhases ?? const <ProjectPhase>[])
              .cast<ProjectPhase?>()
              .firstWhere((p) => p?.phaseName == phaseName, orElse: () => null);
    if (selPhase != null) {
      _activities = selPhase.activities.map((a) => a.name).toList();
    } else {
      final List<ConstructionPhase> allPhases = buildDefaultPhases();
      final ConstructionPhase? defaultSelPhase = phaseName.isEmpty
          ? null
          : allPhases.cast<ConstructionPhase?>().firstWhere(
              (p) => p?.name == phaseName,
              orElse: () => null,
            );
      _activities = defaultSelPhase != null
          ? defaultSelPhase.allActivities.map<String>((a) => a.name).toList()
          : <String>[];
    }
  }
  String? _derivePhaseId(dynamic phaseNameOrObj) {
    if (_selectedProjectId == null) return null;
    String? phaseName;
    if (phaseNameOrObj is String) {
      phaseName = phaseNameOrObj;
    } else if (phaseNameOrObj is ProjectPhase) {
      return phaseNameOrObj.id;
    } else if (phaseNameOrObj is Map) {
      phaseName = (phaseNameOrObj['phaseName'] ?? phaseNameOrObj['name'])
          ?.toString();
    } else if (phaseNameOrObj != null) {
      phaseName = phaseNameOrObj.toString();
    }
    if (phaseName == null || phaseName.isEmpty) return null;
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.projects.cast<ProjectModel?>().firstWhere(
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
    final projectProvider = context.read<ProjectProvider>();
    final project = projectProvider.projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _selectedProjectId,
      orElse: () => null,
    );
    if (project?.selectedPhases == null) return null;
    for (final p in project!.selectedPhases!) {
      for (final a in p.activities) {
        if (a.name == activityName) return a.id;
      }
    }
    return null;
  }
  Future<void> _fetchAndRestoreEdit(
    String txId, {
    Map<String, dynamic>? argsData,
  }) async {
    debugPrint('');
    debugPrint('========== EDIT ENTRY — LAYER 1: ROUTE ARGS ==========');
    debugPrint('txId: $txId');
    debugPrint('argsData keys: ${argsData?.keys.join(', ') ?? 'null'}');
    if (argsData != null) {
      final pId = argsData['projectId'] ?? argsData['project'];
      if (pId != null) {
        if (pId is Map) {
          _selectedProjectId = (pId['_id'] ?? pId['id'])?.toString();
        } else {
          final idStr = pId.toString().trim();
          _selectedProjectId = idStr.startsWith('{') ? null : idStr;
        }
      }
      _nameCtrl.text = _safeString(
        argsData['title'] ?? argsData['name'] ?? argsData['materialName'],
      );
      final double qty = _parseDouble(argsData['quantity']);
      _qtyCtrl.text = qty > 0
          ? (qty % 1 == 0 ? qty.toInt().toString() : qty.toString())
          : '';
      final double rate = _parseDouble(argsData['rate']);
      _rateCtrl.text = rate > 0
          ? (rate % 1 == 0 ? rate.toInt().toString() : rate.toString())
          : '';
      final rawUnit = _safeString(argsData['unit']).trim().toLowerCase();
      if (rawUnit == 'day' || rawUnit == 'days') {
        _selectedUnit = 'Day';
      } else if (rawUnit == 'hour' || rawUnit == 'hours') {
        _selectedUnit = 'Hour';
      } else if (rawUnit == 'sqft' ||
          rawUnit == 'sq.ft' ||
          rawUnit == 'sq ft') {
        _selectedUnit = 'Sq.ft';
      } else if (rawUnit.isNotEmpty) {
        _selectedUnit = rawUnit[0].toUpperCase() + rawUnit.substring(1);
      }
      final catVal = _safeString(
        argsData['categoryName'] ?? argsData['category'],
      );
      _categoryCtrl.text = catVal;
      _workTypeCtrl.text = _safeString(
        argsData['workType'] ?? argsData['remarks'],
      );
      _notesCtrl.text = _safeString(argsData['notes']);
      double overtimeVal = _parseDouble(argsData['overtime']);
      if (overtimeVal == 0) {
        final double totalAmt = _parseDouble(
          argsData['amount'] ??
              argsData['totalAmount'] ??
              argsData['billAmount'],
        );
        overtimeVal = (totalAmt - (qty * rate)).clamp(0.0, double.infinity);
      }
      _overtimeCtrl.text = overtimeVal > 0
          ? (overtimeVal % 1 == 0
                ? overtimeVal.toInt().toString()
                : overtimeVal.toString())
          : '';
      if (argsData['date'] != null) {
        try {
          _selectedDate = DateTime.parse(argsData['date'].toString());
        } catch (_) {}
      }
      final pStatus =
          argsData['paymentStatus']?.toString().toLowerCase() ??
          argsData['status']?.toString().toLowerCase();
      if (pStatus != null && pStatus != 'pending' && pStatus != '') {
        _isAddAndPay = true;
        _paymentMethod =
            argsData['paymentMode'] ?? argsData['paymentMethod'] ?? 'Cash';
        _existingPaidAmount = _parseDouble(argsData['paidAmount']);
      }
      debugPrint(
        'PREFILL from args done. projectId=$_selectedProjectId name=${_nameCtrl.text}',
      );
    }
    debugPrint(
      '========== LAYER 2: API FETCH (fetchTransactionById) ==========',
    );
    Map<String, dynamic>? apiData;
    if (txId.isNotEmpty) {
      apiData = await ApiService.fetchTransactionById(txId);
      if (apiData != null) {
        debugPrint('API RESPONSE keys: ${apiData.keys.join(', ')}');
        debugPrint('API RESPONSE: ${jsonEncode(apiData)}');
      } else {
        debugPrint('API RESPONSE: null');
      }
    }
    debugPrint('========== LAYER 3: SOURCE SELECTION ==========');
    Map<String, dynamic>? latest;
    if (apiData != null) {
      latest = apiData;
      debugPrint('SOURCE: API fetchTransactionById');
    } else if (argsData != null) {
      latest = argsData;
      debugPrint('SOURCE: argsData (route args)');
    } else {
      debugPrint('SOURCE: NONE — aborting');
      return;
    }
    debugPrint(
      '========== LAYER 4: REPOPULATE CONTROLLERS FROM API ==========',
    );
    _nameCtrl.text = _safeString(
      latest['title'] ?? latest['name'] ?? latest['materialName'],
    );
    final double freshQty = _parseDouble(latest['quantity']);
    _qtyCtrl.text = freshQty > 0
        ? (freshQty % 1 == 0
              ? freshQty.toInt().toString()
              : freshQty.toString())
        : '';
    final double freshRate = _parseDouble(latest['rate']);
    _rateCtrl.text = freshRate > 0
        ? (freshRate % 1 == 0
              ? freshRate.toInt().toString()
              : freshRate.toString())
        : '';
    final freshUnit = _safeString(latest['unit']).trim().toLowerCase();
    if (freshUnit == 'day' || freshUnit == 'days') {
      _selectedUnit = 'Day';
    } else if (freshUnit == 'hour' || freshUnit == 'hours') {
      _selectedUnit = 'Hour';
    } else if (freshUnit == 'sqft' ||
        freshUnit == 'sq.ft' ||
        freshUnit == 'sq ft') {
      _selectedUnit = 'Sq.ft';
    } else if (freshUnit.isNotEmpty) {
      _selectedUnit = freshUnit[0].toUpperCase() + freshUnit.substring(1);
    }
    final catVal = _safeString(latest['categoryName'] ?? latest['category']);
    _categoryCtrl.text = catVal;
    _workTypeCtrl.text = _safeString(latest['workType'] ?? latest['remarks']);
    _notesCtrl.text = _safeString(latest['notes']);
    double freshOvertime = _parseDouble(latest['overtime']);
    if (freshOvertime == 0) {
      final double totalAmount = _parseDouble(
        latest['amount'] ?? latest['totalAmount'],
      );
      freshOvertime = (totalAmount - (freshQty * freshRate)).clamp(
        0.0,
        double.infinity,
      );
    }
    _overtimeCtrl.text = freshOvertime > 0
        ? (freshOvertime % 1 == 0
              ? freshOvertime.toInt().toString()
              : freshOvertime.toString())
        : '';
    if (latest['date'] != null) {
      try {
        _selectedDate = DateTime.parse(latest['date'].toString());
      } catch (_) {}
    }
    final freshPStatus =
        latest['paymentStatus']?.toString().toLowerCase() ??
        latest['status']?.toString().toLowerCase();
    if (freshPStatus != null &&
        freshPStatus != 'pending' &&
        freshPStatus != '') {
      _isAddAndPay = true;
      _paymentMethod =
          latest['paymentMode'] ?? latest['paymentMethod'] ?? 'Cash';
      _existingPaidAmount = _parseDouble(latest['paidAmount']);
    }
    if (latest['paymentHistory'] != null && latest['paymentHistory'] is List) {
      _paymentHistory = List<Map<String, dynamic>>.from(
        (latest['paymentHistory'] as List).map((x) => Map<String, dynamic>.from(x))
      );
    }
    debugPrint('REPOPULATED controllers from API. name=${_nameCtrl.text}');
    final contextToRestore = {
      'projectId': _selectedProjectId,
      'floor': _extractString(latest, [
        'floor',
        'floorName',
        'floor_name',
        'zone',
        'Zone',
      ]),
      'floorId': (latest['floorId'] ?? '').toString(),
      'phase': _extractString(latest, ['phase', 'phaseName', 'phase_name']),
      'phaseId': (latest['phaseId'] ?? '').toString(),
      'activity': _extractString(latest, [
        'activity',
        'activityName',
        'activity_name',
      ]),
      'activityId': (latest['activityId'] ?? '').toString(),
    };
    debugPrint('========== LAYER 5: CONTEXT TO RESTORE ==========');
    debugPrint('contextToRestore: $contextToRestore');
    await _restoreDuplicateEntry(contextToRestore);
  }
  Future<void> _fetchAndRestoreDuplicate(
    String txId, {
    Map<String, dynamic>? argsData,
  }) async {
    debugPrint('');
    debugPrint('========== DUPLICATE ENTRY — LAYER 1: ROUTE ARGS ==========');
    debugPrint('txId: $txId');
    debugPrint('argsData keys: ${argsData?.keys.join(', ') ?? 'null'}');
    if (argsData != null) {
      final pId = argsData['projectId'] ?? argsData['project'];
      if (pId != null) {
        if (pId is Map) {
          _selectedProjectId = (pId['_id'] ?? pId['id'])?.toString();
        } else {
          final idStr = pId.toString().trim();
          _selectedProjectId = idStr.startsWith('{') ? null : idStr;
        }
      }
      _nameCtrl.text = _safeString(
        argsData['title'] ?? argsData['name'] ?? argsData['materialName'],
      );
      final rawUnit = _safeString(argsData['unit']).trim().toLowerCase();
      if (rawUnit == 'day' || rawUnit == 'days') {
        _selectedUnit = 'Day';
      } else if (rawUnit == 'hour' || rawUnit == 'hours') {
        _selectedUnit = 'Hour';
      } else if (rawUnit == 'sqft' ||
          rawUnit == 'sq.ft' ||
          rawUnit == 'sq ft') {
        _selectedUnit = 'Sq.ft';
      } else if (rawUnit.isNotEmpty) {
        _selectedUnit = rawUnit[0].toUpperCase() + rawUnit.substring(1);
      }
      final catVal = _safeString(
        argsData['categoryName'] ?? argsData['category'],
      );
      _categoryCtrl.text = catVal;
      _workTypeCtrl.text = _safeString(
        argsData['workType'] ?? argsData['remarks'],
      );
      _notesCtrl.text = _safeString(argsData['notes']);
      double overtimeVal = _parseDouble(argsData['overtime']);
      final double qtyVal = _parseDouble(argsData['quantity']);
      final double rateVal = _parseDouble(
        argsData['rate'] ?? argsData['dailyWage'] ?? argsData['hourlyRate'],
      );
      if (overtimeVal == 0) {
        final double totalAmt = _parseDouble(
          argsData['amount'] ??
              argsData['totalAmount'] ??
              argsData['billAmount'],
        );
        overtimeVal = (totalAmt - (qtyVal * rateVal)).clamp(
          0.0,
          double.infinity,
        );
      }
      _overtimeCtrl.text = overtimeVal > 0
          ? (overtimeVal % 1 == 0
                ? overtimeVal.toInt().toString()
                : overtimeVal.toString())
          : '';
      if (rateVal > 0) {
        _rateCtrl.text = rateVal % 1 == 0
            ? rateVal.toInt().toString()
            : rateVal.toString();
      }
      debugPrint(
        'PREFILL from args done. projectId=$_selectedProjectId name=${_nameCtrl.text}',
      );
    }
    debugPrint(
      '========== LAYER 2: API FETCH (fetchTransactionById) ==========',
    );
    Map<String, dynamic>? apiData;
    if (txId.isNotEmpty) {
      apiData = await ApiService.fetchTransactionById(txId);
      if (apiData != null) {
        debugPrint('API RESPONSE keys: ${apiData.keys.join(', ')}');
        debugPrint('API RESPONSE: ${jsonEncode(apiData)}');
      } else {
        debugPrint('API RESPONSE: null');
      }
    }
    debugPrint('========== LAYER 3: SOURCE SELECTION ==========');
    Map<String, dynamic>? latest;
    if (apiData != null) {
      latest = apiData;
      debugPrint('SOURCE: API fetchTransactionById');
    } else if (argsData != null) {
      latest = argsData;
      debugPrint('SOURCE: argsData (route args)');
    } else {
      debugPrint('SOURCE: NONE — aborting');
      return;
    }
    debugPrint(
      '========== LAYER 4: REPOPULATE CONTROLLERS FROM API ==========',
    );
    _nameCtrl.text = _safeString(
      latest['title'] ?? latest['name'] ?? latest['materialName'],
    );
    final double freshQty = _parseDouble(latest['quantity']);
    _qtyCtrl.text = freshQty > 0
        ? (freshQty % 1 == 0
              ? freshQty.toInt().toString()
              : freshQty.toString())
        : '';
    final double freshRate = _parseDouble(
      latest['rate'] ?? latest['dailyWage'] ?? latest['hourlyRate'],
    );
    _rateCtrl.text = freshRate > 0
        ? (freshRate % 1 == 0
              ? freshRate.toInt().toString()
              : freshRate.toString())
        : '';
    final freshUnit = _safeString(latest['unit']).trim().toLowerCase();
    if (freshUnit == 'day' || freshUnit == 'days') {
      _selectedUnit = 'Day';
    } else if (freshUnit == 'hour' || freshUnit == 'hours') {
      _selectedUnit = 'Hour';
    } else if (freshUnit == 'sqft' ||
        freshUnit == 'sq.ft' ||
        freshUnit == 'sq ft') {
      _selectedUnit = 'Sq.ft';
    } else if (freshUnit.isNotEmpty) {
      _selectedUnit = freshUnit[0].toUpperCase() + freshUnit.substring(1);
    }
    final catVal = _safeString(latest['categoryName'] ?? latest['category']);
    _categoryCtrl.text = catVal;
    _workTypeCtrl.text = _safeString(latest['workType'] ?? latest['remarks']);
    _notesCtrl.text = _safeString(latest['notes']);
    double freshOvertime = _parseDouble(latest['overtime']);
    if (freshOvertime == 0) {
      final double totalAmount = _parseDouble(
        latest['amount'] ?? latest['totalAmount'],
      );
      freshOvertime = (totalAmount - (freshQty * freshRate)).clamp(
        0.0,
        double.infinity,
      );
    }
    _overtimeCtrl.text = freshOvertime > 0
        ? (freshOvertime % 1 == 0
              ? freshOvertime.toInt().toString()
              : freshOvertime.toString())
        : '';
    if (latest['date'] != null) {
      try {
        _selectedDate = DateTime.parse(latest['date'].toString());
      } catch (_) {}
    }
    if (latest['paymentHistory'] != null && latest['paymentHistory'] is List) {
      _paymentHistory = List<Map<String, dynamic>>.from(
        (latest['paymentHistory'] as List).map((x) => Map<String, dynamic>.from(x))
      );
    }
    debugPrint('REPOPULATED controllers from API. name=${_nameCtrl.text}');
    final contextToRestore = {
      'projectId': _selectedProjectId,
      'floor': _extractString(latest, [
        'floor',
        'floorName',
        'floor_name',
        'zone',
        'Zone',
      ]),
      'floorId': (latest['floorId'] ?? '').toString(),
      'phase': _extractString(latest, ['phase', 'phaseName', 'phase_name']),
      'phaseId': (latest['phaseId'] ?? '').toString(),
      'activity': _extractString(latest, [
        'activity',
        'activityName',
        'activity_name',
      ]),
      'activityId': (latest['activityId'] ?? '').toString(),
    };
    debugPrint('========== LAYER 5: CONTEXT TO RESTORE ==========');
    debugPrint('contextToRestore: $contextToRestore');
    await _restoreDuplicateEntry(contextToRestore);
  }
  Future<void> _restoreDuplicateEntry(Map<String, dynamic> latest) async {
    debugPrint('');
    debugPrint('========== RESTORE DUPLICATE ENTRY ==========');
    debugPrint('RAW INPUT: ${jsonEncode(latest)}');
    debugPrint('INPUT KEYS: ${latest.keys.join(', ')}');
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    if (projectProvider.projects.isEmpty) {
      await projectProvider.load();
    }
    final pId = latest['projectId'] ?? latest['project'];
    String? resolvedProjectId;
    if (pId != null) {
      resolvedProjectId = pId is Map
          ? (pId['_id'] ?? pId['id'])?.toString()
          : pId.toString();
    }
    debugPrint('resolvedProjectId => $resolvedProjectId');
    if (resolvedProjectId != null && resolvedProjectId.isNotEmpty) {
      await projectProvider.refreshProject(resolvedProjectId);
    }
    final String floorName = _extractString(latest, [
      'floor',
      'floorName',
      'floor_name',
      'zone',
      'Zone',
    ]);
    final String floorId = (latest['floorId'] ?? '').toString();
    debugPrint('floorName => "$floorName"');
    debugPrint('floorId   => "$floorId"');
    final String phaseName = _extractString(latest, [
      'phase',
      'phaseName',
      'phase_name',
    ]);
    final String phaseId = (latest['phaseId'] ?? '').toString();
    debugPrint('phaseName => "$phaseName"');
    debugPrint('phaseId   => "$phaseId"');
    final String activityName = _extractString(latest, [
      'activity',
      'activityName',
      'activity_name',
    ]);
    final String activityId = (latest['activityId'] ?? '').toString();
    debugPrint('activityName => "$activityName"');
    debugPrint('activityId   => "$activityId"');
    final ProjectModel? project = resolvedProjectId == null
        ? null
        : projectProvider.projects.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == resolvedProjectId,
            orElse: () => null,
          );
    if (project != null) {
      debugPrint('PROJECT FOUND: ${project.name} (${project.id})');
    } else {
      debugPrint('PROJECT NOT FOUND for ID: $resolvedProjectId');
    }
    await _selectProject(resolvedProjectId);
    debugPrint('PROJECT => $_selectedProjectId');
    _floorWarning = null;
    _phaseWarning = null;
    _activityWarning = null;
    await _loadFloors(resolvedProjectId);
    debugPrint('FLOORS LOADED: $_floors');
    String? resolvedFloor;
    if (floorName.isNotEmpty) {
      resolvedFloor = floorName;
    } else if (floorId.isNotEmpty) {
      resolvedFloor = floorId;
    }
    if (resolvedFloor != null) {
      final floorFound = _floors.any((f) => f.toString() == resolvedFloor);
      if (!floorFound) {
        _floors.insert(0, resolvedFloor);
        _floorWarning =
            '⚠ Previously selected floor "$resolvedFloor" no longer exists.\nPlease select another floor.';
        debugPrint(
          'FLOOR WARNING: "$resolvedFloor" not found — inserted at index 0',
        );
      } else {
        debugPrint('FLOOR "$resolvedFloor" found in project floors');
      }
      _selectedFloor = resolvedFloor;
      _selectedFloorId = floorId.isNotEmpty ? floorId : null;
      debugPrint('FLOOR => $_selectedFloor  FLOOR_ID => $_selectedFloorId');
    } else {
      debugPrint('FLOOR => NO DATA (both name and ID empty)');
    }
    await _loadPhases(_selectedFloor);
    debugPrint('PHASES LOADED: $_phases');
    String? resolvedPhase;
    String? resolvedPhaseId;
    if (phaseName.isNotEmpty) {
      resolvedPhase = phaseName;
      resolvedPhaseId = phaseId.isNotEmpty
          ? phaseId
          : _derivePhaseId(phaseName);
    } else if (phaseId.isNotEmpty && project != null) {
      final phaseObj = project.selectedPhases?.cast<ProjectPhase?>().firstWhere(
        (p) => p?.id == phaseId,
        orElse: () => null,
      );
      if (phaseObj != null) {
        resolvedPhase = phaseObj.phaseName;
        resolvedPhaseId = phaseId;
        debugPrint('RESOLVED PHASE NAME from ID $phaseId => "$resolvedPhase"');
      } else {
        resolvedPhase = phaseId;
        resolvedPhaseId = phaseId;
        debugPrint(
          'PHASE ID $phaseId not found in project data — using ID as display',
        );
      }
    }
    if (resolvedPhase != null) {
      final phaseFound = _phases.any((p) => p.toString() == resolvedPhase);
      if (!phaseFound) {
        _phases.insert(0, resolvedPhase);
        _phaseWarning =
            '⚠ Previously selected phase "$resolvedPhase" no longer exists.\nPlease select another phase.';
        debugPrint(
          'PHASE WARNING: "$resolvedPhase" not found — inserted at index 0',
        );
      } else {
        debugPrint('PHASE "$resolvedPhase" found in project phases');
      }
      _selectedPhase = resolvedPhase;
      _selectedPhaseId = resolvedPhaseId;
      debugPrint('PHASE => $_selectedPhase  PHASE_ID => $_selectedPhaseId');
    } else {
      debugPrint('PHASE => NO DATA (both name and ID empty)');
    }
    await _loadActivities(_selectedPhase);
    debugPrint('ACTIVITIES LOADED: $_activities');
    String? resolvedActivity;
    String? resolvedActivityId;
    if (activityName.isNotEmpty) {
      resolvedActivity = activityName;
      resolvedActivityId = activityId.isNotEmpty
          ? activityId
          : _deriveActivityId(activityName);
    } else if (activityId.isNotEmpty && project != null) {
      String? found;
      for (final phase in project.selectedPhases ?? []) {
        for (final act in phase.activities) {
          if (act.id == activityId) {
            found = act.name;
            break;
          }
        }
        if (found != null) break;
      }
      if (found != null) {
        resolvedActivity = found;
        resolvedActivityId = activityId;
        debugPrint(
          'RESOLVED ACTIVITY NAME from ID $activityId => "$resolvedActivity"',
        );
      } else {
        resolvedActivity = activityId;
        resolvedActivityId = activityId;
        debugPrint(
          'ACTIVITY ID $activityId not found in project data — using ID as display',
        );
      }
    }
    if (resolvedActivity != null) {
      final activityFound = _activities.any(
        (a) => a.toString() == resolvedActivity,
      );
      if (!activityFound) {
        _activities.insert(0, resolvedActivity);
        _activityWarning =
            '⚠ Previously selected activity "$resolvedActivity" no longer exists.\nPlease select another activity.';
        debugPrint(
          'ACTIVITY WARNING: "$resolvedActivity" not found — inserted at index 0',
        );
      } else {
        debugPrint('ACTIVITY "$resolvedActivity" found in project activities');
      }
      _selectedActivity = resolvedActivity;
      _selectedActivityId = resolvedActivityId;
      debugPrint(
        'ACTIVITY => $_selectedActivity  ACTIVITY_ID => $_selectedActivityId',
      );
    } else {
      debugPrint('ACTIVITY => NO DATA (both name and ID empty)');
    }
    if (resolvedFloor != null && !_floors.any((f) => f == resolvedFloor)) {
      debugPrint(
        '!!! TYPE/STRING MISMATCH: floor "$resolvedFloor" not in _floors after insert',
      );
    }
    if (resolvedPhase != null && !_phases.any((p) => p == resolvedPhase)) {
      debugPrint(
        '!!! TYPE/STRING MISMATCH: phase "$resolvedPhase" not in _phases after insert',
      );
    }
    if (resolvedActivity != null &&
        !_activities.any((a) => a == resolvedActivity)) {
      debugPrint(
        '!!! TYPE/STRING MISMATCH: activity "$resolvedActivity" not in _activities after insert',
      );
    }
    debugPrint('========== RESTORATION COMPLETE ==========');
    debugPrint('PROJECT => $_selectedProjectId');
    debugPrint('FLOOR   => $_selectedFloor  ($_selectedFloorId)');
    debugPrint('PHASE   => $_selectedPhase  ($_selectedPhaseId)');
    debugPrint('ACTIVITY => $_selectedActivity  ($_selectedActivityId)');
    debugPrint('');
    setState(() {});
  }
  @override
  void dispose() {
    _nameCtrl.dispose();
    _workTypeCtrl.dispose();
    _categoryCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _overtimeCtrl.dispose();
    _notesCtrl.dispose();
    _paymentAmountCtrl.dispose();
    _paymentNoteCtrl.dispose();
    _scrollCtrl.dispose();
    _clientEmailCtrl.dispose();
    super.dispose();
  }
  double _totalCost() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final overtime = double.tryParse(_overtimeCtrl.text) ?? 0;
    return (qty * rate) + overtime;
  }
  void _scrollToFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  bool _validate() {
    debugPrint(
      '[VALIDATE] projectId=$_selectedProjectId floor=$_selectedFloor phase=$_selectedPhase activity=$_selectedActivity unit=$_selectedUnit',
    );
    bool ok = true;
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty
          ? 'Worker / team name is required'
          : null;
      final qty = double.tryParse(_qtyCtrl.text);
      _qtyError = (qty == null || qty <= 0) ? 'Enter valid quantity > 0' : null;
      final rate = double.tryParse(_rateCtrl.text);
      _rateError = (rate == null || rate <= 0) ? 'Enter valid rate > 0' : null;
      _projectError = _selectedProjectId == null
          ? 'Please select a Project.'
          : null;
      _floorError = _selectedFloor == null
          ? 'Please select a Floor / Zone.'
          : null;
      _phaseError = _selectedPhase == null ? 'Please select a Phase.' : null;
      _activityError = _selectedActivity == null || _selectedActivity!.isEmpty
          ? 'Please select an Activity.'
          : null;
      _unitError = _selectedUnit == null ? 'Please select a Unit.' : null;
      ok =
          _nameError == null &&
          _qtyError == null &&
          _rateError == null &&
          _projectError == null &&
          _floorError == null &&
          _phaseError == null &&
          _activityError == null &&
          _unitError == null;
    });
    if (!ok) _scrollToFirstError();
    return ok;
  }
  Future<void> _save(BuildContext ctx) async {
    if (!_validate()) return;
    setState(() => _isSaving = true);
    final payload = {
      "title": _nameCtrl.text.trim(),
      "type": "Wages",
      "category": _categoryCtrl.text.trim(),
      "quantity": double.tryParse(_qtyCtrl.text) ?? 0,
      "rate": double.tryParse(_rateCtrl.text) ?? 0,
      "unit": _selectedUnit == null
          ? "hour"
          : _selectedUnit == "Day" || _selectedUnit == "day"
          ? "day"
          : _selectedUnit == "Hour" || _selectedUnit == "hour"
          ? "hour"
          : _selectedUnit == "Sq ft" ||
                _selectedUnit == "sqft" ||
                _selectedUnit == "Sq.ft"
          ? "sqft"
          : "unit",
      "project": _selectedProjectId,
      "date": _selectedDate.toUtc().toIso8601String(),
      "floor": _selectedFloor,
      "floorId": _selectedFloorId,
      "phase": _selectedPhase,
      "phaseId":
          _selectedPhaseId ??
          (_selectedPhase != null ? _derivePhaseId(_selectedPhase) : null),
      if (_selectedActivity != null && _selectedActivity!.isNotEmpty)
        "activity": _selectedActivity,
      "activityId":
          _selectedActivityId ??
          (_selectedActivity != null && _selectedActivity!.isNotEmpty
              ? _deriveActivityId(_selectedActivity)
              : null),
      "amount": _totalCost(),
      "overtime": double.tryParse(_overtimeCtrl.text) ?? 0,
      "remarks": _workTypeCtrl.text.trim(),
      "notes": _notesCtrl.text.trim(),
      if (_sourceTransactionId != null)
        "sourceTransactionId": _sourceTransactionId,
    };
    if (_isEditing) {
      if (_paymentHistory.isNotEmpty) {
        payload["paymentHistory"] = _paymentHistory.map((p) {
          final rawDate = p['date'] ?? p['paymentDate'];
          String finalDate = DateTime.now().toUtc().toIso8601String();
          if (rawDate is DateTime) {
            finalDate = rawDate.toUtc().toIso8601String();
          } else if (rawDate != null) {
            finalDate = rawDate.toString();
          }
          return {
            "date": finalDate,
            "method": p['method'] ?? p['paymentMode'] ?? 'Cash',
            "amount": _parseDouble(p['amount']),
            "note": p['note'] ?? '',
            "receipt": p['receipt'] ?? p['receiptDataUri'] ?? '',
          };
        }).toList();
      } else {
        payload["paymentHistory"] = [];
      }
    } else if (_isAddAndPay) {
      final paid = _parseDouble(_paymentAmountCtrl.text);
      final totalPaid = _existingPaidAmount + paid;
      final outstanding = (_totalCost() - _existingPaidAmount).clamp(
        0.0,
        double.infinity,
      );
      if (paid > outstanding) {
        _snack('Payment amount cannot exceed the outstanding amount.');
        setState(() => _isSaving = false);
        return;
      }
      String apiMode = _paymentMethod;
      if (apiMode == 'Bank Transfer') apiMode = 'Bank Transfer';
      payload["paidAmount"] = totalPaid;
      payload["paymentMode"] = apiMode;
      final bool esignReq = (_paymentResult!['requestEsign'] as bool?) ?? false;
      if (apiMode == 'Cash' && esignReq) {
        payload['requestEsign'] = true;
        payload['clientEmail'] = (_paymentResult!['clientEmail'] as String?) ?? '';
      }
      if (apiMode == 'Cash' && _requestEsign) {
        payload['requestEsign'] = true;
        payload['clientEmail'] = _clientEmailCtrl.text.trim();
      }
      payload["paymentStatus"] = totalPaid >= _totalCost()
          ? "Paid"
          : totalPaid > 0
          ? "Partial"
          : "Pending";
      payload["paymentDate"] = DateTime.now().toUtc().toIso8601String();
      if (_paymentNoteCtrl.text.trim().isNotEmpty) {
        payload["notes"] = _paymentNoteCtrl.text.trim();
      }
    } else if (_recordPaymentNow && _paymentResult != null) {
      final paid = (_paymentResult!['amount'] as double?) ?? 0.0;
      final totalPaid = _existingPaidAmount + paid;
      final outstanding = (_totalCost() - _existingPaidAmount).clamp(
        0.0,
        double.infinity,
      );
      if (paid > outstanding) {
        _snack('Payment amount cannot exceed the outstanding amount.');
        setState(() => _isSaving = false);
        return;
      }
      final method = (_paymentResult!['method'] as String?) ?? 'Cash';
      final payDate =
          (_paymentResult!['paymentDate'] as DateTime?) ?? DateTime.now();
      String apiMode = method;
      if (apiMode == 'Bank Transfer') apiMode = 'Bank Transfer';
      payload["paidAmount"] = totalPaid;
      payload["paymentMode"] = apiMode;
      final bool esignReq = (_paymentResult!['requestEsign'] as bool?) ?? false;
      if (apiMode == 'Cash' && esignReq) {
        payload['requestEsign'] = true;
        payload['clientEmail'] = (_paymentResult!['clientEmail'] as String?) ?? '';
      }
      payload["paymentStatus"] = totalPaid >= _totalCost()
          ? "Paid"
          : totalPaid > 0
          ? "Partial"
          : "Pending";
      payload["paymentDate"] = payDate.toUtc().toIso8601String();
      if ((_paymentResult!['note'] as String?)?.isNotEmpty == true) {
        payload["notes"] = _paymentResult!['note'];
      }
      final receiptDataUri = _paymentResult!['receiptDataUri'] as String?;
      if (receiptDataUri != null && receiptDataUri.isNotEmpty) {
        payload["paymentReceipt"] = receiptDataUri;
      }
    }
    if (_attachment != null) {
      payload["attachments"] = [_attachment!.dataUri];
    }
    debugPrint('===== SAVE PAYLOAD =====');
    debugPrint(payload.toString());
    debugPrint('========================');
    debugPrint(
      'SAVE PATH CHECK: _isEditing=$_isEditing  _editingTransactionId=$_editingTransactionId  condition=${_isEditing && _editingTransactionId != null}',
    );
    final bool success;
    if (_isEditing && _editingTransactionId != null) {
      debugPrint('>>> SAVE PATH: updateTransaction($_editingTransactionId)');
      success = await ApiService.updateTransaction(
        _editingTransactionId!,
        payload,
      );
    } else {
      debugPrint(
        '>>> SAVE PATH: addMaterial (CREATE NEW) — WARNING: not updating!',
      );
      success = await ApiService.addMaterial(payload);
    }
    if (!mounted) return;
    if (success) {
      context.read<InventoryProvider>().loadInventory(_selectedProjectId!);
      context.read<ProjectProvider>().load();
      _snack(
        _isEditing
            ? 'Labour entry updated successfully!'
            : 'Labour entry saved successfully!',
      );
      if (_fromReport) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/reports',
          (route) => route.settings.name == '/' || route.isFirst,
        );
      } else if (UserSession.hasPermission('view_inventory')) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/inventory',
          (route) => route.settings.name == '/' || route.isFirst,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/add-entry',
          (route) => route.settings.name == '/' || route.isFirst,
        );
      }
    } else {
      _snack('Error saving to server. Please try again.');
    }
    setState(() => _isSaving = false);
  }
  Widget _buildPaymentSection() {
    return EntrySectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF15803D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Payment History' : 'Pay Now',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEditing ? 'Manage payments for this entry' : 'Optionally log payment while adding',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isEditing) Switch(
                value: _recordPaymentNow,
                activeThumbColor: AppColors.primary,
                onChanged: (v) async {
                  if (v) {
                    final result = await showPaymentSheet(
                      context,
                      entryTitle: _nameCtrl.text.trim().isEmpty
                          ? 'Labour'
                          : _nameCtrl.text.trim(),
                      entryRef: '',
                      totalAmount: _totalCost(),
                      alreadyPaid: _existingPaidAmount,
                      vendorName: '',
                      category: _categoryCtrl.text.trim().isEmpty
                          ? 'Labour'
                          : _categoryCtrl.text.trim(),
                    );
                    if (mounted) {
                      setState(() {
                        if (result != null) {
                          _recordPaymentNow = true;
                          _paymentResult = result;
                        }
                      });
                    }
                  } else {
                    setState(() {
                      _recordPaymentNow = false;
                      _paymentResult = null;
                    });
                  }
                },
              ),
            ],
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Request E-Signature for Cash Receipt'),
              value: _requestEsign,
              onChanged: (val) => setState(() => _requestEsign = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_requestEsign)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: TextFormField(
                  controller: _clientEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Client Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
          if (!_isEditing && _recordPaymentNow && _paymentResult != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0EEF8)),
            const SizedBox(height: 12),
            _buildPaymentSummary(),
          ],
          if (_isEditing) ...[
            const SizedBox(height: 16),
            if (_paymentHistory.isNotEmpty) ...[
              const Divider(color: Color(0xFFF0EEF8)),
              const SizedBox(height: 12),
              ..._paymentHistory.asMap().entries.map((entry) {
                final idx = entry.key;
                final payment = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: _buildHistoryItem(payment, idx),
                );
              }),
            ],
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final result = await showPaymentSheet(
                    context,
                    entryTitle: _nameCtrl.text.trim().isEmpty
                        ? 'Labour'
                        : _nameCtrl.text.trim(),
                    entryRef: '',
                    totalAmount: _totalCost(),
                    alreadyPaid: _calculateTotalPaidFromHistory(),
                    vendorName: '',
                    category: _categoryCtrl.text.trim().isEmpty
                        ? 'Labour'
                        : _categoryCtrl.text.trim(),
                  );
                  if (result != null && mounted) {
                    setState(() {
                      _paymentHistory.add(result);
                    });
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Payment'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  double _calculateTotalPaidFromHistory() {
    double total = 0.0;
    for (var p in _paymentHistory) {
      total += _parseDouble(p['amount']);
    }
    return total;
  }
  Widget _buildHistoryItem(Map<String, dynamic> payment, int index) {
    final amount = _parseDouble(payment['amount']);
    final method = (payment['method'] ?? payment['paymentMode'] ?? 'Cash').toString();
    DateTime payDate = DateTime.now();
    if (payment['date'] != null) {
      try {
        payDate = DateTime.parse(payment['date'].toString());
      } catch (_) {}
    } else if (payment['paymentDate'] != null) {
      try {
        payDate = payment['paymentDate'] as DateTime;
      } catch (_) {}
    }
    final note = (payment['note'] ?? '').toString();
    return GestureDetector(
      onTap: () async {
        final result = await showPaymentSheet(
          context,
          entryTitle: _nameCtrl.text.trim().isEmpty
              ? 'Labour'
              : _nameCtrl.text.trim(),
          entryRef: '',
          totalAmount: _totalCost(),
          alreadyPaid: _calculateTotalPaidFromHistory() - amount,
          vendorName: '',
          category: _categoryCtrl.text.trim().isEmpty
              ? 'Labour'
              : _categoryCtrl.text.trim(),
          initialAmount: amount,
          initialMethod: method,
          initialNote: note,
          initialDate: payDate,
        );
        if (result != null && mounted) {
          setState(() {
            _paymentHistory[index] = result;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Payment',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _paymentHistory.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _summaryChip(
                    Icons.currency_rupee,
                    '₹${amount.toStringAsFixed(0)}',
                    'Amount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(Icons.payment_outlined, method, 'Method'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(
                    Icons.calendar_today_outlined,
                    '${payDate.day}/${payDate.month}/${payDate.year}',
                    'Date',
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: $note',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildPaymentSummary() {
    final amount = (_paymentResult!['amount'] as double?) ?? 0.0;
    final method = (_paymentResult!['method'] as String?) ?? 'Cash';
    final payDate =
        (_paymentResult!['paymentDate'] as DateTime?) ?? DateTime.now();
    final note = (_paymentResult!['note'] as String?) ?? '';
    return GestureDetector(
      onTap: () async {
        final savedOffset = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
        final result = await showPaymentSheet(
          context,
          entryTitle: _nameCtrl.text.trim().isEmpty
              ? 'Labour'
              : _nameCtrl.text.trim(),
          entryRef: '',
          totalAmount: _totalCost(),
          alreadyPaid: _existingPaidAmount,
          vendorName: '',
          category: _categoryCtrl.text.trim().isEmpty
              ? 'Labour'
              : _categoryCtrl.text.trim(),
        );
        if (result != null && mounted) {
          setState(() => _paymentResult = result);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.jumpTo(
                savedOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
              );
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Payment Recorded',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Tap to edit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _summaryChip(
                    Icons.currency_rupee,
                    '₹${amount.toStringAsFixed(0)}',
                    'Amount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(Icons.payment_outlined, method, 'Method'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(
                    Icons.calendar_today_outlined,
                    '${payDate.day}/${payDate.month}/${payDate.year}',
                    'Date',
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: $note',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _summaryChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 11, color: const Color(0xFF15803D)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
  void _showRecentEntriesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.60,
          minChildSize: 0.40,
          maxChildSize: 0.90,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Labour Entries',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${_recentEntries.length} similar entr${_recentEntries.length == 1 ? "y" : "ies"} found',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Divider(color: Color(0xFFF0EEF8)),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _recentEntries.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final tx = _recentEntries[i] as Map<String, dynamic>;
                        final String title =
                            tx['title']?.toString() ?? 'Untitled';
                        final double rate =
                            (tx['rate'] as num?)?.toDouble() ?? 0.0;
                        final String unit = tx['unit']?.toString() ?? '';
                        final String category =
                            tx['category']?.toString() ?? '';
                        final String workType =
                            tx['workType']?.toString() ??
                            tx['remarks']?.toString() ??
                            '';
                        String dateStr = '';
                        final rawDate = tx['date'] ?? tx['createdAt'];
                        if (rawDate != null) {
                          try {
                            final d = DateTime.parse(rawDate.toString());
                            dateStr =
                                '${d.day} ${_monthName(d.month)} ${d.year}';
                          } catch (_) {}
                        }
                        final String rateStr = rate > 0
                            ? '₹${rate % 1 == 0 ? rate.toInt() : rate}/$unit'
                            : '';
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(ctx);
                              _prefillFromRecent(tx);
                              _snack('Prefilled from "$title"');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFEEEFF8),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.people_outlined,
                                      color: Color(0xFF2E7D32),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          [
                                            if (rateStr.isNotEmpty) rateStr,
                                            if (category.isNotEmpty) category,
                                            if (workType.isNotEmpty) workType,
                                            if (dateStr.isNotEmpty) dateStr,
                                          ].join(' · '),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textLight,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2E7D32,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Use',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _loadRecentEntries() async {
    if (_selectedProjectId == null) {
      setState(() {
        _recentEntries = [];
      });
      return;
    }
    final recentTxs = await ApiService.fetchRecentTransactions(
      projectId: _selectedProjectId!,
      type: 'Wages',
      userId: UserSession.userId,
    );
    if (mounted) {
      setState(() {
        _recentEntries = recentTxs.take(5).toList();
      });
    }
  }
  void _prefillFromRecent(Map<String, dynamic> tx) {
    setState(() {
      _nameCtrl.text = tx['title']?.toString() ?? '';
      final rawUnit = (tx['unit'] ?? '').toString().trim().toLowerCase();
      if (rawUnit == 'day' || rawUnit == 'days') {
        _selectedUnit = 'Day';
      } else if (rawUnit == 'hour' || rawUnit == 'hours') {
        _selectedUnit = 'Hour';
      } else if (rawUnit == 'sqft' ||
          rawUnit == 'sq.ft' ||
          rawUnit == 'sq ft') {
        _selectedUnit = 'Sq.ft';
      } else if (rawUnit.isNotEmpty) {
        _selectedUnit = rawUnit[0].toUpperCase() + rawUnit.substring(1);
      }
      final catVal = tx['category']?.toString() ?? '';
      _categoryCtrl.text = catVal;
      _workTypeCtrl.text = tx['remarks']?.toString() ?? '';
      final double rateVal = (tx['rate'] as num?)?.toDouble() ?? 0.0;
      _rateCtrl.text = rateVal > 0
          ? (rateVal % 1 == 0 ? rateVal.toInt().toString() : rateVal.toString())
          : '';
      _existingPaidAmount = 0.0;
      _isAddAndPay = false;
      _recordPaymentNow = false;
      _paymentResult = null;
      _paymentHistory.clear();
      _paymentAmountCtrl.clear();
    });
  }
  String _monthName(int month) {
    const months = [
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
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
  @override
  Widget build(BuildContext context) {
    context.watch<ProjectProvider>().projects;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.gradientStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: _isEditing
                  ? 'Modify Labour Log'
                  : _isDuplicate
                  ? 'Repeat Entry'
                  : 'Log Labour Force',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey('add_labour_scroll'),
                controller: _scrollCtrl,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditing || _isDuplicate) ...[
                      ExecutionContextCard(
                        selectedProjectId: _selectedProjectId,
                        selectedFloor: _selectedFloor,
                        selectedPhase: _selectedPhase,
                        selectedActivity: _selectedActivity,
                        projectError: _projectError,
                        floorError: _floorError,
                        phaseError: _phaseError,
                        activityError: _activityError,
                        onProjectChanged: (v) async {
                          setState(() {
                            _selectedProjectId = v;
                            _selectedFloor = null;
                            _selectedFloorId = null;
                            _selectedPhase = null;
                            _selectedPhaseId = null;
                            _selectedActivity = null;
                            _selectedActivityId = null;
                            _projectError = null;
                            _floorWarning = null;
                            _phaseWarning = null;
                            _activityWarning = null;
                          });
                          await _loadFloors(v);
                          setState(() {});
                        },
                        onFloorChanged: (v) async {
                          setState(() {
                            _selectedFloor = v?.toString();
                            _selectedFloorId = v?.toString();
                            _selectedPhase = null;
                            _selectedPhaseId = null;
                            _selectedActivity = null;
                            _selectedActivityId = null;
                            _floorError = null;
                            _floorWarning = null;
                            _phaseWarning = null;
                            _activityWarning = null;
                          });
                          await _loadPhases(v);
                          setState(() {});
                        },
                        onPhaseChanged: (v) async {
                          final phaseName = v?.toString();
                          setState(() {
                            _selectedPhase = phaseName;
                            _selectedPhaseId = phaseName != null
                                ? _derivePhaseId(phaseName)
                                : null;
                            _selectedActivity = null;
                            _selectedActivityId = null;
                            _phaseError = null;
                            _phaseWarning = null;
                            _activityWarning = null;
                          });
                          await _loadActivities(v);
                          setState(() {});
                        },
                        onActivityChanged: (v) {
                          final actName = v?.toString();
                          setState(() {
                            _selectedActivity = actName;
                            _selectedActivityId = actName != null
                                ? _deriveActivityId(actName)
                                : null;
                            _activityError = null;
                            _activityWarning = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_floorWarning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFE65100),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _floorWarning!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFBF360C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_phaseWarning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFE65100),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _phaseWarning!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFBF360C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_activityWarning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFE65100),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _activityWarning!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFBF360C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    EntrySectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const EntryCardHeader(
                            icon: Icons.people_outline,
                            title: 'Labour Entry',
                            subtitle:
                                'Date · Labour Type · Unit · Qty · Rate · Amount',
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFF0EEF8)),
                          const SizedBox(height: 16),
                          const EntryFieldLabel('Date', required: true),
                          const SizedBox(height: 8),
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
                                      primary: AppColors.primary,
                                      onPrimary: Colors.white,
                                      onSurface: AppColors.textDark,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (!mounted) return;
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    _selectedDate.hour,
                                    _selectedDate.minute,
                                    _selectedDate.second,
                                  );
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF173EEA),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Labour Type', required: true),
                          const SizedBox(height: 8),
                          AutocompleteNameField(
                            controller: _nameCtrl,
                            hint: 'e.g. Mason, Carpenter, Steel Fixer',
                            suggestions: const [],
                            onChanged: (_) => setState(() => _nameError = null),
                            onSuggestionSelected: _prefillFromRecent,
                            errorText: _nameError,
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Unit', required: true),
                          const SizedBox(height: 8),
                          UnitSelectorField(
                            value: _selectedUnit,
                            units: kLabourUnits,
                            hint: 'Select unit (e.g. Day, Hour, Sq ft)',
                            onChanged: (u) => setState(() {
                              _selectedUnit = u;
                              _unitError = null;
                            }),
                            error: _unitError,
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Quantity', required: true),
                          const SizedBox(height: 8),
                          EntryUnderlineField(
                            controller: _qtyCtrl,
                            hint: '0',
                            suffix: _selectedUnit ?? 'Unit',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _qtyError = null),
                            error: _qtyError,
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Rate (₹)', required: true),
                          const SizedBox(height: 8),
                          EntryUnderlineField(
                            controller: _rateCtrl,
                            hint: '0',
                            prefix: '₹',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _rateError = null),
                            error: _rateError,
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Amount (₹)'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCDD1F0),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.currency_rupee_rounded,
                                  size: 16,
                                  color: Color(0xFF173EEA),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (() {
                                    final qty =
                                        double.tryParse(_qtyCtrl.text) ?? 0;
                                    final rate =
                                        double.tryParse(_rateCtrl.text) ?? 0;
                                    final sub = qty * rate;
                                    return sub > 0
                                        ? sub.toStringAsFixed(
                                            sub % 1 == 0 ? 0 : 2,
                                          )
                                        : '—';
                                  })(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF173EEA),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E3FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Auto',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF173EEA),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Color(0xFFF0EEF8)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  'OPTIONAL DETAILS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textLight,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Color(0xFFF0EEF8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const EntryFieldLabel('Trade / Work Type (Optional)'),
                          const SizedBox(height: 8),
                          EntryUnderlineField(
                            controller: _workTypeCtrl,
                            hint: 'e.g. Masonry, Barbending, Concrete Crew',
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Contractor / Team (Optional)'),
                          const SizedBox(height: 8),
                          EntryUnderlineField(
                            controller: _categoryCtrl,
                            hint: 'e.g. Vertex Infra Contractors',
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Overtime Amount (Optional)'),
                          const SizedBox(height: 8),
                          EntryUnderlineField(
                            controller: _overtimeCtrl,
                            hint: '0',
                            prefix: '₹',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          const EntryFieldLabel('Notes (Optional)'),
                          const SizedBox(height: 8),
                          EntryNotesField(controller: _notesCtrl),
                        ],
                      ),
                    ),
                    CostSummaryCard(
                      totalAmount: _totalCost(),
                      label: 'Calculated Operational Labor Budget',
                      subtotals: [
                        (
                          'Qty × Rate',
                          '${_qtyCtrl.text.isEmpty ? "—" : _qtyCtrl.text} ${_selectedUnit ?? "Unit"} × ₹${_rateCtrl.text.isEmpty ? "—" : _rateCtrl.text}',
                        ),
                        (
                          'Overtime',
                          '₹ ${_overtimeCtrl.text.isEmpty ? "0" : _overtimeCtrl.text}',
                        ),
                      ],
                    ),
                    EntrySectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const EntryCardHeader(
                            icon: Icons.receipt_long_outlined,
                            title: 'Invoice / Bill',
                            subtitle:
                                'Attach invoice, bill, or supporting document (optional)',
                          ),
                          const SizedBox(height: 16),
                          UploadBox(
                            attachment: _attachment,
                            emptyLabel: 'Tap to upload invoice / bill',
                            onPicked: (a) => setState(() => _attachment = a),
                            onRemove: () => setState(() => _attachment = null),
                          ),
                        ],
                      ),
                    ),
                    if (RoleManager.canApprovePayments)
                      _buildPaymentSection(),
                    const SizedBox(height: 4),
                    if (_selectedProjectId != null &&
                        !_isEditing) ...[
                      if (_recentEntries.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _showRecentEntriesSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD1EDD4),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: Color(0xFF2E7D32),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Recent Labour Entries',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_recentEntries.length} similar entr${_recentEntries.length == 1 ? "y" : "ies"} found · Tap to view',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textLight,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textLight,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    EntrySubmitButton(
                      label: RoleManager.canApprovePayments
                          ? 'Save Labour Entry'
                          : 'Submit to Supervisor',
                      icon: Icons.check_circle,
                      isLoading: _isSaving,
                      onTap: () => _save(context),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
