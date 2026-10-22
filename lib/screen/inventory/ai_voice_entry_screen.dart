import 'package:buildtrack_mobile/design/design.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:buildtrack_mobile/common/controllers/voice_recording_controller.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
class VoiceResponseModel {
  final String status;
  final String? entryType;
  final String? transcript;
  final String? partialTranscript;
  final Map<String, dynamic> detectedFields;
  final List<String> missingFields;
  final String? question;
  final List<String> suggestions;
  final int completedFields;
  final int totalFields;
  final double? confidence;
  final String? errorMessage;
  final String? welcomeMessage;
  const VoiceResponseModel({
    this.status = 'idle',
    this.entryType,
    this.transcript,
    this.partialTranscript,
    this.detectedFields = const {},
    this.missingFields = const [],
    this.question,
    this.suggestions = const [],
    this.completedFields = 0,
    this.totalFields = 0,
    this.confidence,
    this.errorMessage,
    this.welcomeMessage,
  });
  VoiceResponseModel copyWith({
    String? status,
    String? entryType,
    String? transcript,
    String? partialTranscript,
    Map<String, dynamic>? detectedFields,
    List<String>? missingFields,
    String? question,
    List<String>? suggestions,
    int? completedFields,
    int? totalFields,
    double? confidence,
    String? errorMessage,
    String? welcomeMessage,
  }) => VoiceResponseModel(
    status: status ?? this.status,
    entryType: entryType ?? this.entryType,
    transcript: transcript ?? this.transcript,
    partialTranscript: partialTranscript ?? this.partialTranscript,
    detectedFields: detectedFields ?? this.detectedFields,
    missingFields: missingFields ?? this.missingFields,
    question: question ?? this.question,
    suggestions: suggestions ?? this.suggestions,
    completedFields: completedFields ?? this.completedFields,
    totalFields: totalFields ?? this.totalFields,
    confidence: confidence ?? this.confidence,
    errorMessage: errorMessage ?? this.errorMessage,
    welcomeMessage: welcomeMessage ?? this.welcomeMessage,
  );
  bool get hasField => detectedFields.isNotEmpty;
  bool fieldHasValue(String key) =>
      detectedFields.containsKey(key) &&
      detectedFields[key] != null &&
      '${detectedFields[key]}'.trim().isNotEmpty;
}
abstract final class VoiceStatus {
  static const String idle = 'idle';
  static const String listening = 'listening';
  static const String processing = 'processing';
  static const String thinking = 'thinking';
  static const String extracting = 'extracting';
  static const String waitingForUser = 'waiting_for_user';
  static const String summary = 'summary';
  static const String saving = 'saving';
  static const String completed = 'completed';
  static const String error = 'error';
}
class _ExtractedData {
  final Map<String, dynamic> _map;
  final ProjectProvider? _projectProvider;
  _ExtractedData(this._map, [this._projectProvider]);
  String? get itemName => _map['Item Name'] as String?;
  set itemName(String? v) => _map['Item Name'] = v;
  double? get quantity => _map['Quantity'] as double?;
  set quantity(double? v) => _map['Quantity'] = v;
  String? get unit => _map['Unit'] as String?;
  set unit(String? v) => _map['Unit'] = v;
  double? get rate => _map['Rate'] as double?;
  set rate(double? v) => _map['Rate'] = v;
  String? get brand => _map['Brand'] as String?;
  set brand(String? v) => _map['Brand'] = v;
  String? get projectId => _projectProvider != null
      ? _projectProvider.selectedProject?.id
      : _map['Project ID'] as String?;
  set projectId(String? v) => _map['Project ID'] = v;
  String? get projectName => _projectProvider != null
      ? _projectProvider.selectedProject?.name
      : _map['Project Name'] as String?;
  set projectName(String? v) => _map['Project Name'] = v;
  String? get floor => _projectProvider != null
      ? _projectProvider.selectedFloor
      : _map['Floor'] as String?;
  set floor(String? v) => _map['Floor'] = v;
  String? get phase => _projectProvider != null
      ? _projectProvider.selectedPhase
      : _map['Phase'] as String?;
  set phase(String? v) => _map['Phase'] = v;
  String? get phaseId => _projectProvider != null
      ? _projectProvider.selectedPhaseId
      : _map['Phase ID'] as String?;
  set phaseId(String? v) => _map['Phase ID'] = v;
  String? get activity => _projectProvider != null
      ? _projectProvider.selectedActivity
      : _map['Activity'] as String?;
  set activity(String? v) => _map['Activity'] = v;
  int? get workerCount => _map['Worker Count'] as int?;
  set workerCount(int? v) => _map['Worker Count'] = v;
  double? get hours => _map['Hours'] as double?;
  set hours(double? v) => _map['Hours'] = v;
  String? get contractor => _map['Contractor'] as String?;
  set contractor(String? v) => _map['Contractor'] = v;
  String? get workType => _map['Work Type'] as String?;
  set workType(String? v) => _map['Work Type'] = v;
  String? get category => _map['Category'] as String?;
  set category(String? v) => _map['Category'] = v;
  double? get fuelCost => _map['Fuel Cost'] as double?;
  set fuelCost(double? v) => _map['Fuel Cost'] = v;
  String? get operator0 => _map['Operator'] as String?;
  set operator0(String? v) => _map['Operator'] = v;
  String? get equipmentType => _map['Equipment Type'] as String?;
  set equipmentType(String? v) => _map['Equipment Type'] = v;
  String? get vendorName => _map['Vendor Name'] as String?;
  set vendorName(String? v) => _map['Vendor Name'] = v;
  double getComputedAmount(String entryType) {
    if (entryType == 'labour') {
      final qty = (workerCount ?? 1) * (hours ?? quantity ?? 0);
      return qty * (rate ?? 0);
    } else if (entryType == 'equipment') {
      final base = (quantity ?? 0) * (rate ?? 0);
      return base + (fuelCost ?? 0);
    }
    return (quantity ?? 0) * (rate ?? 0);
  }
  bool get hasItemName => itemName != null && itemName!.trim().isNotEmpty;
  bool get hasQuantity => quantity != null && quantity! > 0;
  bool get hasUnit => unit != null && unit!.trim().isNotEmpty;
  bool get hasRate => rate != null && rate! > 0;
  bool get hasBrand => brand != null && brand!.trim().isNotEmpty;
  bool get hasProject => projectId != null && projectId!.isNotEmpty;
  bool get hasFloor => floor != null && floor!.trim().isNotEmpty;
  bool get hasPhase => phase != null && phase!.trim().isNotEmpty;
  bool get hasActivity => activity != null && activity!.trim().isNotEmpty;
  bool get hasWorkerCount => workerCount != null && workerCount! > 0;
  bool get hasHours => hours != null && hours! > 0;
  bool get hasFuelCost => fuelCost != null;
}
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}
class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 3, height: 28, color: context.bt.accent),
    );
  }
}
class _DetectedField {
  final String label;
  final String value;
  _DetectedField({required this.label, required this.value});
}
class AiVoiceEntryScreen extends StatefulWidget {
  const AiVoiceEntryScreen({super.key});
  @override
  State<AiVoiceEntryScreen> createState() => _AiVoiceEntryScreenState();
}
class _AiVoiceEntryScreenState extends State<AiVoiceEntryScreen>
    with TickerProviderStateMixin {
  late String _entryType;
  VoiceResponseModel _response = const VoiceResponseModel();
  final Map<String, dynamic> _detectedFields = {};
  _ExtractedData get _data => _ExtractedData(
    _detectedFields,
    Provider.of<ProjectProvider>(context, listen: false),
  );
  String _rawTranscript = '';
  String _status = VoiceStatus.idle;
  String? _fieldToAsk() {
    final missing = _getStillNeededFieldsFor(_data);
    debugPrint('[AI DEBUG] _fieldToAsk: missingFields=$missing');
    if (missing.isEmpty) return null;
    return missing.first;
  }
  String? get _activeField {
    if (_status != VoiceStatus.waitingForUser) return null;
    return _fieldToAsk();
  }
  String? _saveError;
  String? _savedEntryId;
  bool _isEditing = false;
  final Map<String, TextEditingController> _editControllers = {};
  Map<String, dynamic>? _savedEditFields;
  String? _editError;
  String _backendQuestion = '';
  List<String> _backendSuggestions = const [];
  bool _isProcessing = false;
  late final VoiceRecordingController _voiceCtrl;
  bool _isListeningForAnswer = false;
  String _partialAnswer = '';
  bool _showKeyboardInput = false;
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  late final AnimationController _micPulseCtrl;
  late final AnimationController _bubbleCtrl;
  late final AnimationController _micOrbCtrl;
  late final AnimationController _waveCtrl;
  List<ProjectModel> get _projects {
    final projects = Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).projects;
    debugPrint(
      "AI PROJECTS: ${projects.map((e) => "${e.name} (${e.id})").toList()}",
    );
    return projects;
  }
  ProjectModel? get _selectedProject {
    final projId = _data.projectId;
    if (projId != null && projId.isNotEmpty) {
      final p = _projects.cast<ProjectModel?>().firstWhere(
        (p) => p?.id == projId,
        orElse: () => null,
      );
      if (p != null) return p;
    }
    return Provider.of<ProjectProvider>(context, listen: false).selectedProject;
  }
  int _processingStage = 0;
  Timer? _processingTimer;
  Timer? _answerTimeoutTimer;
  @override
  void initState() {
    super.initState();
    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _micOrbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _voiceCtrl = VoiceRecordingController();
    _voiceCtrl.addListener(_onVoiceChanged);
    _voiceCtrl.preInitialize();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _entryType = (args?['type'] as String?) ?? 'material';
    _rebuildResponse();
  }
  @override
  void dispose() {
    _voiceCtrl.removeListener(_onVoiceChanged);
    _voiceCtrl.dispose();
    _micPulseCtrl.dispose();
    _bubbleCtrl.dispose();
    _micOrbCtrl.dispose();
    _waveCtrl.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _processingTimer?.cancel();
    _answerTimeoutTimer?.cancel();
    _disposeEditControllers();
    super.dispose();
  }
  void _cancelAllTimers() {
    _processingTimer?.cancel();
    _processingTimer = null;
    _answerTimeoutTimer?.cancel();
    _answerTimeoutTimer = null;
  }
  void _startAnswerTimeout() {
    _answerTimeoutTimer?.cancel();
    _answerTimeoutTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('[VOICE] Answer timeout reached — auto-stopping');
      if (_isListeningForAnswer && !_isProcessing && mounted) {
        _stopAnswerListening();
      }
    });
  }
  void _speechFailed() {
    if (!mounted) return;
    _cancelAllTimers();
    _isListeningForAnswer = false;
    _isProcessing = false;
    setState(() {
      _status = VoiceStatus.listening;
      _partialAnswer = '';
      _rebuildResponse();
    });
  }
  void _onVoiceChanged() {
    if (!mounted) return;
    final state = _voiceCtrl.engineState;
    final text = _voiceCtrl.finalTranscript.trim().isNotEmpty
        ? _voiceCtrl.finalTranscript.trim()
        : _voiceCtrl.partialTranscript.trim();
    final partial = _voiceCtrl.partialTranscript;
    if (_partialAnswer != partial) {
      setState(() => _partialAnswer = partial);
      debugPrint('[VOICE] Partial: "$partial"');
    }
    debugPrint(
      '[UI LISTENING STATE CHANGES] onVoiceChanged: EngineState=$state, STT.isListening=${_voiceCtrl.isListening}, UIStatus=$_status, isListeningForAnswer=$_isListeningForAnswer',
    );
    if (state == VoiceEngineState.parsed) {
      debugPrint('[VOICE] Parsed: finalTranscript="$text"');
      if (_status == VoiceStatus.listening && _rawTranscript.isEmpty) {
        if (text.isNotEmpty) {
          debugPrint('[VOICE] Setting rawTranscript from parsed: "$text"');
          _rawTranscript = text;
          _beginAiProcessing();
        } else {
          debugPrint('[VOICE] Parsed with empty transcript — restarting');
          _restartInitialRecording();
        }
        return;
      }
      if (_isListeningForAnswer) {
        if (_isProcessing) {
          debugPrint('[VOICE] Parsed while processing — ignoring');
          return;
        }
        _isListeningForAnswer = false;
        debugPrint('[VOICE] Answer listening stopped');
        if (text.isNotEmpty) {
          debugPrint('[VOICE] Processing answer: "$text"');
          _handleVoiceAnswer(text);
        } else {
          debugPrint('[VOICE] Empty answer — unsticking');
          _unstickListening();
        }
        return;
      }
      setState(() => _rebuildResponse());
      return;
    }
    if (state == VoiceEngineState.error) {
      debugPrint('[VOICE ERROR] Engine error: ${_voiceCtrl.errorMessage}');
      if (mounted) {
        final err = _voiceCtrl.errorMessage;
        final isPermission = err.toLowerCase().contains('permission') || err.toLowerCase().contains('denied');
        setState(() {
          _saveError = isPermission
              ? 'Microphone permission is required. Please enable microphone access in your device Settings.'
              : err;
          _status = VoiceStatus.idle;
          _isListeningForAnswer = false;
          _rebuildResponse();
        });
        if (isPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission denied. Please allow microphone access in device Settings to use voice input.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFFC01048),
            ),
          );
        }
      }
      return;
    }
    if (state == VoiceEngineState.idle) {
      if (_isListeningForAnswer) {
        if (_isProcessing) {
          debugPrint('[VOICE] idle while processing — ignoring');
          return;
        }
        debugPrint(
          '[VOICE] Engine went idle while waiting for answer — unsticking',
        );
        _isListeningForAnswer = false;
        _unstickListening();
        return;
      } else if (_status == VoiceStatus.listening) {
        setState(() {
          _status = VoiceStatus.idle;
          _rebuildResponse();
        });
      }
    }
    if (state == VoiceEngineState.processing &&
        text.isNotEmpty &&
        _rawTranscript.isEmpty) {
      if (_status == VoiceStatus.listening) {
        debugPrint('[VOICE] Processing with transcript available: "$text"');
        _rawTranscript = text;
        _beginAiProcessing();
      }
    }
  }
  void _unstickListening() {
    if (!mounted) return;
    setState(() {
      _partialAnswer = '';
      _rebuildResponse();
    });
  }
  void _restartInitialRecording() {
    if (!mounted) return;
    setState(() {
      _status = VoiceStatus.idle;
      _rebuildResponse();
    });
  }
  Future<void> _startInitialRecording() async {
    if (_isProcessing || _voiceCtrl.engineState == VoiceEngineState.listening) {
      debugPrint(
        '[VOICE ACTION GUARD] _startInitialRecording ignored: isProcessing=$_isProcessing, engineState=${_voiceCtrl.engineState}',
      );
      return;
    }
    debugPrint("Listening: true");
    debugPrint("Recording: true");
    _resetCurrentEntryData();
    setState(() {
      _status = VoiceStatus.listening;
      _saveError = null;
      _rebuildResponse();
    });
    await _voiceCtrl.startListening();
    if (mounted) setState(() {});
  }
  // ignore: unused_element — kept from the original (not reachable there either).
  Future<void> _stopInitialRecording() async {
    if (_voiceCtrl.engineState != VoiceEngineState.listening) {
      debugPrint(
        '[VOICE ACTION GUARD] _stopInitialRecording ignored: engineState=${_voiceCtrl.engineState}',
      );
      return;
    }
    debugPrint("Listening: false");
    debugPrint("Recording: false");
    debugPrint("Timer cancelled");
    debugPrint("Waveform stopped");
    await _voiceCtrl.stopListening();
  }
  Future<void> _stopAndAnalyze() async {
    if (_isProcessing) {
      debugPrint(
        '[VOICE ACTION GUARD] _stopAndAnalyze ignored: already processing.',
      );
      return;
    }
    debugPrint('[VOICE] Stop & Analyze pressed');
    await _voiceCtrl.stopListening();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final transcript = _voiceCtrl.finalTranscript.trim().isNotEmpty
        ? _voiceCtrl.finalTranscript.trim()
        : _voiceCtrl.partialTranscript.trim();
    debugPrint('[VOICE] Stop & Analyze: transcript="$transcript"');
    if (transcript.isNotEmpty) {
      _rawTranscript = transcript;
    }
    if (mounted && _rawTranscript.isNotEmpty) {
      _beginAiProcessing();
    } else if (mounted) {
      debugPrint('[VOICE] No transcript captured — setting idle');
      setState(() {
        _status = VoiceStatus.idle;
        _saveError = "Couldn't hear or understand any speech. Please tap the mic and speak clearly.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't hear or understand any speech. Please tap the mic and try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  void _resetCurrentEntryData() {
    setState(() {
      _data.itemName = null;
      _data.quantity = null;
      _data.unit = null;
      _data.rate = null;
      _data.brand = null;
      _data.workerCount = null;
      _data.hours = null;
      _data.fuelCost = null;
      _data.contractor = null;
      _data.workType = null;
      _data.category = null;
      _data.operator0 = null;
      _data.equipmentType = null;
      _data.vendorName = null;
      _rawTranscript = '';
      _partialAnswer = '';
      _detectedFields.clear();
      _rebuildResponse();
    });
  }
  Future<void> _cancelRecording() async {
    debugPrint('[VOICE] Cancel recording pressed');
    if (_isProcessing) {
      debugPrint(
        '[VOICE ACTION GUARD] _cancelRecording ignored: already processing.',
      );
      return;
    }
    await _voiceCtrl.cancelListening();
    _resetCurrentEntryData();
    setState(() {
      _status = VoiceStatus.idle;
      _rebuildResponse();
    });
  }
  void _beginAiProcessing() {
    if (_isProcessing) {
      debugPrint('[AI] Already processing — ignoring duplicate request');
      return;
    }
    _isProcessing = true;
    debugPrint('[AI] PROCESSING: begin, transcript="$_rawTranscript"');
    _cancelAllTimers();
    if (!mounted) {
      _isProcessing = false;
      return;
    }
    setState(() {
      _status = VoiceStatus.processing;
      _processingStage = 0;
      _rebuildResponse();
    });
    _processingTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_status != VoiceStatus.processing) {
        t.cancel();
        return;
      }
      setState(() {
        _processingStage++;
        _rebuildResponse();
      });
      if (_processingStage >= 6) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _finishExtraction();
        });
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _status != VoiceStatus.processing) return;
      debugPrint('[AI] Processing timeout (5s) — forcing extraction');
      _cancelAllTimers();
      try {
        if (_rawTranscript.isEmpty) {
          _rawTranscript = _voiceCtrl.finalTranscript.trim().isNotEmpty
              ? _voiceCtrl.finalTranscript.trim()
              : _voiceCtrl.partialTranscript.trim();
          debugPrint('[AI] Fallback transcript: "$_rawTranscript"');
        }
        _finishExtraction();
      } catch (e, stack) {
        debugPrint('[AI ERROR] Timeout extraction: $e');
        debugPrint('[AI ERROR] $stack');
        _isProcessing = false;
        if (mounted) {
          setState(() {
            _status = VoiceStatus.waitingForUser;
            _rebuildResponse();
          });
        }
      }
    });
  }
  void _finishExtraction() {
    debugPrint('[AI] === _finishExtraction ===');
    debugPrint('[AI] Raw transcript: "$_rawTranscript"');
    debugPrint('[AI] Detected fields before: $_detectedFields');
    try {
      if (_rawTranscript.isNotEmpty) {
        _parseTranscriptInto(_data, _rawTranscript);
      }
    } catch (e, stack) {
      debugPrint('[AI ERROR] _finishExtraction parse: $e');
      debugPrint('[AI ERROR] $stack');
    }
    debugPrint('[AI] Detected fields after: $_detectedFields');
    final missing = _getStillNeededFieldsFor(_data);
    debugPrint('[AI] Missing fields: $missing');
    _isProcessing = false;
    if (missing.isEmpty && _detectedFields.isNotEmpty) {
      debugPrint('[AI] All fields collected — showing review');
      _goToSummary();
      return;
    }
    _advanceToNextMissingField();
  }
  _ExtractedData get _currentData {
    if ((_status == VoiceStatus.listening || _status == VoiceStatus.idle) &&
        _voiceCtrl.isListening &&
        _partialAnswer.isNotEmpty) {
      final tempMap = <String, dynamic>{};
      final temp = _ExtractedData(
        tempMap,
        Provider.of<ProjectProvider>(context, listen: false),
      );
      _parseTranscriptInto(temp, _partialAnswer);
      return temp;
    } else if (_status == VoiceStatus.waitingForUser &&
        _voiceCtrl.isListening &&
        _partialAnswer.isNotEmpty) {
      final tempMap = Map<String, dynamic>.from(_detectedFields);
      final field = _activeField;
      if (field != null) {
        _applyAnswerForFieldToMap(tempMap, field, _partialAnswer);
      }
      return _ExtractedData(tempMap);
    }
    return _data;
  }
  void _parseTranscriptInto(_ExtractedData data, String text) {
    final t = text.toLowerCase().trim();
    if (_entryType == 'material') {
      const labourKeywords = [
        'mason',
        'masons',
        'worker',
        'workers',
        'carpenter',
        'carpenters',
        'plumber',
        'plumbers',
        'electrician',
        'electricians',
        'helper',
        'helpers',
        'labour',
        'labourer',
        'labourers',
        'welder',
        'welders',
        'painter',
        'painters',
        'foreman',
        'engineer',
        'engineers',
        'supervisor',
        'supervisors',
        'driver',
        'drivers',
      ];
      const equipmentKeywords = [
        'jcb',
        'excavator',
        'crane',
        'concrete mixer',
        'generator',
        'road roller',
        'roller',
        'dumper',
        'dumptruck',
        'bulldozer',
        'forklift',
        'tractor',
        'compressor',
        'drill',
        'water pump',
        'hoist',
        'lift',
        'vibrator',
      ];
      for (final kw in labourKeywords) {
        if (t.contains(kw)) {
          _entryType = 'labour';
          break;
        }
      }
      if (_entryType == 'material') {
        for (final kw in equipmentKeywords) {
          if (t.contains(kw)) {
            _entryType = 'equipment';
            break;
          }
        }
      }
    }
    final numMatch = RegExp(r'(\d+\.?\d*)').firstMatch(t);
    if (numMatch != null) {
      data.quantity = double.tryParse(numMatch.group(0) ?? '');
    }
    const unitMap = {
      'bag': 'Bags',
      'bags': 'Bags',
      'kg': 'Kg',
      'kilo': 'Kg',
      'kilos': 'Kg',
      'ton': 'Tons',
      'tons': 'Tons',
      'cft': 'CFT',
      'cubic feet': 'CFT',
      'sqft': 'Sqft',
      'square feet': 'Sqft',
      'nos': 'Nos',
      'number': 'Nos',
      'piece': 'Nos',
      'pieces': 'Nos',
      'ltr': 'Ltrs',
      'litre': 'Ltrs',
      'litres': 'Ltrs',
      'liter': 'Ltrs',
      'cum': 'Cum',
      'cubic meter': 'Cum',
      'cubic metres': 'Cum',
      'hour': 'Hours',
      'hours': 'Hours',
      'hr': 'Hours',
      'hrs': 'Hours',
      'day': 'Days',
      'days': 'Days',
      'rft': 'Rft',
      'running feet': 'Rft',
      'trip': 'Trips',
      'trips': 'Trips',
    };
    for (final entry in unitMap.entries) {
      if (t.contains(entry.key)) {
        data.unit = entry.value;
        break;
      }
    }
    final rateMatch = RegExp(
      r'(?:rate|at|per unit|@)\s*(?:rs\.?|rupees?|₹)?\s*(\d+\.?\d*)',
    ).firstMatch(t);
    if (rateMatch != null) {
      data.rate = double.tryParse(rateMatch.group(1) ?? '');
    } else {
      final priceMatch = RegExp(
        r'(?:₹|rs\.?|rupees?)\s*(\d+\.?\d*)',
      ).firstMatch(t);
      if (priceMatch != null) {
        data.rate = double.tryParse(priceMatch.group(1) ?? '');
      }
    }
    const brands = [
      'ultratech',
      'ambuja',
      'acc',
      'india cement',
      'tata',
      'jk cement',
      'dalmia',
      'ramco',
      'jsw',
      'steel authority',
      'birla',
      'shree',
      'jcb',
      'caterpillar',
      'l&t',
      'volvo',
      'mahindra',
      'atlas copco',
      'komatsu',
    ];
    for (final b in brands) {
      if (t.contains(b)) {
        data.brand = b
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
            .join(' ');
        break;
      }
    }
    if (_entryType == 'material') {
      const materials = {
        'cement': 'Cement',
        'concrete': 'Ready-Mix Concrete',
        'steel': 'Steel',
        'rod': 'Steel Rod',
        'rebar': 'Steel Rebar',
        'brick': 'Brick',
        'sand': 'Sand',
        'aggregate': 'Aggregate',
        'gravel': 'Gravel',
        'tile': 'Tiles',
        'paint': 'Paint',
        'pipe': 'PVC Pipe',
        'wire': 'Wire',
        'plywood': 'Plywood',
        'timber': 'Timber',
        'wood': 'Wood',
        'glass': 'Glass',
        'marble': 'Marble',
        'granite': 'Granite',
        'block': 'Block',
        'drywall': 'Drywall',
        'plaster': 'Plaster',
      };
      for (final entry in materials.entries) {
        if (t.contains(entry.key)) {
          data.itemName = data.brand != null
              ? '${data.brand} ${entry.value}'
              : entry.value;
          break;
        }
      }
    }
    if (_entryType == 'labour') {
      const trades = {
        'masonry': 'Masonry',
        'mason': 'Masonry',
        'plumbing': 'Plumbing',
        'plumber': 'Plumbing',
        'electrical': 'Electrical',
        'electrician': 'Electrical',
        'carpentry': 'Carpentry',
        'carpenter': 'Carpentry',
        'welding': 'Welding',
        'welder': 'Welding',
        'painting': 'Painting',
        'painter': 'Painting',
        'helper': 'Helper',
        'labourer': 'General Labour',
        'driver': 'Driver',
        'supervisor': 'Supervisor',
        'foreman': 'Foreman',
        'engineer': 'Engineer',
      };
      for (final entry in trades.entries) {
        if (t.contains(entry.key)) {
          data.workType = entry.value;
          break;
        }
      }
      final workerMatch = RegExp(
        r'(\d+)\s*(?:mason|worker|carpenter|plumber|electrician|helper|labor|labour|painter|welder|man|men)s?',
      ).firstMatch(t);
      if (workerMatch != null) {
        data.workerCount = int.tryParse(workerMatch.group(1) ?? '');
      }
      final hoursMatch = RegExp(r'(\d+\.?\d*)\s*(?:hour|hr)s?').firstMatch(t);
      if (hoursMatch != null) {
        data.hours = double.tryParse(hoursMatch.group(1) ?? '');
        data.unit = 'Hours';
      }
      final nameMatch = RegExp(
        r'\b([A-Z][a-z]+ [A-Z][a-z]+)\b',
      ).firstMatch(text);
      if (nameMatch != null) {
        data.itemName = nameMatch.group(0);
      } else if (data.workerCount != null && data.workType != null) {
        data.itemName = '${data.workerCount} ${data.workType}s';
      } else if (data.workType != null) {
        data.itemName = '${data.workType} Team';
      } else if (data.workerCount != null) {
        data.itemName = '${data.workerCount} Workers';
      }
    }
    if (_entryType == 'equipment') {
      const equipment = {
        'jcb': 'JCB Excavator',
        'excavator': 'Excavator',
        'crane': 'Crane',
        'mixer': 'Concrete Mixer',
        'generator': 'Generator',
        'roller': 'Road Roller',
        'dumper': 'Dumper',
        'truck': 'Truck',
        'bulldozer': 'Bulldozer',
        'forklift': 'Forklift',
        'tractor': 'Tractor',
        'compressor': 'Compressor',
        'drill': 'Drill Machine',
        'pump': 'Water Pump',
        'lift': 'Hoist / Lift',
        'vibrator': 'Vibrator',
      };
      for (final entry in equipment.entries) {
        if (t.contains(entry.key)) {
          data.itemName = entry.value;
          break;
        }
      }
      final hoursMatch = RegExp(r'(\d+\.?\d*)\s*(?:hour|hr)s?').firstMatch(t);
      if (hoursMatch != null) {
        data.quantity = double.tryParse(hoursMatch.group(1) ?? '');
        data.unit = 'Hours';
      }
      final fuelMatch = RegExp(
        r'(?:fuel|diesel)\s*(?:of|cost|rate|is)?\s*(?:rs\.?|rupees?|₹)?\s*(\d+\.?\d*)',
      ).firstMatch(t);
      if (fuelMatch != null) {
        data.fuelCost = double.tryParse(fuelMatch.group(1) ?? '');
      } else {
        final fuelMatch2 = RegExp(
          r'(?:rs\.?|rupees?|₹)?\s*(\d+\.?\d*)\s*(?:for)?\s*(?:fuel|diesel)',
        ).firstMatch(t);
        if (fuelMatch2 != null) {
          data.fuelCost = double.tryParse(fuelMatch2.group(1) ?? '');
        }
      }
    }
    if (data.floor == null || data.floor!.trim().isEmpty) {
      if (t.contains('basement')) {
        data.floor = 'Basement';
      } else if (t.contains('ground floor') || t.contains('g floor')) {
        data.floor = 'Ground Floor';
      } else if (t.contains('1st') || t.contains('first floor')) {
        data.floor = '1st Floor';
      } else if (t.contains('2nd') || t.contains('second floor')) {
        data.floor = '2nd Floor';
      } else if (t.contains('3rd') || t.contains('third floor')) {
        data.floor = '3rd Floor';
      } else if (t.contains('terrace') || t.contains('roof')) {
        data.floor = 'Terrace';
      }
    }
    if (data.phase == null || data.phase!.trim().isEmpty) {
      final projProv = Provider.of<ProjectProvider>(context, listen: false);
      final phases = projProv.selectedProject?.selectedPhases;
      if (phases != null) {
        for (final p in phases) {
          if (t.contains(p.phaseName.toLowerCase())) {
            data.phase = p.phaseName;
            break;
          }
        }
      }
    }
    if (data.activity == null || data.activity!.trim().isEmpty) {
      final projProv = Provider.of<ProjectProvider>(context, listen: false);
      final phases = projProv.selectedProject?.selectedPhases;
      if (phases != null) {
        for (final p in phases) {
          if (data.phase != null && data.phase != p.phaseName) continue;
          for (final a in p.activities) {
            if (t.contains(a.name.toLowerCase())) {
              data.activity = a.name;
              if (data.phase == null) {
                data.phase = p.phaseName;
              }
              break;
            }
          }
          if (data.activity != null) break;
        }
      }
    }
    if (!data.hasProject) {
      for (final proj in _projects) {
        if (t.contains(proj.name.toLowerCase())) {
          data.projectId = proj.id;
          data.projectName = proj.name;
          break;
        }
      }
    }
  }
  void _advanceToNextMissingField() {
    if (_isProcessing) {
      debugPrint('[AI] Already processing — not advancing');
      return;
    }
    _isProcessing = true;
    final missing = _getStillNeededFieldsFor(_data);
    debugPrint('[AI] _advanceToNextMissingField: missingFields=$missing');
    debugPrint('[AI] Detected: $_detectedFields');
    if (missing.isEmpty && _detectedFields.isNotEmpty) {
      debugPrint('[AI] All fields collected → review screen');
      _isProcessing = false;
      _goToSummary();
      return;
    }
    if (missing.isEmpty) {
      debugPrint('[AI] No data and no missing fields — restarting');
      _isProcessing = false;
      _speechFailed();
      return;
    }
    final field = _fieldToAsk();
    final question = field != null ? _questionForField(field) : '';
    debugPrint('[AI] Next question: "$question" (field=$field)');
    _isProcessing = false;
    if (!mounted) return;
    setState(() {
      _status = VoiceStatus.waitingForUser;
      _rebuildResponse();
    });
    _scrollToBottom();
  }
  void _rebuildResponse() {
    final missing = _getStillNeededFieldsFor(_data);
    final allFields = _getAllFieldsFor();
    final total = allFields.length;
    final completed = total - missing.length;
    String? question;
    List<String> suggestions = [];
    if (_status == VoiceStatus.waitingForUser && missing.isNotEmpty) {
      final field = _fieldToAsk();
      if (field != null) {
        question = _questionForField(field);
        if (question.isEmpty) {
          question = 'Please provide the $field.';
        }
        suggestions = _suggestionsForField(field);
      }
      debugPrint(
        '[AI DEBUG] _rebuildResponse: question="$question" for field=$field',
      );
    }
    _backendQuestion = question ?? '';
    _backendSuggestions = suggestions;
    debugPrint('[AI DEBUG] ===== _rebuildResponse =====');
    debugPrint(
      '[UI LISTENING STATE CHANGES] rebuildResponse: status=$_status, progress=$completed/$total',
    );
    debugPrint('[AI DEBUG] Status: $_status');
    debugPrint('[AI DEBUG] Transcript: $_rawTranscript');
    debugPrint('[AI DEBUG] Detected fields map: $_detectedFields');
    debugPrint('[AI DEBUG] Missing fields: $missing');
    debugPrint('[AI DEBUG] Total fields: $total');
    debugPrint('[AI DEBUG] Completed fields: $completed');
    debugPrint('[AI DEBUG] Progress: $completed/$total');
    _response = VoiceResponseModel(
      status: _status,
      entryType: _entryType,
      transcript: _rawTranscript.isNotEmpty ? _rawTranscript : null,
      partialTranscript: _partialAnswer.isNotEmpty ? _partialAnswer : null,
      detectedFields: Map.from(_detectedFields),
      missingFields: missing,
      question: question ?? _backendQuestion,
      suggestions: _backendSuggestions,
      completedFields: completed,
      totalFields: total,
      errorMessage: _saveError,
    );
  }
  List<String> _getAllFieldsFor() {
    if (_entryType == 'material') {
      return ['Material', 'Quantity', 'Unit', 'Rate'];
    } else if (_entryType == 'labour') {
      return ['Labour Type', 'Worker Count', 'Hours', 'Rate'];
    } else {
      return ['Equipment Name', 'Hours', 'Rate'];
    }
  }
  String _questionForField(String field) {
    switch (field) {
      case 'Project':
        return 'Which project is this for?';
      case 'Floor':
        return 'Which floor or zone is this work happening on?';
      case 'Phase':
        return 'Under which phase of the project is this scheduled?';
      case 'Activity':
        return 'And what\'s the specific activity we are working on?';
      case 'Labour Type':
        return 'What is the trade or labor category? (e.g. Mason, Plumber, Helper)';
      case 'Worker Count':
        return 'How many workers were in this team?';
      case 'Hours':
        return _entryType == 'labour'
            ? 'How many hours did they work today?'
            : 'How many hours was the machine operated?';
      case 'Equipment':
        return 'Which equipment or machinery was used? (e.g. JCB, Crane)';
      case 'Fuel':
        return 'What was the fuel or diesel cost for this operation? (Enter 0 if none)';
      case 'Quantity':
        return 'What\'s the total quantity we should enter?';
      case 'Unit':
        return 'What unit of measurement are we tracking this in? (e.g. Bags, Kg, Tons)';
      case 'Rate':
        final unitLabel =
            _data.unit ?? (_entryType == 'material' ? 'unit' : 'hour');
        return 'Got that. What purchase rate per $unitLabel should I log in ₹?';
      case 'Brand':
        return 'What brand is it? (e.g. UltraTech, Ambuja)';
      default:
        return '';
    }
  }
  List<String> _suggestionsForField(String field) {
    switch (field) {
      case 'Project':
        return _projects.take(5).map((p) => p.name).toList();
      case 'Floor':
        final activeProj = _selectedProject;
        if (activeProj?.floors != null && activeProj!.floors!.isNotEmpty) {
          return activeProj.floors!;
        }
        return <String>[];
      case 'Phase':
        return [
          'Foundation Work',
          'Structural Work',
          'Finishing',
          'Roofing',
          'Plumbing Work',
          'Electrical Work',
        ];
      case 'Activity':
        return [
          'Column Casting',
          'Slab Work',
          'PCC',
          'Brick Laying',
          'Plastering',
          'Excavation',
        ];
      case 'Unit':
        return ['Bags', 'Kg', 'Tons', 'Sqft', 'Nos', 'Ltrs', 'Hours'];
      case 'Brand':
        return ['UltraTech', 'Ambuja', 'ACC', 'JK Cement', 'Tata', 'JSW'];
      case 'Labour Type':
        return [
          'Mason',
          'Helper',
          'Carpenter',
          'Plumber',
          'Electrician',
          'Painter',
        ];
      case 'Worker Count':
        return ['2', '4', '6', '8', '10', '12'];
      case 'Hours':
        return ['4', '6', '8', '10', '12'];
      case 'Equipment':
        return [
          'JCB Excavator',
          'Crane',
          'Concrete Mixer',
          'Dumper',
          'Generator',
          'Road Roller',
        ];
      default:
        return [];
    }
  }
  Future<void> _startAnswerListening() async {
    if (_isProcessing) {
      debugPrint('[VOICE] Processing in progress — not starting listening');
      return;
    }
    _isListeningForAnswer = true;
    _startAnswerTimeout();
    await _voiceCtrl.startListening();
    if (mounted) setState(() {});
    debugPrint('[VOICE] _startAnswerListening: started, status=$_status');
  }
  Future<void> _stopAnswerListening() async {
    debugPrint('[VOICE] _stopAnswerListening tapped');
    if (_isProcessing) {
      debugPrint('[VOICE] Already processing — ignoring stop');
      return;
    }
    _isProcessing = true;
    _answerTimeoutTimer?.cancel();
    debugPrint('[VOICE] _stopAnswerListening: LOCKED processing');
    try {
      await _voiceCtrl.stopListening();
      debugPrint('[VOICE] _stopAnswerListening: mic stopped');
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) {
        _isProcessing = false;
        return;
      }
      final answer = _voiceCtrl.finalTranscript.trim().isNotEmpty
          ? _voiceCtrl.finalTranscript.trim()
          : _voiceCtrl.partialTranscript.trim();
      debugPrint('[VOICE] _stopAnswerListening: captured answer="$answer"');
      await _voiceCtrl.resetEngine();
      debugPrint('[VOICE] _stopAnswerListening: engine reset');
      _isListeningForAnswer = false;
      _cancelAllTimers();
      if (answer.isNotEmpty) {
        final field = _activeField;
        if (field != null) {
          debugPrint(
            '[VOICE] Applying captured answer for field "$field": "$answer"',
          );
          _applyAnswerForField(field, answer);
        }
      } else {
        debugPrint(
          '[VOICE] _stopAnswerListening: empty transcript — still advancing',
        );
      }
      if (!mounted) {
        _isProcessing = false;
        return;
      }
      setState(() {
        _partialAnswer = '';
        _rebuildResponse();
      });
      final missing = _getStillNeededFieldsFor(_data);
      debugPrint(
        '[VOICE] After answer: detected=$_detectedFields, missing=$missing',
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        _isProcessing = false;
        debugPrint('[VOICE] _stopAnswerListening: releasing processing lock');
        if (!mounted) return;
        if (missing.isEmpty && _detectedFields.isNotEmpty) {
          debugPrint('[VOICE] _stopAnswerListening: all fields → summary');
          _goToSummary();
        } else {
          debugPrint(
            '[VOICE] _stopAnswerListening: more fields needed → advancing',
          );
          _advanceToNextMissingField();
        }
      });
    } catch (e, stack) {
      debugPrint('[VOICE ERROR] _stopAnswerListening: $e');
      debugPrint('[VOICE ERROR] $stack');
      _isProcessing = false;
      _isListeningForAnswer = false;
      if (mounted) {
        setState(() {
          _status = VoiceStatus.waitingForUser;
          _saveError = 'Error processing: $e';
          _rebuildResponse();
        });
      }
    }
  }
  void _handleVoiceAnswer(String text) {
    if (_isProcessing) {
      debugPrint('[AI] Already processing answer — ignoring duplicate');
      return;
    }
    _isProcessing = true;
    debugPrint('[AI] TRANSCRIPT: answer="$text"');
    try {
      final field = _activeField;
      debugPrint('[AI] _handleVoiceAnswer: field=$field');
      if (field != null) {
        _applyAnswerForField(field, text);
        debugPrint('[AI] PROCESSING: applied answer to "$field"');
      }
    } catch (e, stack) {
      debugPrint('[AI ERROR] _handleVoiceAnswer: $e');
      debugPrint('[AI ERROR] $stack');
    }
    _isProcessing = false;
    debugPrint('[AI] After apply, missing: ${_getStillNeededFieldsFor(_data)}');
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        debugPrint('[AI] Advancing to next missing field');
        _advanceToNextMissingField();
      }
    });
  }
  void _handleTypedAnswer(String text) {
    if (text.trim().isEmpty) return;
    if (_isProcessing) {
      debugPrint('[AI] Already processing — ignoring typed answer');
      return;
    }
    _isProcessing = true;
    debugPrint('[AI] TRANSCRIPT: typed answer="$text"');
    _textCtrl.clear();
    try {
      final field = _activeField;
      if (field != null) {
        _applyAnswerForField(field, text.trim());
        debugPrint('[AI] PROCESSING: applied typed answer to "$field"');
      }
    } catch (e, stack) {
      debugPrint('[AI ERROR] _handleTypedAnswer: $e');
      debugPrint('[AI ERROR] $stack');
    }
    _isProcessing = false;
    _focusNode.unfocus();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _advanceToNextMissingField();
    });
  }
  void _applyAnswerForField(String field, String text) {
    setState(() {
      _applyAnswerForFieldToMap(_detectedFields, field, text);
      _rebuildResponse();
      debugPrint(
        '[AI DEBUG] _applyAnswer done: detectedFields=$_detectedFields, missing=${_getStillNeededFieldsFor(_data)}',
      );
    });
  }
  void _applyAnswerForFieldToMap(
    Map<String, dynamic> fields,
    String field,
    String text,
  ) {
    final t = text.toLowerCase().trim();
    final data = _ExtractedData(fields);
    switch (field) {
      case 'Project':
        final match = _projects.cast<ProjectModel?>().firstWhere(
          (p) =>
              p!.name.toLowerCase().contains(t) ||
              t.contains(p.name.toLowerCase()),
          orElse: () => null,
        );
        if (match != null) {
          data.projectId = match.id;
          data.projectName = match.name;
        } else {
          data.projectName = text.trim();
        }
        break;
      case 'Floor':
        if (t.contains('ground') || t == 'g') {
          data.floor = 'Ground Floor';
        } else if (t.contains('basement') || t == 'b') {
          data.floor = 'Basement';
        } else if (t.contains('1') || t.contains('first') || t == '1st') {
          data.floor = '1st Floor';
        } else if (t.contains('2') || t.contains('second') || t == '2nd') {
          data.floor = '2nd Floor';
        } else if (t.contains('3') || t.contains('third') || t == '3rd') {
          data.floor = '3rd Floor';
        } else if (t.contains('terrace') || t.contains('roof')) {
          data.floor = 'Terrace';
        } else {
          data.floor = text.trim();
        }
        break;
      case 'Phase':
        data.phase = text.trim();
        break;
      case 'Activity':
        data.activity = text.trim();
        break;
      case 'Labour Type':
        data.workType = text.trim();
        if (data.workerCount != null) {
          data.itemName = '${data.workerCount} ${data.workType}s';
        } else {
          data.itemName = '${data.workType} Team';
        }
        break;
      case 'Worker Count':
        final num = RegExp(r'(\d+)').firstMatch(t);
        if (num != null) {
          data.workerCount = int.tryParse(num.group(1) ?? '');
        }
        if (data.workType != null && data.workerCount != null) {
          data.itemName = '${data.workerCount} ${data.workType}s';
        }
        break;
      case 'Hours':
        final num = RegExp(r'(\d+\.?\d*)').firstMatch(t);
        if (num != null) {
          final val = double.tryParse(num.group(1) ?? '');
          if (_entryType == 'labour') {
            data.hours = val;
          } else {
            data.quantity = val;
          }
        }
        break;
      case 'Equipment':
        data.itemName = text.trim();
        break;
      case 'Fuel':
        if (t.contains('no') ||
            t.contains('none') ||
            t.contains('zero') ||
            t == '0') {
          data.fuelCost = 0;
        } else {
          final num = RegExp(r'(\d+\.?\d*)').firstMatch(t);
          if (num != null) {
            data.fuelCost = double.tryParse(num.group(1) ?? '');
          }
        }
        break;
      case 'Quantity':
        final num = RegExp(r'(\d+\.?\d*)').firstMatch(t);
        if (num != null) {
          data.quantity = double.tryParse(num.group(0) ?? '');
        }
        break;
      case 'Unit':
        const unitMap = {
          'bag': 'Bags',
          'bags': 'Bags',
          'kg': 'Kg',
          'kilo': 'Kg',
          'ton': 'Tons',
          'tons': 'Tons',
          'sqft': 'Sqft',
          'square feet': 'Sqft',
          'hour': 'Hours',
          'hours': 'Hours',
          'hr': 'Hours',
          'hrs': 'Hours',
          'day': 'Days',
          'days': 'Days',
          'nos': 'Nos',
          'piece': 'Nos',
          'pieces': 'Nos',
          'ltr': 'Ltrs',
          'litres': 'Ltrs',
          'liters': 'Ltrs',
          'cum': 'Cum',
          'cubic': 'Cum',
        };
        bool found = false;
        for (final entry in unitMap.entries) {
          if (t.contains(entry.key)) {
            data.unit = entry.value;
            found = true;
            break;
          }
        }
        if (!found) data.unit = text.trim();
        break;
      case 'Rate':
        final rateNum = RegExp(r'(\d+\.?\d*)').firstMatch(t);
        if (rateNum != null) {
          data.rate = double.tryParse(rateNum.group(0) ?? '');
        }
        break;
      case 'Brand':
        data.brand = text.trim();
        break;
      default:
        break;
    }
    if (text.isNotEmpty) {
      final tempFields = <String, dynamic>{};
      final tempData = _ExtractedData(tempFields);
      _parseTranscriptInto(tempData, text);
      tempFields.forEach((key, value) {
        if (!fields.containsKey(key) && value != null) {
          fields[key] = value;
        }
      });
    }
  }
  void _goToSummary() {
    if (!mounted) return;
    _cancelAllTimers();
    _isListeningForAnswer = false;
    _isProcessing = false;
    setState(() {
      _status = VoiceStatus.summary;
      _rebuildResponse();
    });
    _scrollToBottom();
  }
  String? _derivePhaseId(String? phaseName) {
    if (phaseName == null || phaseName.isEmpty || _data.projectId == null) {
      return null;
    }
    final project = _projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _data.projectId,
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
        _data.projectId == null) {
      return null;
    }
    final project = _projects.cast<ProjectModel?>().firstWhere(
      (p) => p?.id == _data.projectId,
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
  String _mapUnitToBackend(String? rawUnit) {
    if (rawUnit == null || rawUnit.isEmpty) return 'unit';
    final lower = rawUnit.toLowerCase();
    if (lower.contains('bag')) return 'bag';
    if (lower.contains('kg') || lower.contains('kilo')) return 'kg';
    if (lower.contains('ton')) return 'ton';
    if (lower.contains('sqft') || lower.contains('square')) return 'sqft';
    if (lower.contains('sqm') ||
        lower.contains('cum') ||
        lower.contains('cft')) {
      return 'sqm';
    }
    if (lower.contains('day')) return 'day';
    if (lower.contains('hour') || lower.contains('hr')) return 'hour';
    if (lower.contains('ltr') || lower.contains('liter')) return 'ltr';
    if (lower.contains('rft') || lower.contains('running')) return 'rft';
    if (lower.contains('trip') || lower.contains('truck')) return 'truck';
    if (lower.contains('nos') || lower.contains('piece')) return 'unit';
    return 'unit';
  }
  Future<void> _saveEntry() async {
    if (_isProcessing) {
      debugPrint('[AI] Already saving — ignoring duplicate');
      return;
    }
    _isProcessing = true;
    _cancelAllTimers();
    if (!mounted) return;
    setState(() {
      _status = VoiceStatus.saving;
      _saveError = null;
      _rebuildResponse();
    });
    try {
      final String txType = _entryType == 'labour'
          ? 'Wages'
          : _entryType == 'equipment'
          ? 'Expense'
          : 'Materials';
      final double qty = _entryType == 'labour'
          ? ((_data.workerCount ?? 1) * (_data.hours ?? 1)).toDouble()
          : (_data.quantity ?? 0);
      final double rate = _data.rate ?? 0;
      final double fuel = _data.fuelCost ?? 0;
      final double totalAmount = (qty * rate) + fuel;
      final payload = <String, dynamic>{
        'title':
            _data.itemName ??
            (_entryType == 'labour'
                ? 'Labour Log'
                : _entryType == 'equipment'
                ? 'Equipment Rental'
                : 'Material Delivery'),
        'type': txType,
        'project': _data.projectId ?? '',
        'floor': _data.floor ?? '',
        'phase': _data.phase ?? '',
        'phaseId': _derivePhaseId(_data.phase),
        'activity': _data.activity ?? '',
        'activityId': _deriveActivityId(_data.activity),
        'category': _entryType == 'labour'
            ? (_data.workType ?? 'General Labour')
            : _entryType == 'equipment'
            ? (_data.itemName ?? 'Equipment')
            : 'Materials',
        'unit': _mapUnitToBackend(
          _data.unit ?? (_entryType == 'material' ? 'Bags' : 'hour'),
        ),
        'quantity': qty,
        'rate': rate,
        'amount': totalAmount,
        'paymentStatus': 'Pending',
        'paymentMode': 'Cash',
        'paidAmount': 0,
        'date': DateTime.now().toIso8601String(),
        if (_entryType == 'material' && _data.hasBrand) 'brand': _data.brand,
        if (_entryType == 'equipment' && _data.fuelCost != null)
          'fuelCost': fuel,
        'createdBy': UserSession.userId,
      };
      final result = await ApiService.addTransaction(payload);
      if (result != null) {
        final serverTx = result['transaction'] ?? result;
        _savedEntryId =
            serverTx?['_id']?.toString() ??
            'VOICE-${DateTime.now().millisecondsSinceEpoch}';
        if (mounted) {
          await Provider.of<ProjectProvider>(context, listen: false).load();
        }
        _isProcessing = false;
        if (!mounted) return;
        setState(() {
          _status = VoiceStatus.completed;
          _savedEntryId =
              serverTx?['_id']?.toString() ??
              'VOICE-${DateTime.now().millisecondsSinceEpoch}';
          _rebuildResponse();
        });
      } else {
        _isProcessing = false;
        if (!mounted) return;
        setState(() {
          _status = VoiceStatus.summary;
          _saveError = 'Failed to save. Please try again.';
          _rebuildResponse();
        });
      }
    } catch (e) {
      _isProcessing = false;
      if (!mounted) return;
      setState(() {
        _status = VoiceStatus.summary;
        _saveError = 'Error: ${e.toString()}';
        _rebuildResponse();
      });
    }
  }
  void _enterEditMode() {
    _savedEditFields = Map<String, dynamic>.from(_detectedFields);
    _editError = null;
    _editControllers.clear();
    _editControllers['project'] = TextEditingController(
      text: _data.projectName ?? _data.projectId ?? '',
    );
    _editControllers['floor'] = TextEditingController(text: _data.floor ?? '');
    _editControllers['activity'] = TextEditingController(
      text: _data.activity ?? '',
    );
    if (_entryType == 'material') {
      _editControllers['phase'] = TextEditingController(
        text: _data.phase ?? '',
      );
      _editControllers['material'] = TextEditingController(
        text: _data.itemName ?? '',
      );
      _editControllers['quantity'] = TextEditingController(
        text: _data.hasQuantity ? '${_data.quantity}' : '',
      );
      _editControllers['unit'] = TextEditingController(text: _data.unit ?? '');
    } else if (_entryType == 'labour') {
      _editControllers['labourType'] = TextEditingController(
        text: _data.workType ?? _data.itemName ?? '',
      );
      _editControllers['workers'] = TextEditingController(
        text: _data.hasWorkerCount ? '${_data.workerCount}' : '',
      );
      _editControllers['hours'] = TextEditingController(
        text: _data.hasHours ? '${_data.hours}' : '',
      );
    } else {
      _editControllers['equipment'] = TextEditingController(
        text: _data.itemName ?? '',
      );
      _editControllers['hours'] = TextEditingController(
        text: _data.hasQuantity ? '${_data.quantity}' : '',
      );
    }
    _editControllers['rate'] = TextEditingController(
      text: _data.hasRate ? '${_data.rate}' : '',
    );
    setState(() => _isEditing = true);
  }
  void _cancelEdit() {
    if (_savedEditFields != null) {
      _detectedFields.clear();
      _detectedFields.addAll(_savedEditFields!);
    }
    _disposeEditControllers();
    _savedEditFields = null;
    _editError = null;
    setState(() {
      _isEditing = false;
      _rebuildResponse();
    });
  }
  void _disposeEditControllers() {
    for (final ctrl in _editControllers.values) {
      ctrl.dispose();
    }
    _editControllers.clear();
  }
  void _saveEditChanges() {
    _editError = null;
    if (!_isEditValid()) {
      setState(() => _editError = 'Please complete all required fields.');
      return;
    }
    _data.projectName = _editControllers['project']!.text.trim();
    _data.projectId = _editControllers['project']!.text.trim();
    _data.floor = _editControllers['floor']!.text.trim();
    _data.activity = _editControllers['activity']!.text.trim();
    if (_entryType == 'material') {
      _data.phase = _editControllers['phase']!.text.trim();
      _data.itemName = _editControllers['material']!.text.trim();
      _data.quantity = double.tryParse(_editControllers['quantity']!.text) ?? 0;
      _data.unit = _editControllers['unit']!.text.trim();
    } else if (_entryType == 'labour') {
      final labourType = _editControllers['labourType']!.text.trim();
      _data.workType = labourType;
      _data.itemName = labourType;
      _data.workerCount = int.tryParse(_editControllers['workers']!.text) ?? 0;
      _data.hours = double.tryParse(_editControllers['hours']!.text) ?? 0;
    } else {
      _data.itemName = _editControllers['equipment']!.text.trim();
      final hrs = double.tryParse(_editControllers['hours']!.text) ?? 0;
      _data.quantity = hrs;
      _data.hours = hrs;
    }
    _data.rate = double.tryParse(_editControllers['rate']!.text) ?? 0;
    _disposeEditControllers();
    _savedEditFields = null;
    setState(() {
      _isEditing = false;
      _rebuildResponse();
    });
  }
  bool _isEditValid() {
    if (_editControllers['project']?.text.trim().isEmpty ?? true) return false;
    if (_entryType == 'material') {
      if (_editControllers['material']?.text.trim().isEmpty ?? true) {
        return false;
      }
      if ((double.tryParse(_editControllers['quantity']?.text ?? '') ?? 0) <=
          0) {
        return false;
      }
      if (_editControllers['unit']?.text.trim().isEmpty ?? true) return false;
    } else if (_entryType == 'labour') {
      if (_editControllers['labourType']?.text.trim().isEmpty ?? true) {
        return false;
      }
      if ((int.tryParse(_editControllers['workers']?.text ?? '') ?? 0) <= 0) {
        return false;
      }
      if ((double.tryParse(_editControllers['hours']?.text ?? '') ?? 0) <= 0) {
        return false;
      }
    } else {
      if (_editControllers['equipment']?.text.trim().isEmpty ?? true) {
        return false;
      }
      if ((double.tryParse(_editControllers['hours']?.text ?? '') ?? 0) <= 0) {
        return false;
      }
    }
    if ((double.tryParse(_editControllers['rate']?.text ?? '') ?? 0) <= 0) {
      return false;
    }
    return true;
  }
  double _getLiveEditAmount() {
    final rateText = _editControllers['rate']?.text ?? '';
    final rate = double.tryParse(rateText) ?? 0;
    if (_entryType == 'material') {
      final qty =
          double.tryParse(_editControllers['quantity']?.text ?? '') ?? 0;
      return qty * rate;
    } else if (_entryType == 'labour') {
      final workers =
          double.tryParse(_editControllers['workers']?.text ?? '') ?? 0;
      final hours = double.tryParse(_editControllers['hours']?.text ?? '') ?? 0;
      return workers * hours * rate;
    } else {
      final hours = double.tryParse(_editControllers['hours']?.text ?? '') ?? 0;
      return hours * rate;
    }
  }
  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BtField(
        label: label,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: BtText.num(BtText.body(context, weight: FontWeight.w500)),
          decoration: btInput(context),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }
  Widget _buildEditFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtSectionHeader(title: 'Details', caption: true),
        BtCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_entryType == 'material') ...[
                _buildEditField(
                  label: 'Material',
                  controller: _editControllers['material']!,
                ),
                _buildEditField(
                  label: 'Quantity',
                  controller: _editControllers['quantity']!,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _buildEditField(label: 'Unit', controller: _editControllers['unit']!),
              ] else if (_entryType == 'labour') ...[
                _buildEditField(
                  label: 'Labour Type',
                  controller: _editControllers['labourType']!,
                ),
                _buildEditField(
                  label: 'Workers Count',
                  controller: _editControllers['workers']!,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _buildEditField(
                  label: 'Hours Worked',
                  controller: _editControllers['hours']!,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ] else ...[
                _buildEditField(
                  label: 'Equipment',
                  controller: _editControllers['equipment']!,
                ),
                _buildEditField(
                  label: 'Hours Used',
                  controller: _editControllers['hours']!,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              _buildEditField(
                label: 'Rate (₹)',
                controller: _editControllers['rate']!,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BtSectionHeader(title: 'Where', caption: true),
        BtCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEditField(
                label: 'Project',
                controller: _editControllers['project']!,
              ),
              _buildEditField(label: 'Floor', controller: _editControllers['floor']!),
              if (_entryType == 'material')
                _buildEditField(
                  label: 'Phase',
                  controller: _editControllers['phase']!,
                ),
              _buildEditField(
                label: 'Activity',
                controller: _editControllers['activity']!,
              ),
            ],
          ),
        ),
        if (_editError != null) ...[
          const SizedBox(height: 14),
          _inlineError(_editError!, onDark: false),
        ],
      ],
    );
  }
  /// Red notice used for save / edit / mic errors (light or noir surface).
  Widget _inlineError(String message, {required bool onDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: onDark ? Bt.redBright.withValues(alpha: .14) : Bt.redSoft,
        borderRadius: BorderRadius.circular(Bt.rTile),
        border: onDark ? Border.all(color: Bt.redBright.withValues(alpha: .28)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: onDark ? Bt.redBright : Bt.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: BtText.subhead(context, color: onDark ? Bt.bone : Bt.red),
            ),
          ),
        ],
      ),
    );
  }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 250,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }
  List<String> _getStillNeededFieldsFor(_ExtractedData d) {
    final list = <String>[];
    if (_entryType == 'material') {
      if (!d.hasItemName) list.add('Material');
      if (!d.hasQuantity) list.add('Quantity');
      if (!d.hasUnit) list.add('Unit');
      if (!d.hasRate) list.add('Rate');
    } else if (_entryType == 'labour') {
      if (!d.hasItemName) list.add('Labour Type');
      if (!d.hasWorkerCount) list.add('Worker Count');
      if (!d.hasHours) list.add('Hours');
      if (!d.hasRate) list.add('Rate');
    } else if (_entryType == 'equipment') {
      if (!d.hasItemName) list.add('Equipment Name');
      if (!d.hasQuantity) list.add('Hours');
      if (!d.hasRate) list.add('Rate');
    }
    return list;
  }
  List<_DetectedField> _getDetectedFieldsWithLabels(_ExtractedData d) {
    final list = <_DetectedField>[];
    if (_entryType == 'material') {
      if (d.hasItemName) {
        list.add(_DetectedField(label: 'Material', value: d.itemName!));
      }
      if (d.hasQuantity) {
        list.add(_DetectedField(label: 'Quantity', value: '${d.quantity}'));
      }
      if (d.hasUnit) {
        list.add(_DetectedField(label: 'Unit', value: d.unit!));
      }
      if (d.hasRate) {
        list.add(
          _DetectedField(
            label: 'Rate',
            value: '₹ ${d.rate!.toStringAsFixed(0)}',
          ),
        );
      }
    } else if (_entryType == 'labour') {
      if (d.hasItemName) {
        list.add(
          _DetectedField(
            label: 'Labour Type',
            value: d.workType ?? d.itemName!,
          ),
        );
      }
      if (d.hasWorkerCount) {
        list.add(
          _DetectedField(label: 'Worker Count', value: '${d.workerCount}'),
        );
      }
      if (d.hasHours) {
        list.add(_DetectedField(label: 'Hours', value: '${d.hours}'));
      }
      if (d.hasRate) {
        list.add(
          _DetectedField(
            label: 'Rate',
            value: '₹ ${d.rate!.toStringAsFixed(0)}',
          ),
        );
      }
    } else {
      if (d.hasItemName) {
        list.add(_DetectedField(label: 'Equipment Name', value: d.itemName!));
      }
      if (d.hasQuantity) {
        list.add(_DetectedField(label: 'Hours', value: '${d.quantity}'));
      }
      if (d.hasRate) {
        list.add(
          _DetectedField(
            label: 'Rate',
            value: '₹ ${d.rate!.toStringAsFixed(0)}',
          ),
        );
      }
    }
    return list;
  }
  Map<String, dynamic> _getVoiceFields(String entryType, _ExtractedData d) {
    if (entryType == 'material') {
      return {
        'Material': d.itemName,
        'Quantity': d.quantity,
        'Unit': d.unit,
        'Rate': d.rate,
      };
    } else if (entryType == 'labour') {
      return {
        'Labour Type': d.workType ?? d.itemName,
        'Worker Count': d.workerCount,
        'Hours': d.hours,
        'Rate': d.rate,
      };
    } else {
      return {
        'Equipment Name': d.itemName,
        'Hours': d.quantity,
        'Rate': d.rate,
      };
    }
  }
  bool _isVoiceFieldPresent(String key, dynamic val) {
    if (val == null) return false;
    if (val is String) return val.trim().isNotEmpty;
    if (val is num) return val > 0;
    return false;
  }
  bool get _isProjectContextSelected {
    final hasProj = _data.projectId != null && _data.projectId!.isNotEmpty;
    final proj = _selectedProject;
    final projHasFloors = proj?.floors != null && proj!.floors!.isNotEmpty;
    final hasFloor =
        !projHasFloors || (_data.floor != null && _data.floor!.trim().isNotEmpty);
    final hasPhase = _data.phase != null && _data.phase!.trim().isNotEmpty;
    final hasAct = _data.activity != null && _data.activity!.trim().isNotEmpty;
    return hasProj && hasFloor && hasPhase && hasAct;
  }
  /// Listening, processing and the saved moment sit on the noir surface
  /// (Voice-Listening / Saved-Success boards); the AI chat and the review
  /// receipt sit on bone (Voice-Question / Voice-Review boards).
  bool get _isNoirStage {
    switch (_response.status) {
      case VoiceStatus.idle:
      case VoiceStatus.listening:
      case VoiceStatus.processing:
      case VoiceStatus.thinking:
      case VoiceStatus.completed:
        return true;
      default:
        return false;
    }
  }
  String get _entryTypeLabel => _entryType == 'material'
      ? 'Material'
      : _entryType == 'labour'
      ? 'Labour'
      : 'Equipment';
  @override
  Widget build(BuildContext context) {
    Provider.of<ProjectProvider>(context);
    final noir = _isNoirStage;
    final isReview =
        _response.status == VoiceStatus.summary ||
        _response.status == VoiceStatus.saving;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: noir ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: noir ? Bt.noir : Bt.ground,
        body: AnimatedContainer(
          duration: Bt.medium,
          curve: Bt.ease,
          color: noir ? Bt.noir : Bt.ground,
          child: Stack(
            children: [
              if (noir)
                const Positioned.fill(
                  child: IgnorePointer(child: _NoirGlow()),
                ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Stack(
                        children: [
                          _buildMainBody(),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: isReview
                                ? _buildReviewCtaBar()
                                : _buildBottomInputArea(),
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
      ),
    );
  }
  Widget _buildTopBar() {
    String title = 'BuildTrack AI';
    String subtitle = 'AI Voice Entry';
    switch (_response.status) {
      case VoiceStatus.listening:
      case VoiceStatus.idle:
        title = 'BuildTrack AI';
        subtitle = 'AI Voice Entry • $_entryTypeLabel';
        break;
      case VoiceStatus.processing:
      case VoiceStatus.thinking:
        title = 'AI is Thinking...';
        subtitle = 'Analyzing voice input';
        break;
      case VoiceStatus.extracting:
        title = 'Extracted Information';
        subtitle = 'Review details';
        break;
      case VoiceStatus.waitingForUser:
        title = 'BuildTrack AI';
        subtitle = '$_entryTypeLabel entry';
        break;
      case VoiceStatus.summary:
      case VoiceStatus.saving:
        title = 'Review entry';
        subtitle = '$_entryTypeLabel · from your voice';
        break;
      case VoiceStatus.completed:
        title = 'Success';
        subtitle = 'Entry saved';
        break;
      case VoiceStatus.error:
        title = 'Error';
        subtitle = 'Something went wrong';
        break;
    }
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    if (_response.status == VoiceStatus.listening || _response.status == VoiceStatus.idle) {
      title = 'Speak an update';
    }
    final noir = _isNoirStage;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            BtIconButton(
              icon: Icons.close_rounded,
              size: 22,
              semantic: 'Close',
              color: noir ? Bt.bone : Bt.ink,
              background: noir ? Colors.white.withValues(alpha: .09) : null,
              onTap: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: Bt.fast,
                    child: Text(
                      title,
                      key: ValueKey(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BtText.navTitle(context).copyWith(color: noir ? Bt.bone : Bt.ink),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BtText.caption(context, color: noir ? Bt.onNoir2 : Bt.ink3),
                  ),
                ],
              ),
            ),
            SizedBox(width: 92, child: Center(child: _buildStatusBadge(isListening))),
          ],
        ),
      ),
    );
  }
  Widget _buildStatusBadge(bool isListening) {
    final label = isListening ? 'Listening' : 'Ready';
    if (!_isNoirStage) {
      return BtBadge(label: label, tone: isListening ? BtTone.red : BtTone.neutral);
    }
    return AnimatedContainer(
      duration: Bt.fast,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: isListening ? Bt.redBright.withValues(alpha: .18) : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isListening) ...[
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Bt.redBright, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            style: BtText.caption(context, color: isListening ? Bt.bone : Bt.onNoir2, weight: FontWeight.w600).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
  Widget _buildMainBody() {
    Widget content;
    String stage;
    double bottomPad;
    final curData = _currentData;
    switch (_response.status) {
      case VoiceStatus.processing:
      case VoiceStatus.thinking:
        stage = 'processing';
        bottomPad = 40;
        content = _buildProcessingCard();
        break;
      case VoiceStatus.completed:
        stage = 'saved';
        bottomPad = 32;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSuccessCard(),
            if (_saveError != null) _buildErrorCard(),
          ],
        );
        break;
      case VoiceStatus.summary:
      case VoiceStatus.saving:
        stage = 'review';
        bottomPad = 132;
        content = _buildSummaryCard();
        break;
      default:
        if (_isNoirStage) {
          stage = 'voice';
          bottomPad = 360;
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_saveError != null) _buildErrorCard(),
              _buildVoiceListeningCard(),
              _buildExampleHintCard(),
              _buildAiUnderstandingPanel(curData),
              _buildMissingInformationPanel(curData),
            ],
          );
        } else {
          stage = 'chat';
          bottomPad = 120;
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAiUnderstandingPanel(curData),
              if (_saveError != null) _buildErrorCard(),
              _buildExampleHintCard(),
              _buildVoiceListeningCard(),
              _buildAiQuestionCard(),
              _buildMissingInformationPanel(curData),
            ],
          );
        }
        break;
    }
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(Bt.gutter, 8, Bt.gutter, bottomPad),
      child: AnimatedSwitcher(
        duration: Bt.medium,
        switchInCurve: Bt.ease,
        switchOutCurve: Curves.easeOut,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(stage), child: content),
      ),
    );
  }
  /// Noir: the live transcript in big display type, older words dimmed.
  /// Chat: what the user said, as ink bubbles.
  Widget _buildVoiceListeningCard() {
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    final hasContent = _partialAnswer.isNotEmpty || _rawTranscript.isNotEmpty;
    if (!isListening && !hasContent) return const SizedBox.shrink();
    final displayText = hasContent
        ? (_partialAnswer.isNotEmpty ? _partialAnswer : _rawTranscript)
        : 'Listening for voice input...';
    if (_isNoirStage) {
      return Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isListening)
              _buildSmallMicListening()
            else
              Text('YOU SAID', style: BtText.mono(context, color: Bt.onNoir2)),
            const SizedBox(height: 16),
            _buildLiveTranscript(displayText, hasContent: hasContent, isListening: isListening),
          ],
        ),
      );
    }
    final bubbles = <Widget>[];
    if (_rawTranscript.isNotEmpty) bubbles.add(_meBubble(_rawTranscript));
    if (_partialAnswer.isNotEmpty && _partialAnswer != _rawTranscript) {
      bubbles.add(_meBubble(_partialAnswer, live: isListening));
    } else if (isListening && _partialAnswer.isEmpty) {
      bubbles.add(_meBubble('Listening for voice input...', live: true, placeholder: true));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bubbles.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            bubbles[i],
          ],
        ],
      ),
    );
  }
  Widget _buildLiveTranscript(String text, {required bool hasContent, required bool isListening}) {
    final base = BtText.display(const TextStyle(
      fontSize: 29,
      height: 1.22,
      fontWeight: FontWeight.w600,
      letterSpacing: -.9,
      color: Bt.bone,
    ));
    final spans = <InlineSpan>[];
    if (!hasContent) {
      spans.add(TextSpan(text: text, style: base.copyWith(color: Bt.onNoir3)));
    } else {
      final words = text.trim().split(RegExp(r'\s+'));
      final dimCount = isListening ? math.max(0, words.length - 6) : 0;
      if (dimCount > 0) {
        spans.add(TextSpan(
          text: '${words.take(dimCount).join(' ')} ',
          style: base.copyWith(color: Bt.bone.withValues(alpha: .42)),
        ));
      }
      spans.add(TextSpan(text: words.skip(dimCount).join(' '), style: base));
    }
    if (isListening) {
      spans.add(const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(padding: EdgeInsets.only(left: 4), child: _BlinkingCursor()),
      ));
    }
    return Text.rich(TextSpan(children: spans));
  }
  Widget _meBubble(String text, {bool live = false, bool placeholder = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: AnimatedContainer(
        duration: Bt.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: live ? Bt.ink.withValues(alpha: .82) : Bt.ink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: BtText.subhead(context, color: placeholder ? Bt.onNoir2 : Bt.bone).copyWith(
            fontStyle: live ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
  Widget _aiBubble(Widget child, {bool mark = true}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (mark) const _BrickMark() else const SizedBox(width: 28),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Bt.card,
                boxShadow: Bt.shadow,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildAiUnderstandingPanel(_ExtractedData currentData) {
    final voiceFields = _getVoiceFields(_entryType, currentData);
    final total = voiceFields.length;
    int completed = 0;
    voiceFields.forEach((key, val) {
      if (_isVoiceFieldPresent(key, val)) completed++;
    });
    final isComplete = completed >= total;
    final noir = _isNoirStage;
    return Padding(
      padding: EdgeInsets.only(top: noir ? 0 : 4, bottom: noir ? 20 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text('UNDERSTOOD SO FAR', style: BtText.mono(context, color: noir ? Bt.onNoir2 : Bt.ink3)),
            ),
            Text(
              '$completed OF $total',
              style: BtText.num(BtText.mono(
                context,
                color: isComplete ? (noir ? Bt.greenBright : Bt.green) : (noir ? Bt.onNoir2 : Bt.ink3),
              )),
            ),
          ]),
          const SizedBox(height: 10),
          BtBricks(value: total > 0 ? completed / total : 0, count: 20, height: 9, onDark: noir),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: voiceFields.entries.map((e) {
              final isPresent = _isVoiceFieldPresent(e.key, e.value);
              final displayVal = e.value is num
                  ? (e.value as num).toStringAsFixed(e.value % 1 == 0 ? 0 : 2)
                  : e.value?.toString() ?? '';
              return AnimatedContainer(
                duration: Bt.fast,
                curve: Bt.ease,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: isPresent
                      ? (noir ? Colors.white.withValues(alpha: .08) : Bt.card)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Bt.rChip),
                  border: Border.all(
                    color: isPresent
                        ? (noir ? Colors.white.withValues(alpha: .12) : Bt.line)
                        : (noir ? Colors.white.withValues(alpha: .14) : Bt.inputBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPresent ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: isPresent
                          ? (noir ? Bt.greenBright : Bt.green)
                          : (noir ? Bt.onNoir3 : Bt.placeholder),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isPresent ? '${e.key}: $displayVal' : e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BtText.caption(
                          context,
                          weight: isPresent ? FontWeight.w600 : FontWeight.w500,
                          color: isPresent ? (noir ? Bt.bone : Bt.ink) : (noir ? Bt.onNoir3 : Bt.ink3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  /// Missing fields are shown inline in "Understood so far" (unchecked pills).
  Widget _buildMissingInformationPanel(_ExtractedData currentData) => const SizedBox.shrink();
  Widget _buildExampleHintCard() {
    String example = "";
    if (_entryType == 'material') {
      example = '"20 bags of UltraTech cement at 420 rupees per bag"';
    } else if (_entryType == 'labour') {
      example = '"8 masons worked 9 hours at 850 rupees"';
    } else {
      example = '"JCB excavator worked 6 hours at 1200 rupees per hour"';
    }
    final hasContent = _partialAnswer.isNotEmpty || _rawTranscript.isNotEmpty;
    if (hasContent) return const SizedBox.shrink();
    final noir = _isNoirStage;
    if (noir) {
      return Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRY SAYING', style: BtText.mono(context, color: Bt.onNoir2)),
            const SizedBox(height: 14),
            Text(
              example,
              style: BtText.display(const TextStyle(
                fontSize: 26,
                height: 1.24,
                fontWeight: FontWeight.w600,
                letterSpacing: -.8,
                color: Bt.onNoir3,
              )),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Bt.ink3, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Try saying ', style: BtText.subhead(context)),
              TextSpan(text: example, style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w500)),
            ])),
          ),
        ],
      ),
    );
  }
  Widget _buildAiQuestionCard() {
    final isAskingStep = _response.status == VoiceStatus.waitingForUser;
    if (!isAskingStep) return const SizedBox.shrink();
    final field = _fieldToAsk();
    final question = _response.question?.isNotEmpty == true
        ? _response.question!
        : (field != null ? _questionForField(field) : '');
    final suggestions = _backendSuggestions.isNotEmpty
        ? _backendSuggestions
        : (field != null ? _suggestionsForField(field) : <String>[]);
    debugPrint(
      '[AI DEBUG] _buildAiQuestionCard: showing question="$question" for field=$field',
    );
    final confirmed = _getDetectedFieldsWithLabels(_data).take(3).toList();
    return KeyedSubtree(
      key: ValueKey('q:$question'),
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (confirmed.isNotEmpty) ...[
              BtReveal(
                index: 0,
                child: _aiBubble(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        confirmed.length == 1 ? 'Great. I found:' : 'I have:',
                        style: BtText.subhead(context),
                      ),
                      const SizedBox(height: 6),
                      ...confirmed.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: Bt.green),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${f.label}: ${f.value}',
                                  overflow: TextOverflow.ellipsis,
                                  style: BtText.num(BtText.subhead(context, color: Bt.ink, weight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  mark: false,
                ),
              ),
              const SizedBox(height: 8),
            ],
            BtReveal(
              index: 1,
              child: _aiBubble(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question, style: BtText.headline(context)),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('COMMON OPTIONS', style: BtText.mono(context)),
                      const SizedBox(height: 8),
                      _buildSuggestionsChips(suggestions),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSuggestionsChips(List<String> options) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options
          .map((opt) => BtChip(label: opt, onTap: () => _handleTypedAnswer(opt)))
          .toList(),
    );
  }
  Widget _buildProcessingCard() {
    final stages = <String>[];
    final states = <bool>[];
    final hasMaterial = _data.hasItemName;
    final hasQuantity = _data.hasQuantity;
    final hasUnit = _data.hasUnit;
    final hasRate = _data.hasRate;
    if (_entryType == 'material') {
      stages.add(hasMaterial ? 'Material identified' : 'Finding material');
      states.add(hasMaterial);
      stages.add(hasQuantity ? 'Quantity detected' : 'Detecting quantity');
      states.add(hasQuantity);
      stages.add(hasUnit ? 'Unit identified' : 'Finding unit');
      states.add(hasUnit);
      stages.add(hasRate ? 'Rate detected' : 'Detecting rate');
      states.add(hasRate);
    } else if (_entryType == 'labour') {
      stages.add(
        hasMaterial ? 'Labour type identified' : 'Finding labour type',
      );
      states.add(hasMaterial);
      stages.add(
        _data.hasWorkerCount
            ? 'Worker count detected'
            : 'Extracting worker count',
      );
      states.add(_data.hasWorkerCount);
      stages.add(_data.hasHours ? 'Hours detected' : 'Extracting hours');
      states.add(_data.hasHours);
      stages.add(hasRate ? 'Rate detected' : 'Detecting rate');
      states.add(hasRate);
    } else {
      stages.add(hasMaterial ? 'Equipment identified' : 'Finding equipment');
      states.add(hasMaterial);
      stages.add(hasQuantity ? 'Hours detected' : 'Extracting hours');
      states.add(hasQuantity);
      stages.add(hasRate ? 'Rate detected' : 'Detecting rate');
      states.add(hasRate);
    }
    final accent = context.bt.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        BtReveal(
          index: 0,
          child: Row(
            children: [
              Text('BUILDTRACK AI', style: BtText.mono(context, color: Bt.onNoir2)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_entryType.toUpperCase(), style: BtText.mono(context, color: accent)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BtReveal(
          index: 1,
          child: Text('Analyzing Entry...', style: BtText.d1(context, color: Bt.bone)),
        ),
        if (_rawTranscript.isNotEmpty) ...[
          const SizedBox(height: 12),
          BtReveal(
            index: 2,
            child: Text(
              _rawTranscript,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: BtText.body(context, color: Bt.onNoir2),
            ),
          ),
        ],
        const SizedBox(height: 28),
        BtReveal(
          index: 3,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(Bt.rCard),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EXTRACTING DETAILS...', style: BtText.mono(context, color: Bt.onNoir2)),
                const SizedBox(height: 8),
                ...List.generate(stages.length, (i) {
                  final label = stages[i];
                  final isCompleted = i < _processingStage;
                  final isCurrent = i == _processingStage;
                  Widget indicator;
                  Color textColor;
                  FontWeight fontWeight;
                  if (isCompleted) {
                    if (states[i]) {
                      indicator = const Icon(Icons.check_circle_rounded, color: Bt.greenBright, size: 18);
                      textColor = Bt.bone;
                      fontWeight = FontWeight.w600;
                    } else {
                      indicator = Icon(Icons.refresh_rounded, color: accent, size: 18);
                      textColor = Bt.onNoir2;
                      fontWeight = FontWeight.w500;
                    }
                  } else if (isCurrent) {
                    indicator = SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    );
                    textColor = accent;
                    fontWeight = FontWeight.w600;
                  } else {
                    indicator = Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: .28), width: 1.5),
                      ),
                    );
                    textColor = Bt.onNoir3;
                    fontWeight = FontWeight.w500;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        SizedBox(width: 20, child: Center(child: indicator)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: Bt.fast,
                            style: BtText.subhead(context, color: textColor, weight: fontWeight),
                            child: Text(
                              isCompleted
                                  ? (states[i]
                                        ? label
                                        : 'Finding ${stages[i].split(" ").last}...')
                                  : (isCurrent ? '$label...' : label),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        BtReveal(
          index: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Bt.onNoir3, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: You can keep the app open. We\'ll notify you when ready.',
                  style: BtText.caption(context, color: Bt.onNoir2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  /// Review "receipt" (Voice-Review board): ink card with perforation, the
  /// voice-filled figures marked with an accent dot, then the Where group.
  Widget _buildSummaryCard() {
    final amount = _isEditing
        ? _getLiveEditAmount()
        : _data.getComputedAmount(_entryType);
    final accent = context.bt.accent;
    final title = _data.itemName ??
        (_entryType == 'labour'
            ? 'Labour Log'
            : _entryType == 'equipment'
            ? 'Equipment Entry'
            : 'Material Entry');
    // Figures on the receipt — same labels/values as the original summary.
    final figures = <(String, String, bool)>[
      if (_entryType == 'material') ...[
        (
          'Quantity',
          _data.hasQuantity ? '${_data.quantity} ${_data.unit ?? ''}'.trim() : '—',
          _data.hasQuantity,
        ),
      ] else if (_entryType == 'labour') ...[
        ('Labour Type', _data.workType ?? '—', _data.workType != null),
        ('Worker Count', _data.hasWorkerCount ? '${_data.workerCount}' : '—', _data.hasWorkerCount),
        ('Hours', _data.hasHours ? '${_data.hours} ${_data.unit ?? 'Hours'}' : '—', _data.hasHours),
      ] else ...[
        ('Hours', _data.hasQuantity ? '${_data.quantity} ${_data.unit ?? 'Hours'}' : '—', _data.hasQuantity),
      ],
      ('Rate', _data.hasRate ? '₹ ${_data.rate!.toStringAsFixed(0)}' : '—', _data.hasRate),
      if (_entryType == 'equipment' && _data.hasFuelCost)
        ('Fuel Cost', '₹ ${_data.fuelCost!.toStringAsFixed(0)}', true),
    ];
    final where = <(String, String)>[
      ('Project', _data.projectName ?? _data.projectId ?? '—'),
      ('Floor', _data.floor ?? '—'),
      if (_entryType == 'material') ('Phase', _data.phase ?? '—'),
      ('Activity', _data.activity ?? '—'),
    ];
    final typeLine = _entryType == 'material'
        ? 'MATERIAL'
        : _entryType == 'labour'
        ? 'LABOUR'
        : 'EQUIPMENT';
    Widget aiDot() => Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
    );
    final receipt = Container(
      decoration: BoxDecoration(
        color: Bt.noir,
        borderRadius: BorderRadius.circular(Bt.rCard),
        boxShadow: Bt.shadowLg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Bt.rCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('$typeLine · FROM YOUR VOICE', style: BtText.mono(context, color: Bt.onNoir2)),
                      ),
                      Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(11)),
                        child: Text(
                          'AI filled',
                          style: BtText.caption(context, color: context.bt.onAccent, weight: FontWeight.w600).copyWith(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(title, style: BtText.d3(context, color: Bt.bone)),
                  const SizedBox(height: 2),
                  Text('Entry summary', style: BtText.caption(context, color: Bt.onNoir2)),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in figures)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(f.$1, style: BtText.subhead(context, color: Bt.onNoir2)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (f.$3) aiDot(),
                                Flexible(
                                  child: Text(
                                    f.$2,
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
                                    style: BtText.num(BtText.subhead(context, color: Bt.bone, weight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Amount', style: BtText.headline(context).copyWith(color: Bt.bone)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: amount > 0
                              ? BtCountUp(
                                  value: amount,
                                  format: (v) => '₹ ${v.toStringAsFixed(0)}',
                                  style: BtText.d2(context, color: Bt.bone),
                                )
                              : Text('—', style: BtText.d2(context, color: Bt.onNoir3)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        BtReveal(index: 0, child: receipt),
        const SizedBox(height: 26),
        if (_isEditing)
          BtReveal(index: 1, child: _buildEditFormFields())
        else ...[
          BtReveal(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BtSectionHeader(title: 'Where', caption: true),
                BtGroup(
                  children: [
                    for (final w in where) BtValueRow(label: w.$1, value: w.$2),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BtReveal(
            index: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                aiDot(),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'Marked figures were filled from your voice. Tip: You can keep the app open. We\'ll notify you when ready.',
                    style: BtText.caption(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  Widget _buildReviewCtaBar() {
    final isSaving = _response.status == VoiceStatus.saving;
    if (_isEditing) {
      return BtCtaBar(children: [
        SizedBox(
          width: 116,
          child: BtButton(label: 'Cancel', variant: BtButtonVariant.destructive, onPressed: _cancelEdit),
        ),
        Expanded(child: BtButton(label: 'Save Changes', icon: Icons.check_rounded, onPressed: _saveEditChanges)),
      ]);
    }
    return BtCtaBar(children: [
      SizedBox(
        width: 116,
        child: BtButton(
          label: 'Edit',
          icon: Icons.edit_outlined,
          variant: BtButtonVariant.secondary,
          onPressed: isSaving ? null : _enterEditMode,
        ),
      ),
      Expanded(
        child: BtButton(
          label: 'Confirm & Save',
          icon: Icons.check_rounded,
          loading: isSaving,
          onPressed: isSaving ? null : _saveEntry,
        ),
      ),
    ]);
  }
  Widget _buildBottomInputArea() {
    if (_response.status == VoiceStatus.completed) {
      return const SizedBox.shrink();
    }
    if (_response.status == VoiceStatus.summary ||
        _response.status == VoiceStatus.saving) {
      return const SizedBox.shrink();
    }
    if (_response.status == VoiceStatus.processing ||
        _response.status == VoiceStatus.thinking) {
      return const SizedBox.shrink();
    }
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    final isInitialVoice =
        _response.status == VoiceStatus.listening ||
        _response.status == VoiceStatus.idle;
    final isAskingStep = _response.status == VoiceStatus.waitingForUser;
    if (isInitialVoice) {
      // Voice-Listening dock: waveform, accent orb with ripples, actions.
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [.78, 1],
            colors: [Bt.noir, Bt.noir.withValues(alpha: 0)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Bt.gutter, 36, Bt.gutter, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  duration: Bt.fast,
                  opacity: isListening ? 1 : 0,
                  child: BtWave(active: isListening, bars: 18, height: 48, barWidth: 4),
                ),
                const SizedBox(height: 26),
                _buildLargeMicButtonRedesigned(isListening),
                const SizedBox(height: 26),
                AnimatedSwitcher(
                  duration: Bt.fast,
                  child: KeyedSubtree(
                    key: ValueKey('dock:$isListening'),
                    child: isListening
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: Text(
                                  'Tap to stop. We\'ll fill in the details from what you said.',
                                  textAlign: TextAlign.center,
                                  style: BtText.subhead(context, color: Bt.onNoir2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildCancelRecordingButton()),
                                  const SizedBox(width: 10),
                                  Expanded(child: _buildRedStopAnalyzeButton()),
                                ],
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildRecordingStatusLeft(isListening),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!isAskingStep) return const SizedBox.shrink();
    // Voice-Question composer: text field + round accent mic.
    final bt = context.bt;
    Widget row;
    String mode;
    if (isListening) {
      mode = 'listening';
      row = Row(
        children: [
          BtWave(active: isListening, bars: 5, height: 22),
          const SizedBox(width: 12),
          Expanded(child: _buildSmallMicListening(onDark: false)),
          BtButton(
            label: 'Done Answering',
            icon: Icons.stop_rounded,
            small: true,
            expand: false,
            variant: BtButtonVariant.accent,
            onPressed: _stopAnswerListening,
          ),
        ],
      );
    } else if (_showKeyboardInput) {
      mode = 'keyboard';
      OutlineInputBorder pill(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: c, width: w),
      );
      row = Row(
        children: [
          _roundAction(
            icon: Icons.mic_rounded,
            semantic: 'Answer by voice',
            background: Bt.card,
            foreground: Bt.ink,
            onTap: () => setState(() => _showKeyboardInput = false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              focusNode: _focusNode,
              style: BtText.body(context),
              textInputAction: TextInputAction.send,
              decoration: btInput(context, hint: _hintForCurrentStep).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: pill(Bt.inputBorder),
                enabledBorder: pill(Bt.inputBorder),
                focusedBorder: pill(Bt.ink, 2),
              ),
              onSubmitted: _handleTypedAnswer,
            ),
          ),
          const SizedBox(width: 8),
          _roundAction(
            icon: Icons.arrow_upward_rounded,
            semantic: 'Send answer',
            background: bt.accent,
            foreground: bt.onAccent,
            onTap: () => _handleTypedAnswer(_textCtrl.text),
          ),
        ],
      );
    } else {
      mode = 'voice';
      row = Row(
        children: [
          Expanded(
            child: BtPressable(
              semanticLabel: 'Type an answer',
              onTap: () {
                setState(() => _showKeyboardInput = true);
                _focusNode.requestFocus();
              },
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Bt.card,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Bt.inputBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.keyboard_outlined, color: Bt.ink3, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Type an answer…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BtText.body(context, color: Bt.placeholder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildMicWithWaves(),
        ],
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Bt.ground,
        boxShadow: [BoxShadow(color: Bt.line, offset: Offset(0, -1))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Bt.gutter, 12, Bt.gutter, 12),
          child: AnimatedSwitcher(
            duration: Bt.fast,
            child: KeyedSubtree(key: ValueKey(mode), child: row),
          ),
        ),
      ),
    );
  }
  Widget _roundAction({
    required IconData icon,
    required String semantic,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return BtPressable(
      onTap: onTap,
      scale: .92,
      semanticLabel: semantic,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: background == Bt.card ? Border.all(color: Bt.inputBorder) : null,
        ),
        child: Icon(icon, color: foreground, size: 22),
      ),
    );
  }
  Widget _buildRecordingStatusLeft(bool isListening) {
    if (!_isProjectContextSelected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('RECORDING STATUS', style: BtText.mono(context, color: Bt.onNoir3)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 15, color: Bt.amberBright),
              const SizedBox(width: 6),
              Text('Context Locked', style: BtText.subhead(context, color: Bt.bone, weight: FontWeight.w600)),
            ],
          ),
        ],
      );
    }
    if (!isListening) {
      return Text('Ready · tap the mic and speak', textAlign: TextAlign.center, style: BtText.subhead(context, color: Bt.onNoir2));
    }
    return AnimatedBuilder(
      animation: _voiceCtrl,
      builder: (context, _) {
        final timer = _voiceCtrl.elapsedDisplay;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RECORDING STATUS', style: BtText.mono(context, color: Bt.onNoir3)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Bt.redBright)),
                const SizedBox(width: 6),
                Text('Listening ($timer)', style: BtText.num(BtText.subhead(context, color: Bt.bone, weight: FontWeight.w600))),
              ],
            ),
          ],
        );
      },
    );
  }
  /// The accent voice orb (Voice-Listening board). Ripples + glow only while
  /// the engine is actually listening.
  Widget _buildLargeMicButtonRedesigned(bool isListening) {
    final isEnabled = _isProjectContextSelected;
    final accent = context.bt.accent;
    const size = 112.0;
    return Center(
      child: Semantics(
        button: true,
        label: isListening ? 'Listening' : 'Start recording',
        child: BtPulse(
          active: isListening,
          size: size,
          color: accent.withValues(alpha: .7),
          child: BtPressable(
            scale: .94,
            // As in the original: while listening the orb is display-only;
            // Cancel / Stop & Analyze are the controls.
            onTap: isEnabled && !isListening ? _startInitialRecording : null,
            child: AnimatedContainer(
              duration: Bt.medium,
              curve: Bt.ease,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnabled ? null : Colors.white.withValues(alpha: .07),
                border: isEnabled ? null : Border.all(color: Colors.white.withValues(alpha: .14)),
                gradient: isEnabled
                    ? RadialGradient(
                        center: const Alignment(-.3, -.4),
                        radius: .9,
                        colors: [
                          Color.lerp(accent, Colors.white, .32)!,
                          accent,
                          Color.lerp(accent, Colors.black, .3)!,
                        ],
                        stops: const [0, .55, 1],
                      )
                    : null,
                boxShadow: isEnabled
                    ? [
                        BoxShadow(color: accent.withValues(alpha: .14), spreadRadius: 10),
                        BoxShadow(color: accent.withValues(alpha: isListening ? .38 : .22), blurRadius: 70, spreadRadius: 6),
                      ]
                    : null,
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: isEnabled ? Bt.noir : Bt.onNoir3,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildRedStopAnalyzeButton() {
    return BtButton(
      label: 'Stop & Analyze',
      icon: Icons.auto_awesome_rounded,
      variant: BtButtonVariant.accent,
      onPressed: _stopAndAnalyze,
    );
  }
  Widget _buildCancelRecordingButton() {
    return BtButton(
      label: 'Cancel',
      variant: BtButtonVariant.onDark,
      onPressed: _cancelRecording,
    );
  }
  /// Round accent mic in the chat composer (Voice-Question board).
  Widget _buildMicWithWaves() {
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    final bt = context.bt;
    return BtPulse(
      active: isListening,
      size: 50,
      child: _roundAction(
        icon: isListening ? Icons.stop_rounded : Icons.mic_rounded,
        semantic: isListening ? 'Done answering' : 'Answer by voice',
        background: bt.accent,
        foreground: bt.onAccent,
        onTap: isListening ? _stopAnswerListening : _startAnswerListening,
      ),
    );
  }
  /// "● LISTENING · 0:07" — live recording line with the session timer.
  Widget _buildSmallMicListening({bool onDark = true}) {
    return AnimatedBuilder(
      animation: _voiceCtrl,
      builder: (_, _) {
        final timer = _voiceCtrl.elapsedDisplay;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: onDark ? Bt.redBright : Bt.red),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'LISTENING · $timer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BtText.num(BtText.mono(context, color: onDark ? Bt.onNoir2 : Bt.ink2, size: 11)),
              ),
            ),
          ],
        );
      },
    );
  }
  /// Saved moment (Saved-Success board): bags drop and stack on the noir
  /// surface, then the entry receipt and the two existing next steps.
  Widget _buildSuccessCard() {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)}'
        ' ${now.year}, '
        '${(now.hour % 12 == 0 ? 12 : now.hour % 12)}'
        ':${now.minute.toString().padLeft(2, '0')}'
        ' ${now.hour >= 12 ? 'PM' : 'AM'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Center(child: _SavedBagsStack(label: _entryType.toUpperCase())),
        const SizedBox(height: 36),
        BtReveal(
          index: 6,
          child: Column(
            children: [
              Text('ENTRY SAVED', textAlign: TextAlign.center, style: BtText.mono(context, color: context.bt.accent)),
              const SizedBox(height: 10),
              Text(
                'Entry Saved Successfully!',
                textAlign: TextAlign.center,
                style: BtText.d2(context, color: Bt.bone),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'Your $_entryType entry has been saved and added to today\'s log.',
                  textAlign: TextAlign.center,
                  style: BtText.body(context, color: Bt.onNoir2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        BtReveal(
          index: 7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              children: [
                _successDetailRow(
                  'Entry ID',
                  '#${_savedEntryId?.substring(math.max(0, (_savedEntryId?.length ?? 4) - 8)) ?? 'NEW'}',
                ),
                Container(height: 1, color: Colors.white.withValues(alpha: .08)),
                _successDetailRow('Date & Time', dateStr),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        BtReveal(
          index: 8,
          child: Column(
            children: [
              BtButton(
                label: 'Add Another Entry',
                variant: BtButtonVariant.accent,
                onPressed: () => Navigator.pushNamed(context, '/add-entry'),
              ),
              const SizedBox(height: 10),
              BtButton(
                label: 'View All Entries',
                variant: BtButtonVariant.onDark,
                onPressed: () => Navigator.pushNamed(context, '/logs'),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildErrorCard() {
    final completed = _response.status == VoiceStatus.completed;
    return Padding(
      padding: EdgeInsets.only(top: completed ? 14 : 4, bottom: completed ? 0 : 14),
      child: _inlineError(_saveError ?? '', onDark: _isNoirStage),
    );
  }
  Widget _successDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Text(label, style: BtText.subhead(context, color: Bt.onNoir2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: BtText.num(BtText.subhead(context, color: Bt.bone, weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
  String get _hintForCurrentStep {
    final field = _activeField;
    if (field == null) return 'Type your answer...';
    switch (field) {
      case 'Project':
        return 'Type or say project name...';
      case 'Floor':
        return 'e.g. Ground Floor, 1st Floor...';
      case 'Phase':
        return 'e.g. Foundation Work...';
      case 'Activity':
        return 'e.g. Column Casting, PCC...';
      case 'Labour Type':
        return 'e.g. Mason, Helper, Carpenter...';
      case 'Worker Count':
        return 'e.g. 5, 8, 12...';
      case 'Hours':
        return 'e.g. 6, 8, 10 hours...';
      case 'Equipment':
        return 'e.g. JCB Excavator, Crane...';
      case 'Fuel':
        return 'e.g. 500, 1200 or 0 for none...';
      case 'Quantity':
        return 'Enter quantity...';
      case 'Unit':
        return 'e.g. Bags, Kg, Hours...';
      case 'Rate':
        return 'Rate in ₹ per unit...';
      case 'Brand':
        return 'e.g. UltraTech, Tata...';
      default:
        return 'Type your answer...';
    }
  }
  String _monthName(int m) {
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
    return months[(m - 1).clamp(0, 11)];
  }
}
/// Soft accent glow behind the noir voice surface (static — no animation).
class _NoirGlow extends StatelessWidget {
  const _NoirGlow();
  @override
  Widget build(BuildContext context) {
    final accent = context.bt.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, 1.05),
          radius: 1.1,
          colors: [accent.withValues(alpha: .16), accent.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
/// Small BuildTrack "brick" avatar for AI chat bubbles.
class _BrickMark extends StatelessWidget {
  const _BrickMark();
  @override
  Widget build(BuildContext context) {
    final accent = context.bt.accent;
    Widget brick() => Container(
      width: 6,
      height: 3,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(1)),
    );
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: Bt.ink, borderRadius: BorderRadius.circular(9)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          brick(),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [brick(), brick()]),
        ],
      ),
    );
  }
}
/// Receipt perforation: a row of bone "punch holes" across the ink card.
class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 14,
        width: double.infinity,
        child: CustomPaint(painter: _PerforationPainter(Bt.ground)),
      ),
    );
  }
}
class _PerforationPainter extends CustomPainter {
  _PerforationPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x <= size.width + 9; x += 18) {
      canvas.drawCircle(Offset(x, size.height / 2), 6, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _PerforationPainter old) => old.color != color;
}
/// Saved-Success board: cement bags drop and stack, then a check pops.
/// Plays once per mount; static under reduce-motion.
class _SavedBagsStack extends StatefulWidget {
  const _SavedBagsStack({required this.label});
  final String label;
  @override
  State<_SavedBagsStack> createState() => _SavedBagsStackState();
}
class _SavedBagsStackState extends State<_SavedBagsStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  // (left, bottom, start) — positions from the board's 260×200 stage.
  static const _bags = <(double, double, double)>[
    (4, 1, .07),
    (92, 1, .15),
    (180, 1, .22),
    (48, 42, .32),
    (136, 42, .40),
    (92, 83, .50),
  ];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Bt.reduceMotion(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  double _iv(double a, double b, Curve curve) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));
  Widget _bag({required bool top, required Color accent}) {
    return Container(
      width: 76,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: top
              ? [Color.lerp(accent, Colors.white, .15)!, accent]
              : const [Color(0xFFE9E4D8), Color(0xFFCFC7B5)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 10), blurRadius: 18, spreadRadius: -10),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            right: 8,
            top: 6,
            child: Container(height: 1, color: Colors.black.withValues(alpha: .12)),
          ),
          if (top)
            Center(
              child: Text(
                widget.label,
                maxLines: 1,
                style: BtText.mono(context, color: Bt.noir, size: 8.5),
              ),
            ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final accent = context.bt.accent;
    return RepaintBoundary(
      child: SizedBox(
        width: 260,
        height: 200,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -30,
                right: -30,
                bottom: 0,
                child: Container(height: 1, color: Bt.bone.withValues(alpha: .25)),
              ),
              for (var i = 0; i < _bags.length; i++)
                Positioned(
                  left: _bags[i].$1,
                  bottom: _bags[i].$2,
                  child: Opacity(
                    opacity: _iv(_bags[i].$3, _bags[i].$3 + .06, Curves.linear),
                    child: Transform.translate(
                      offset: Offset(0, -150 * (1 - _iv(_bags[i].$3, _bags[i].$3 + .26, Curves.bounceOut))),
                      child: _bag(top: i == _bags.length - 1, accent: accent),
                    ),
                  ),
                ),
              Positioned(
                right: -6,
                top: 4,
                child: Transform.scale(
                  scale: _iv(.68, .86, Bt.spring),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Bt.greenBright,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Bt.greenBright.withValues(alpha: .18), spreadRadius: 8)],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
