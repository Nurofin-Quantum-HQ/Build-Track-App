import 'dart:async';
import 'dart:math' as math;
import 'package:buildtrack_mobile/common/controllers/voice_recording_controller.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
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
      child: Container(width: 2, height: 18, color: AppColors.primary),
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
  int _processingStage = 0;
  Timer? _processingTimer;
  Timer? _answerTimeoutTimer;
  @override
  void initState() {
    super.initState();
    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _micOrbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
        setState(() {
          _saveError = _voiceCtrl.errorMessage;
          _status = VoiceStatus.idle;
          _isListeningForAnswer = false;
          _rebuildResponse();
        });
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
      debugPrint('[VOICE] No transcript captured — restarting');
      setState(() => _status = VoiceStatus.listening);
      _startInitialRecording();
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
        return [
          'Ground Floor',
          '1st Floor',
          '2nd Floor',
          '3rd Floor',
          'Basement',
          'Terrace',
        ];
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(height: 1, color: Color(0xFFF7F5FC)),
        ],
      ),
    );
  }
  Widget _buildEditFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEditField(
          label: 'Project',
          controller: _editControllers['project']!,
        ),
        if (_entryType == 'material') ...[
          _buildEditField(
            label: 'Material',
            controller: _editControllers['material']!,
          ),
          _buildEditField(
            label: 'Quantity',
            controller: _editControllers['quantity']!,
            keyboardType: TextInputType.number,
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
            keyboardType: TextInputType.number,
          ),
          _buildEditField(
            label: 'Hours Worked',
            controller: _editControllers['hours']!,
            keyboardType: TextInputType.number,
          ),
        ] else ...[
          _buildEditField(
            label: 'Equipment',
            controller: _editControllers['equipment']!,
          ),
          _buildEditField(
            label: 'Hours Used',
            controller: _editControllers['hours']!,
            keyboardType: TextInputType.number,
          ),
        ],
        _buildEditField(
          label: 'Rate (₹)',
          controller: _editControllers['rate']!,
          keyboardType: TextInputType.number,
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
        if (_editError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _editError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
    final hasFloor = _data.floor != null && _data.floor!.trim().isNotEmpty;
    final hasPhase = _data.phase != null && _data.phase!.trim().isNotEmpty;
    final hasAct = _data.activity != null && _data.activity!.trim().isNotEmpty;
    return hasProj && hasFloor && hasPhase && hasAct;
  }
  @override
  Widget build(BuildContext context) {
    Provider.of<ProjectProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      body: SafeArea(
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
                    child: _buildBottomInputArea(),
                  ),
                ],
              ),
            ),
          ],
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
        final label = _entryType == 'material'
            ? 'Material'
            : _entryType == 'labour'
            ? 'Labour'
            : 'Equipment';
        subtitle = 'AI Voice Entry • $label';
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
      case VoiceStatus.summary:
      case VoiceStatus.saving:
        title = 'AI Assistant';
        subtitle = 'Smart conversational flow';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEBF8))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(isListening),
        ],
      ),
    );
  }
  Widget _buildStatusBadge(bool isListening) {
    final statusText = isListening ? 'Listening' : 'Ready';
    final color = isListening ? const Color(0xFFEF4444) : AppColors.textLight;
    final bgColor = isListening
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF1F5F9);
    final borderColor = isListening
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMainBody() {
    Widget content;
    final curData = _currentData;
    switch (_response.status) {
      case VoiceStatus.processing:
      case VoiceStatus.thinking:
        content = _buildProcessingCard();
        break;
      case VoiceStatus.completed:
        content = Column(
          children: [
            _buildSuccessCard(),
            if (_saveError != null) _buildErrorCard(),
          ],
        );
        break;
      case VoiceStatus.summary:
      case VoiceStatus.saving:
        content = _buildSummaryCard();
        break;
      default:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_saveError != null) _buildErrorCard(),
            _buildVoiceListeningCard(),
            _buildAiUnderstandingPanel(curData),
            _buildMissingInformationPanel(curData),
            _buildAiQuestionCard(),
            _buildExampleHintCard(),
          ],
        );
        break;
    }
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      child: content,
    );
  }
  Widget _buildVoiceListeningCard() {
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    if (!isListening) return const SizedBox.shrink();
    final hasContent = _partialAnswer.isNotEmpty || _rawTranscript.isNotEmpty;
    final displayText = hasContent
        ? (_partialAnswer.isNotEmpty ? _partialAnswer : _rawTranscript)
        : 'Listening for voice input...';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD8F5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE TRANSCRIPT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildLiveWaveform(),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 13.5,
                color: hasContent
                    ? AppColors.textDark
                    : AppColors.textLight.withValues(alpha: 0.7),
                fontStyle: _partialAnswer.isNotEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLiveWaveform() {
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    if (!isListening) return const SizedBox.shrink();
    final level = _voiceCtrl.soundLevel;
    final vol = ((level + 2.0) / 12.0).clamp(0.1, 1.0);
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, _) {
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (i) {
              final phase = _waveCtrl.value * 2 * math.pi;
              final offset = i * (math.pi / 10);
              final baseHeight = 4.0 + (math.sin(phase + offset).abs() * 14.0);
              final randNoise = math.sin(phase * 4.0 + i).abs() * 4.0;
              final finalHeight = ((baseHeight + randNoise) * vol).clamp(
                4.0,
                32.0,
              );
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 3.0,
                height: finalHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF173EEA), Color(0xFFB137FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }
  Widget _buildAiUnderstandingPanel(_ExtractedData currentData) {
    final voiceFields = _getVoiceFields(_entryType, currentData);
    final total = voiceFields.length;
    int completed = 0;
    voiceFields.forEach((key, val) {
      if (_isVoiceFieldPresent(key, val)) completed++;
    });
    final progress = total > 0 ? completed / total : 0.0;
    final isComplete = completed >= total;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEBF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                'AI Understanding Entry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$completed / $total',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isComplete
                        ? const Color(0xFF16A34A)
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFF0EDFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? const Color(0xFF22C55E) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: voiceFields.entries.map((e) {
              final isPresent = _isVoiceFieldPresent(e.key, e.value);
              final displayVal = e.value is num
                  ? (e.value as num).toStringAsFixed(e.value % 1 == 0 ? 0 : 2)
                  : e.value?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPresent
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPresent
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPresent
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      color: isPresent
                          ? const Color(0xFF16A34A)
                          : AppColors.textLight,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPresent ? '${e.key}: $displayVal' : e.key,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPresent
                            ? const Color(0xFF16A34A)
                            : AppColors.textLight,
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
  Widget _buildMissingInformationPanel(_ExtractedData currentData) {
    final voiceFields = _getVoiceFields(_entryType, currentData);
    final missing = voiceFields.entries
        .where((e) => !_isVoiceFieldPresent(e.key, e.value))
        .map((e) => e.key)
        .toList();
    if (missing.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEBF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Still Needed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  '${missing.length} field${missing.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: missing.map((field) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD97706),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      field,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
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
  Widget _buildExampleHintCard() {
    String example = "";
    if (_entryType == 'material') {
      example = '"20 bags of UltraTech cement at 420 rupees per bag"';
    } else if (_entryType == 'labour') {
      example = '"8 masons worked 9 hours at 850 rupees"';
    } else {
      example = '"JCB excavator worked 6 hours at 1200 rupees per hour"';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBE8FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Example Phrase:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  example,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173EEA), Color(0xFF7B3FE4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173EEA).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text(
                  'BuildTrack AI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (confirmed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    confirmed.length == 1 ? 'Great. I found:' : 'I have:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ...confirmed.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${f.label}: ${f.value}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.15),
              height: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              suggestions.isEmpty ? 16 : 0,
            ),
            child: Text(
              question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick answers:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionsChips(suggestions),
                ],
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildSuggestionsChips(List<String> options) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options
          .map(
            (opt) => GestureDetector(
              onTap: () => _handleTypedAnswer(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  opt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEEEBF8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0EDFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'BuildTrack AI',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _entryType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analyzing Entry...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEEEBF8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Extracting details...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(stages.length, (i) {
                final label = stages[i];
                final isCompleted = i < _processingStage;
                final isCurrent = i == _processingStage;
                Widget indicator;
                Color textColor;
                FontWeight fontWeight;
                if (isCompleted) {
                  if (states[i]) {
                    indicator = const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF22C55E),
                      size: 18,
                    );
                    textColor = AppColors.textDark;
                    fontWeight = FontWeight.w600;
                  } else {
                    indicator = const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                      size: 18,
                    );
                    textColor = AppColors.textLight;
                    fontWeight = FontWeight.w500;
                  }
                } else if (isCurrent) {
                  indicator = const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  );
                  textColor = AppColors.primary;
                  fontWeight = FontWeight.bold;
                } else {
                  indicator = Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textLight.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  );
                  textColor = AppColors.textLight;
                  fontWeight = FontWeight.w500;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    children: [
                      SizedBox(width: 20, child: Center(child: indicator)),
                      const SizedBox(width: 12),
                      Text(
                        isCompleted
                            ? (states[i]
                                  ? label
                                  : 'Finding ${stages[i].split(" ").last}...')
                            : (isCurrent ? '$label...' : label),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: textColor,
                          fontWeight: fontWeight,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEBE8FF)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: You can keep the app open. We\'ll notify you when ready.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildSummaryCard() {
    final isSaving = _response.status == VoiceStatus.saving;
    final amount = _isEditing
        ? _getLiveEditAmount()
        : _data.getComputedAmount(_entryType);
    final details = <Map<String, String>>[
      {
        'label': 'Project',
        'value': _data.projectName ?? _data.projectId ?? '—',
      },
      {'label': 'Floor', 'value': _data.floor ?? '—'},
      if (_entryType == 'material')
        {'label': 'Phase', 'value': _data.phase ?? '—'},
      {'label': 'Activity', 'value': _data.activity ?? '—'},
      if (_entryType == 'material') ...[
        {'label': 'Material', 'value': _data.itemName ?? '—'},
        {
          'label': 'Quantity',
          'value': _data.hasQuantity
              ? '${_data.quantity} ${_data.unit ?? ''}'
              : '—',
        },
      ] else if (_entryType == 'labour') ...[
        {'label': 'Labour Type', 'value': _data.workType ?? '—'},
        {
          'label': 'Worker Count',
          'value': _data.hasWorkerCount ? '${_data.workerCount}' : '—',
        },
        {
          'label': 'Hours',
          'value': _data.hasHours
              ? '${_data.hours} ${_data.unit ?? 'Hours'}'
              : '—',
        },
      ] else ...[
        {'label': 'Equipment', 'value': _data.itemName ?? '—'},
        {
          'label': 'Hours',
          'value': _data.hasQuantity
              ? '${_data.quantity} ${_data.unit ?? 'Hours'}'
              : '—',
        },
      ],
      {
        'label': 'Rate',
        'value': _data.hasRate ? '₹ ${_data.rate!.toStringAsFixed(0)}' : '—',
      },
      if (_entryType == 'equipment' && _data.hasFuelCost)
        {
          'label': 'Fuel Cost',
          'value': '₹ ${_data.fuelCost!.toStringAsFixed(0)}',
        },
      {
        'label': 'Amount',
        'value': amount > 0 ? '₹ ${amount.toStringAsFixed(0)}' : '—',
        'highlight': 'true',
      },
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD8F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF173EEA), Color(0xFF7B3FE4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ENTRY SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    '\u20b9 ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _data.itemName ??
                        (_entryType == 'labour'
                            ? 'Labour Log'
                            : _entryType == 'equipment'
                            ? 'Equipment Entry'
                            : 'Material Entry'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEBF8)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _isEditing
                ? _buildEditFormFields()
                : Column(
                    children: List.generate(details.length, (idx) {
                      final item = details[idx];
                      final isHighlight = item['highlight'] == 'true';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['label']!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textLight,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['value']!,
                              style: TextStyle(
                                fontSize: isHighlight ? 18 : 14.5,
                                fontWeight: FontWeight.w700,
                                color: isHighlight
                                    ? AppColors.primary
                                    : AppColors.textDark,
                              ),
                            ),
                            if (idx < details.length - 1) ...[
                              const SizedBox(height: 10),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF7F5FC),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEBE8FF)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: You can keep the app open. We\'ll notify you when ready.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _isEditing
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cancelEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(
                              color: Color(0xFFFCA5A5),
                              width: 1.5,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveEditChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : _enterEditMode,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                            side: const BorderSide(
                              color: Color(0xFFDDD8F5),
                              width: 1.5,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Edit Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveEntry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Confirm & Save',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFFEEEBF8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isInitialVoice) ...[
                if (isListening) ...[
                  _buildSmallMicListening(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildCancelRecordingButton()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRedStopAnalyzeButton()),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildRecordingStatusLeft(isListening),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildLargeMicButtonRedesigned(isListening),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildStopAnalyzeButtonRight(isListening),
                      ),
                    ],
                  ),
                ],
              ] else if (isAskingStep) ...[
                if (isListening) ...[
                  _buildSmallMicListening(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _stopAnswerListening,
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text(
                      'Done Answering',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  if (_showKeyboardInput) ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showKeyboardInput = false),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6FC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDDD8F5),
                              ),
                            ),
                            child: TextField(
                              controller: _textCtrl,
                              focusNode: _focusNode,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: _hintForCurrentStep,
                                hintStyle: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: _handleTypedAnswer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _handleTypedAnswer(_textCtrl.text),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF173EEA), Color(0xFFB137FF)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _showKeyboardInput = true);
                            _focusNode.requestFocus();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6FC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDDD8F5),
                              ),
                            ),
                            child: const Icon(
                              Icons.keyboard_outlined,
                              color: AppColors.textDark,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(child: _buildMicWithWaves()),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildRecordingStatusLeft(bool isListening) {
    if (!_isProjectContextSelected) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Recording Status',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Context Locked',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
        ],
      );
    }
    if (!isListening) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Recording Status',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Color(0xFF16A34A),
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'Ready To Record',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (context, _) {
        final timer = _voiceCtrl.elapsedDisplay;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Recording Status',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Listening ($timer)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  Widget _buildLargeMicButtonRedesigned(bool isListening) {
    final isEnabled = _isProjectContextSelected;
    return Center(
      child: GestureDetector(
        onTap: isEnabled
            ? (isListening ? _stopInitialRecording : _startInitialRecording)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !isEnabled
                ? const Color(0xFFF1F5F9)
                : (isListening ? const Color(0xFFEF4444) : AppColors.primary),
            border: Border.all(
              color: !isEnabled
                  ? const Color(0xFFCBD5E1)
                  : (isListening
                        ? const Color(0xFFFCA5A5)
                        : AppColors.primary.withValues(alpha: 0.2)),
              width: 2,
            ),
          ),
          child: Icon(
            isListening ? Icons.stop_rounded : Icons.mic_rounded,
            color: !isEnabled ? const Color(0xFF94A3B8) : Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
  Widget _buildStopAnalyzeButtonRight(bool isListening) {
    final isEnabled = isListening;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 40,
        child: TextButton(
          onPressed: isEnabled ? _stopAndAnalyze : null,
          style: TextButton.styleFrom(
            backgroundColor: isEnabled
                ? AppColors.primary
                : const Color(0xFFF1F5F9),
            foregroundColor: isEnabled ? Colors.white : const Color(0xFF94A3B8),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isEnabled ? AppColors.primary : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
          ),
          child: const Text(
            'Stop & Analyze',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
  Widget _buildRedStopAnalyzeButton() {
    return OutlinedButton(
      onPressed: _stopAndAnalyze,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Stop & Analyze',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
  Widget _buildCancelRecordingButton() {
    return OutlinedButton(
      onPressed: _cancelRecording,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6B7280),
        side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
  Widget _buildMicWithWaves() {
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isListening)
          _buildWaveSide(isLeft: true)
        else
          const SizedBox(width: 50),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: isListening ? _stopAnswerListening : _startAnswerListening,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF173EEA), Color(0xFFB137FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB137FF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.stop : Icons.mic_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 14),
        if (isListening)
          _buildWaveSide(isLeft: false)
        else
          const SizedBox(width: 50),
      ],
    );
  }
  Widget _buildWaveSide({required bool isLeft}) {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final idx = isLeft ? i : 3 - i;
            final phase = _waveCtrl.value * 2 * math.pi;
            final h = 6.0 + math.sin(phase + idx * math.pi / 4).abs() * 16.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
  Widget _buildSmallMicListening() {
    return AnimatedBuilder(
      animation: _voiceCtrl,
      builder: (_, _) {
        final timer = _voiceCtrl.elapsedDisplay;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎤', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              timer,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Listening',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildSuccessCard() {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)}'
        ' ${now.year}, '
        '${(now.hour % 12 == 0 ? 12 : now.hour % 12)}'
        ':${now.minute.toString().padLeft(2, '0')}'
        ' ${now.hour >= 12 ? 'PM' : 'AM'}';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCFCE7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Entry Saved Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your $_entryType entry has been saved and added to today\'s log.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    _successDetailRow(
                      'Entry ID',
                      '#${_savedEntryId?.substring(math.max(0, (_savedEntryId?.length ?? 4) - 8)) ?? 'NEW'}',
                    ),
                    const Divider(height: 12, color: Color(0xFFDCFCE7)),
                    _successDetailRow('Date & Time', dateStr),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/add-entry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Add Another Entry',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, '/logs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'View All Entries',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saveError ?? '',
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
  Widget _successDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
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
