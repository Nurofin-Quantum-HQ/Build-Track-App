import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/widgets/autocomplete_name_field.dart';
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
  String? _selectedProjectId;
  String? _selectedFloor;
  String? _selectedFloorId;
  dynamic _selectedPhase;
  String? _selectedPhaseId;
  String? _selectedActivity;
  String? _selectedActivityId;
  Map<String, dynamic>? _duplicateContext;
  bool _isDuplicate = false;
  /// Where to go after saving (route arg from the entry flow; see finishEntrySave).
  String? _entryExit;
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
      if (_isEditing &&
          ((args['status'] ?? args['approvalStatus'])?.toString().toLowerCase() == 'approved')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.maybePop(context);
          btToast(context, 'Approved entries cannot be edited', error: true);
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
            prePhase != null &&
            prePhase.isNotEmpty) { // activity is optional
          _selectedProjectId = preProjectId;
          // Projects without floors have no floor; phase/activity still apply.
          _selectedFloor = (preFloor != null && preFloor.isNotEmpty) ? preFloor : null;
          _selectedFloorId = _selectedFloor;
          _selectedPhase = prePhase;
          _selectedPhaseId = projectProvider.selectedPhaseId;
          _selectedActivity = (preActivity != null && preActivity.isNotEmpty) ? preActivity : null;
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
              routePhase != null &&
              routePhase.isNotEmpty) { // activity is optional
            _selectedProjectId = routeProjectId;
            _selectedFloor = (routeFloor != null && routeFloor.isNotEmpty) ? routeFloor : null;
            _selectedFloorId = _selectedFloor == null ? null : (args['floorId']?.toString() ?? routeFloor);
            _selectedPhase = routePhase;
            _selectedPhaseId = args['phaseId']?.toString();
            _selectedActivity = (routeActivity != null && routeActivity.isNotEmpty) ? routeActivity : null;
            _selectedActivityId = args['activityId']?.toString();
          } else {
            _selectedProjectId = routeProjectId;
          }
        }
        _isDuplicate = args['isDuplicate'] as bool? ?? false;
        _entryExit = args['entryExit']?.toString();
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
          );    if (project != null && project.floors != null) {
      _floors = List<String>.from(project.floors!);
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
      if (argsData['date'] != null) {
        try {
          _selectedDate = DateTime.parse(argsData['date'].toString()).toLocal();
        } catch (_) {}
      }
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
    if (latest['date'] != null) {
      try {
        _selectedDate = DateTime.parse(latest['date'].toString()).toLocal();
      } catch (_) {}
    }
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
    
    // A repeat is a new entry: never carry the source entry's payments over.
    _paymentHistory = [];
    _existingPaidAmount = 0.0;
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
      if (_floors.isNotEmpty) {
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
        _selectedFloor = null;
        _selectedFloorId = null;
        debugPrint('FLOOR => Project has no floors, cleared floor selection');
      }
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
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
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
      _floorError = (_floors.isNotEmpty && _selectedFloor == null)
          ? 'Please select a Floor / Zone.'
          : null;
      _phaseError = _selectedPhase == null ? 'Please select a Phase.' : null;
      _activityError = null; // Activity is optional (some phases have none).
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
    if (!ok) {
      _scrollToFirstError();
      // Say what's missing: some fields sit in the collapsed "Where" card, so a
      // scroll alone looked like Save did nothing.
      final first = [_projectError, _floorError, _phaseError, _activityError, _nameError, _qtyError, _unitError, _rateError]
          .firstWhere((e) => e != null, orElse: () => null);
      if (first != null) btToast(context, first, error: true);
    }
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
      // Payment history is only sent by users allowed to record payments; for
      // everyone else the server keeps the entry's payments as they are.
      if (!RoleManager.canRecordPayments) {
      } else if (_paymentHistory.isNotEmpty) {
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
            // The sheet returns the picked file's name in 'receipt' and the
            // image itself in 'receiptDataUri' — send the image, not the name.
            "receipt": p['receiptDataUri'] ?? p['receipt'] ?? '',
          };
        }).toList();
        settlePaymentHistory(payload["paymentHistory"] as List, _totalCost());
      } else {
        payload["paymentHistory"] = [];
      }
    } else if (_isAddAndPay) {
      final paid = _parseDouble(_paymentAmountCtrl.text);
      final bill = _totalCost();
      final outstanding = (bill - _existingPaidAmount).clamp(
        0.0,
        double.infinity,
      );
      if (paymentExceeds(paid, outstanding)) {
        _snack('Payment amount cannot exceed the outstanding amount.');
        setState(() => _isSaving = false);
        return;
      }
      // The exact remainder pays the bill in full (sent as the bill itself).
      final totalPaid = paymentSettles(paid, outstanding) ? bill : _existingPaidAmount + paid;
      String apiMode = _paymentMethod;
      if (apiMode == 'Bank Transfer') apiMode = 'Bank Transfer';
      payload["paidAmount"] = totalPaid;
      payload["paymentMode"] = apiMode;
      final bool esignReq = (_paymentResult?['requestEsign'] as bool?) ?? false;
      if (apiMode == 'Cash' && esignReq) {
        payload['requestEsign'] = true;
        payload['clientEmail'] = (_paymentResult?['clientEmail'] as String?) ?? '';
      }
      payload["paymentStatus"] = moneyPaise(totalPaid) >= moneyPaise(bill)
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
      final bill = _totalCost();
      final outstanding = (bill - _existingPaidAmount).clamp(
        0.0,
        double.infinity,
      );
      if (paymentExceeds(paid, outstanding)) {
        _snack('Payment amount cannot exceed the outstanding amount.');
        setState(() => _isSaving = false);
        return;
      }
      // The exact remainder pays the bill in full (sent as the bill itself).
      final totalPaid = paymentSettles(paid, outstanding) ? bill : _existingPaidAmount + paid;
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
      payload["paymentStatus"] = moneyPaise(totalPaid) >= moneyPaise(bill)
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
    final EntrySaveResult result;
    if (_isEditing && _editingTransactionId != null) {
      final ok = await ApiService.updateTransaction(_editingTransactionId!, payload);
      result = EntrySaveResult(ok ? EntrySaveOutcome.saved : EntrySaveOutcome.failed);
    } else {
      result = await postTransaction(payload);
    }
    if (!mounted) return;
    if (result.offline) {
      // Queued by the offline queue: no success animation for money that isn't saved yet.
      btToast(context, result.message ?? EntrySaveResult.offlineMessage);
      finishEntrySave(context, exit: _entryExit);
      return;
    }
    if (!result.saved) {
      btToast(context, result.message ?? 'Error saving to server. Please try again.', error: true);
      setState(() => _isSaving = false);
      return;
    }
    final projectId = _selectedProjectId;
    if (projectId != null && projectId.isNotEmpty) {
      context.read<InventoryProvider>().loadInventory(projectId);
    }
    // When this screen pops with `true` the caller reloads; the dock / origin exits refresh here.
    if (_entryExit != null || !Navigator.canPop(context)) {
      context.read<ProjectProvider>().load();
    }
    final savedTitle = _nameCtrl.text.trim();
    final savedTotal = _totalCost();
    await showBtSuccess(
      context,
      kind: BtSuccessKind.check,
      label: _isEditing
          ? 'Entry updated'
          : RoleManager.isAdmin
          ? 'Entry saved'
          : 'Submitted to supervisor',
      title: _isEditing ? 'Labour entry updated.' : 'Labour entry saved.',
      message: [
        if (savedTitle.isNotEmpty) savedTitle,
        if (savedTotal > 0) formatInr(savedTotal),
      ].join(' · '),
    );
    if (!mounted) return;
    finishEntrySave(context, exit: _entryExit);
  }
  Widget _buildPaymentSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtGroup(
            children: [
              BtRow(
                leading: const BtTile(icon: Icons.payments_outlined, bg: Bt.greenSoft, fg: Bt.green),
                title: _isEditing ? 'Payment history' : 'Record a payment',
                titleWeight: FontWeight.w600,
                subtitle: _isEditing ? 'Manage payments for this entry' : 'Optionally log payment while adding',
                trailing: _isEditing
                    ? null
                    : BtSwitch(
                        value: _recordPaymentNow,
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
                                  _scrollToBottom();
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
              ),
            ],
          ),
          if (!_isEditing && _recordPaymentNow && _paymentResult != null) ...[
            const SizedBox(height: 12),
            _buildPaymentSummary(),
          ],
          if (_isEditing) ...[
            if (_paymentHistory.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._paymentHistory.asMap().entries.map((entry) {
                final idx = entry.key;
                final payment = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: _buildHistoryItem(payment, idx),
                );
              }),
            ] else
              const SizedBox(height: 12),
            BtButton(
              label: 'Add Payment',
              icon: Icons.add_rounded,
              variant: BtButtonVariant.secondary,
              small: true,
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
                    _scrollToBottom();
                  });
                }
              },
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
        payDate = DateTime.parse(payment['date'].toString()).toLocal();
      } catch (_) {}
    } else if (payment['paymentDate'] != null) {
      try {
        payDate = payment['paymentDate'] as DateTime;
      } catch (_) {}
    }
    final note = (payment['note'] ?? '').toString();
    return _paymentCard(
      title: 'Payment',
      amount: amount,
      method: method,
      payDate: payDate,
      note: note,
      trailing: BtIconButton(
        icon: Icons.delete_outline_rounded,
        size: 20,
        color: Bt.red,
        semantic: 'Remove payment',
        onTap: () {
          setState(() {
            _paymentHistory.removeAt(index);
          });
        },
      ),
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
    );
  }
  Widget _buildPaymentSummary() {
    final amount = (_paymentResult!['amount'] as double?) ?? 0.0;
    final method = (_paymentResult!['method'] as String?) ?? 'Cash';
    final payDate =
        (_paymentResult!['paymentDate'] as DateTime?) ?? DateTime.now();
    final note = (_paymentResult!['note'] as String?) ?? '';
    return _paymentCard(
      title: 'Payment recorded',
      amount: amount,
      method: method,
      payDate: payDate,
      note: note,
      trailing: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text('Tap to edit', style: BtText.caption(context, color: Bt.green, weight: FontWeight.w600)),
      ),
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
    );
  }
  /// Green payment card: heading row (check · title · trailing), then
  /// amount / method / date tiles and an optional note.
  Widget _paymentCard({
    required String title,
    required double amount,
    required String method,
    required DateTime payDate,
    required String note,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return BtPressable(
      onTap: onTap,
      scale: .98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
        decoration: BoxDecoration(
          color: Bt.greenSoft,
          borderRadius: BorderRadius.circular(Bt.rCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: Bt.touch,
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Bt.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: BtText.subhead(context, color: Bt.green, weight: FontWeight.w600))),
                  trailing,
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
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
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Note: $note',
                style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _summaryChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Bt.card,
        borderRadius: BorderRadius.circular(Bt.rTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: BtText.mono(context, size: 9.5)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    btToast(context, msg, error: msg.toLowerCase().contains('cannot') || msg.toLowerCase().contains('error'));
  }
  void _showRecentEntriesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Bt.scrim,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.60,
          minChildSize: 0.40,
          maxChildSize: 0.90,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Bt.ground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Bt.inputBorder,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                    child: Row(
                      children: [
                        BtTile(icon: Icons.history_rounded, bg: context.bt.accentSoft, fg: context.bt.accentInk),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recent Labour Entries', style: BtText.d3(ctx)),
                              Text(
                                '${_recentEntries.length} similar entr${_recentEntries.length == 1 ? "y" : "ies"} found',
                                style: BtText.caption(ctx),
                              ),
                            ],
                          ),
                        ),
                        BtIconButton(
                          icon: Icons.close_rounded,
                          size: 18,
                          semantic: 'Close',
                          background: Bt.fill,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _recentEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                            final d = DateTime.parse(rawDate.toString()).toLocal();
                            dateStr =
                                '${d.day} ${_monthName(d.month)} ${d.year}';
                          } catch (_) {}
                        }
                        final String rateStr = rate > 0
                            ? '₹${rate % 1 == 0 ? rate.toInt() : rate}/$unit'
                            : '';
                        final row = BtPressable(
                          onTap: () {
                            Navigator.pop(ctx);
                            _prefillFromRecent(tx);
                            _snack('Prefilled from "$title"');
                          },
                          scale: .98,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: Bt.card,
                              borderRadius: BorderRadius.circular(Bt.rCard),
                              boxShadow: Bt.shadow,
                            ),
                            child: Row(
                              children: [
                                const BtTile(icon: Icons.people_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: BtText.body(ctx, weight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                            if (rateStr.isNotEmpty) rateStr,
                                            if (category.isNotEmpty) category,
                                            if (workType.isNotEmpty) workType,
                                            if (dateStr.isNotEmpty) dateStr,
                                        ].join(' · '),
                                        style: BtText.num(BtText.caption(ctx)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Bt.ink,
                                    borderRadius: BorderRadius.circular(Bt.rChip),
                                  ),
                                  child: Text(
                                    'Use',
                                    style: BtText.caption(ctx, color: Bt.bone, weight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        return i < 8 ? BtReveal(index: i, child: row) : row;
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
  void _showDeleteDialog(BuildContext context) async {
    final confirmed = await btConfirm(
      context,
      title: 'Delete entry?',
      message: 'Are you sure you want to permanently delete this entry?',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    if (_editingTransactionId != null) {
      final success = await ApiService.deleteTransaction(_editingTransactionId!);
      if (success && context.mounted) {
        if (_selectedProjectId != null) {
          context.read<InventoryProvider>().loadInventory(_selectedProjectId!);
        }
        context.read<ProjectProvider>().load();
        btToast(context, 'Entry deleted successfully');
        // 'deleted' tells the entry detail screen to close as well.
        Navigator.pop(context, 'deleted');
      } else if (context.mounted) {
        btToast(context, 'Failed to delete entry', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProjectProvider>().projects;
    final title = _isEditing ? 'Edit labour' : _isDuplicate ? 'Repeat entry' : 'Labour';
    final showRecent = _selectedProjectId != null && !_isEditing;
    final qtyText = _qtyCtrl.text.isEmpty ? '—' : _qtyCtrl.text;
    final rateText = _rateCtrl.text.isEmpty ? '—' : '₹${_rateCtrl.text}';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: title,
        trailing: _isEditing && RoleManager.canDeleteEntries
            ? BtIconButton(
                icon: Icons.delete_outline_rounded,
                semantic: 'Delete entry',
                color: Bt.red,
                onTap: () => _showDeleteDialog(context),
              )
            : null,
      ),
      body: ListView(
        controller: _scrollCtrl,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                          if (_floors.isEmpty) {
                            await _loadPhases(null);
                          }
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
                      const SizedBox(height: 20),
          ] else
            BtReveal(child: EntryWhereSummary(
              projectId: _selectedProjectId,
              floor: _selectedFloor,
              phase: _selectedPhase,
              activity: _selectedActivity,
            )),
          if (_floorWarning != null) EntryNotice(_floorWarning!),
          if (_phaseWarning != null) EntryNotice(_phaseWarning!),
          if (_activityWarning != null) EntryNotice(_activityWarning!),
          if (showRecent) ...[
            if (_recentEntries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: EntryRecentRow(count: _recentEntries.length, onTap: _showRecentEntriesSheet),
              ),
          ],
          EntryFormSection(
            children: btStagger(start: 1, [
              EntryLabeled(
                label: 'Labour type',
                required: true,
                child: AutocompleteNameField(
                  controller: _nameCtrl,
                  hint: 'e.g. Mason, Carpenter, Steel Fixer',
                  suggestions: const [],
                  onChanged: (_) => setState(() => _nameError = null),
                  onSuggestionSelected: _prefillFromRecent,
                  errorText: _nameError,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EntryLabeled(
                      label: 'Quantity',
                      required: true,
                      child: EntryUnderlineField(
                        controller: _qtyCtrl,
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _qtyError = null),
                        error: _qtyError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EntryLabeled(
                      label: 'Unit',
                      required: true,
                      child: UnitSelectorField(
                        value: _selectedUnit,
                        units: kLabourUnits,
                        hint: 'Day, Hour, Sq ft',
                        onChanged: (u) => setState(() {
                          _selectedUnit = u;
                          _unitError = null;
                        }),
                        error: _unitError,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EntryLabeled(
                      label: _selectedUnit == null ? 'Rate' : 'Rate per ${_selectedUnit!}',
                      required: true,
                      child: EntryUnderlineField(
                        controller: _rateCtrl,
                        hint: '0',
                        prefix: '₹',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _rateError = null),
                        error: _rateError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EntryLabeled(
                      label: 'Date',
                      required: true,
                      child: EntryDateField(
                        date: _selectedDate,
                        onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: ColorScheme.light(
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
                      ),
                    ),
                  ),
                ],
              ),
              EntryLabeled(
                label: 'Overtime amount',
                child: EntryUnderlineField(
                  controller: _overtimeCtrl,
                  hint: '0',
                  prefix: '₹',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              EntryTotalCard(
                total: _totalCost(),
                label: 'Total',
                lines: [
                  ('$qtyText ${_selectedUnit ?? "Unit"} × $rateText', formatInr((double.tryParse(_qtyCtrl.text) ?? 0) * (double.tryParse(_rateCtrl.text) ?? 0))),
                  ('Overtime', '₹ ${_overtimeCtrl.text.isEmpty ? "0" : _overtimeCtrl.text}'),
                ],
              ),
            ]),
          ),
          if (RoleManager.canRecordPayments) BtReveal(index: 7, child: _buildPaymentSection()),
          BtReveal(index: 8, child: EntryFormSection(
            title: 'Bill or invoice',
            caption: 'optional',
            children: [
              UploadBox(
                attachment: _attachment,
                emptyLabel: 'Tap to upload invoice / bill',
                onPicked: (a) => setState(() => _attachment = a),
                onRemove: () => setState(() => _attachment = null),
              ),
            ],
          )),
          BtReveal(index: 9, child: EntryMoreDetails(
            title: 'More details',
            subtitle: 'Trade, contractor, notes',
            autoExpand: _workTypeCtrl.text.trim().isNotEmpty || _categoryCtrl.text.trim().isNotEmpty || _notesCtrl.text.trim().isNotEmpty,
            children: [
              EntryLabeled(
                label: 'Trade / work type',
                child: EntryUnderlineField(controller: _workTypeCtrl, hint: 'e.g. Masonry, Barbending, Concrete Crew'),
              ),
              EntryLabeled(
                label: 'Contractor / team',
                child: EntryUnderlineField(controller: _categoryCtrl, hint: 'e.g. Vertex Infra Contractors'),
              ),
              EntryLabeled(
                label: 'Notes',
                child: EntryNotesField(controller: _notesCtrl),
              ),
            ],
          )),
        ],
      ),
      bottomNavigationBar: EntryBottomBar(
        child: EntrySubmitButton(
          label: RoleManager.isAdmin
              ? 'Save Labour Entry'
              : 'Submit to Supervisor',
          icon: Icons.check_circle,
          isLoading: _isSaving,
          onTap: () => _save(context),
        ),
      ),
    );
  }
}


