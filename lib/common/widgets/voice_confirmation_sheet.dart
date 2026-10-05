import 'dart:math' as math;
import 'package:buildtrack_mobile/common/controllers/voice_recording_controller.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/models/project_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
Future<void> showVoiceConfirmationSheet(
  BuildContext context, {
  String? detectedType,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isDismissible: true,
    enableDrag: true,
    builder: (_) => VoiceConfirmationSheet(initialType: detectedType),
  );
}
class _EntryData {
  String? type;
  String? projectId;
  String? projectName;
  String? floor;
  String? phase;
  String? activity;
  String? itemName;
  String? quantity;
  String? unit;
  String? rate;
  String? brand;
  String? supplier;
  String? category;
  String? gst;
  String? paymentMode;
  String? notes;
  String? operator0;
  String? fuelCost;
  double get computedAmount {
    final q = double.tryParse(quantity ?? '') ?? 0;
    final r = double.tryParse(rate ?? '') ?? 0;
    return q * r;
  }
  String get typeLabel {
    switch (type) {
      case 'material':
        return 'Material Entry';
      case 'labour':
        return 'Labour Entry';
      case 'equipment':
        return 'Equipment Entry';
      default:
        return 'Entry';
    }
  }
}
enum _StepId {
  entryType,
  project,
  floor,
  phase,
  activity,
  itemName,
  quantity,
  unit,
  rate,
  optionals,
  review,
}
class VoiceConfirmationSheet extends StatefulWidget {
  final String? initialType;
  const VoiceConfirmationSheet({super.key, this.initialType});
  @override
  State<VoiceConfirmationSheet> createState() => _VoiceConfirmationSheetState();
}
class _VoiceConfirmationSheetState extends State<VoiceConfirmationSheet>
    with TickerProviderStateMixin {
  static _blue = AppColors.primaryBlue;
  static const _bgColor = Color(0xFFF4F6FC);
  static const _cardBg = Colors.white;
  static const _textDark = Color(0xFF0F1724);
  static const _textGray = Color(0xFF5A6B82);
  static const _successGreen = Color(0xFF10B981);
  final _entry = _EntryData();
  _StepId _currentStep = _StepId.entryType;
  final _answerCtrl = TextEditingController();
  bool _isSaving = false;
  bool _saveSuccess = false;
  String? _saveError;
  final _voiceCtrl = VoiceRecordingController();
  String _sttError = '';
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  final _textFocusNode = FocusNode();
  static const _units = [
    'Bags',
    'Kg',
    'Tons',
    'CFT',
    'Sqft',
    'Rft',
    'Nos',
    'Ltrs',
    'Cum',
    'Days',
    'Hours',
    'Per Day',
    'Trips',
  ];
  static const _paymentModes = ['Cash', 'UPI', 'NEFT', 'Cheque', 'Credit'];
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _voiceCtrl.addListener(_onVoiceStateChanged);
    if (widget.initialType != null) {
      _entry.type = widget.initialType;
      _currentStep = _StepId.project;
    }
  }
  @override
  void dispose() {
    _voiceCtrl.removeListener(_onVoiceStateChanged);
    _voiceCtrl.dispose();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _fadeCtrl.dispose();
    _answerCtrl.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }
  List<_StepId> get _allSteps {
    return [
      _StepId.entryType,
      _StepId.project,
      _StepId.floor,
      _StepId.phase,
      _StepId.activity,
      _StepId.itemName,
      _StepId.quantity,
      _StepId.unit,
      _StepId.rate,
      _StepId.optionals,
      _StepId.review,
    ];
  }
  int get _stepIndex => _allSteps.indexOf(_currentStep);
  int get _totalSteps => _allSteps.length;
  String get _aiGreeting {
    switch (_currentStep) {
      case _StepId.entryType:
        return 'Hi! I\'m BuildTrack AI.\nWhat would you like to add today?';
      case _StepId.project:
        return 'Great! Which project are you working on?';
      case _StepId.floor:
        return 'Perfect! Which floor?';
      case _StepId.phase:
        return 'Nice! Which phase?';
      case _StepId.activity:
        return 'Excellent! Which activity?';
      case _StepId.itemName:
        final label = _entry.type == 'material'
            ? 'material'
            : _entry.type == 'labour'
            ? 'labour type'
            : 'equipment name';
        return 'What is the $label?';
      case _StepId.quantity:
        return 'Got it! What is the quantity?';
      case _StepId.unit:
        return 'What unit are you using?';
      case _StepId.rate:
        return 'What is the rate per unit?';
      case _StepId.optionals:
        return 'Almost done! Would you like to add any optional details?';
      case _StepId.review:
        return 'Great! Here\'s what I understood.';
    }
  }
  String get _stepLabel {
    switch (_currentStep) {
      case _StepId.entryType:
        return 'Entry Type';
      case _StepId.project:
        return 'Project';
      case _StepId.floor:
        return 'Floor';
      case _StepId.phase:
        return 'Phase';
      case _StepId.activity:
        return 'Activity';
      case _StepId.itemName:
        return _entry.type == 'material'
            ? 'Material Name'
            : _entry.type == 'labour'
            ? 'Labour Name / Type'
            : 'Equipment Name';
      case _StepId.quantity:
        return 'Quantity';
      case _StepId.unit:
        return 'Unit';
      case _StepId.rate:
        return 'Rate';
      case _StepId.optionals:
        return 'Optional Details';
      case _StepId.review:
        return 'Review';
    }
  }
  void _animateTransition(VoidCallback action) {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(action);
      _fadeCtrl.forward();
    });
  }
  void _goToNext() {
    _animateTransition(() {
      switch (_currentStep) {
        case _StepId.entryType:
          _currentStep = _StepId.project;
          break;
        case _StepId.project:
          _currentStep = _StepId.floor;
          break;
        case _StepId.floor:
          _currentStep = _StepId.phase;
          break;
        case _StepId.phase:
          _currentStep = _StepId.activity;
          break;
        case _StepId.activity:
          _currentStep = _StepId.itemName;
          break;
        case _StepId.itemName:
          _currentStep = _StepId.quantity;
          break;
        case _StepId.quantity:
          _currentStep = _StepId.unit;
          break;
        case _StepId.unit:
          _currentStep = _StepId.rate;
          break;
        case _StepId.rate:
          _currentStep = _StepId.optionals;
          break;
        case _StepId.optionals:
          _currentStep = _StepId.review;
          break;
        case _StepId.review:
          break;
      }
    });
  }
  void _goBack() {
    _animateTransition(() {
      final idx = _stepIndex;
      if (idx > 0) {
        _currentStep = _allSteps[idx - 1];
      }
    });
  }
  void _onVoiceStateChanged() {
    if (!mounted) return;
    debugPrint('STT state: ${_voiceCtrl.engineState}');
    switch (_voiceCtrl.engineState) {
      case VoiceEngineState.idle:
        break;
      case VoiceEngineState.listening:
        debugPrint('Listening...');
        setState(() => _sttError = '');
        break;
      case VoiceEngineState.processing:
        debugPrint('Processing...');
        setState(() {});
        break;
      case VoiceEngineState.parsed:
        debugPrint('Recognized: "${_voiceCtrl.finalTranscript}"');
        _processRecognizedText(_voiceCtrl.finalTranscript);
        break;
      case VoiceEngineState.error:
        debugPrint('STT Error: ${_voiceCtrl.errorMessage}');
        setState(() => _sttError = _voiceCtrl.errorMessage);
        break;
    }
  }
  Future<void> _handleTapToAnswer() async {
    if (_voiceCtrl.engineState == VoiceEngineState.listening) {
      debugPrint('Listening stopped');
      await _voiceCtrl.stopListening();
      return;
    }
    debugPrint('STT Initialized');
    _sttError = '';
    setState(() {});
    await _voiceCtrl.startListening();
    debugPrint('Listening started');
  }
  void _processRecognizedText(String text) {
    if (text.isEmpty) return;
    debugPrint('Process: "$text" for step $_currentStep');
    setState(() {
      switch (_currentStep) {
        case _StepId.entryType:
          final lower = text.toLowerCase();
          if (lower.contains('material') ||
              lower.contains('cement') ||
              lower.contains('steel') ||
              lower.contains('sand') ||
              lower.contains('brick')) {
            _entry.type = 'material';
          } else if (lower.contains('labour') ||
              lower.contains('mason') ||
              lower.contains('helper') ||
              lower.contains('carpenter')) {
            _entry.type = 'labour';
          } else if (lower.contains('equipment') ||
              lower.contains('jcb') ||
              lower.contains('tractor') ||
              lower.contains('mixer') ||
              lower.contains('machine')) {
            _entry.type = 'equipment';
          }
          break;
        case _StepId.project:
          _entry.projectName = text;
          _entry.floor = null;
          _entry.phase = null;
          _entry.activity = null;
          try {
            final provider = Provider.of<ProjectProvider>(
              context,
              listen: false,
            );
            final match = provider.projects
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(text.toLowerCase()) ||
                      text.toLowerCase().contains(p.name.toLowerCase()),
                )
                .firstOrNull;
            if (match != null) {
              _entry.projectId = match.id;
              _entry.projectName = match.name;
            }
          } catch (_) {}
          break;
        case _StepId.floor:
          _entry.floor = text;
          break;
        case _StepId.phase:
          _entry.phase = text;
          _entry.activity = null;
          break;
        case _StepId.activity:
          _entry.activity = text;
          break;
        case _StepId.itemName:
          _entry.itemName = text;
          break;
        case _StepId.quantity:
          {
            final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
            _entry.quantity = cleaned.isNotEmpty ? cleaned : text;
            break;
          }
        case _StepId.unit:
          _entry.unit = text;
          break;
        case _StepId.rate:
          {
            final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
            _entry.rate = cleaned.isNotEmpty ? cleaned : text;
            break;
          }
        default:
          break;
      }
    });
    debugPrint('Conversation updated.');
    if (_currentStep == _StepId.entryType && _entry.type != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _goToNext();
      });
    } else if (_currentStep != _StepId.entryType &&
        _currentStep != _StepId.optionals &&
        _currentStep != _StepId.review) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _goToNext();
      });
    }
  }
  Widget _buildTapToAnswerButton() {
    final isListening = _voiceCtrl.engineState == VoiceEngineState.listening;
    final isProcessing = _voiceCtrl.engineState == VoiceEngineState.processing;
    return Column(
      children: [
        if (_sttError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sttError,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        Center(
          child: GestureDetector(
            onTap: isProcessing || isListening
                ? _handleTapToAnswer
                : _handleTapToAnswer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: isListening ? null : AppGradients.primaryButton,
                color: isListening ? const Color(0xFFEEF0F8) : null,
                borderRadius: BorderRadius.circular(50),
                border: isListening
                    ? Border.all(color: _blue.withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isListening ? Icons.mic : Icons.mic_none_rounded,
                    color: isListening ? _blue : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isListening
                        ? (_voiceCtrl.partialTranscript.isNotEmpty
                              ? _voiceCtrl.partialTranscript
                              : 'Listening...')
                        : 'Tap to Answer',
                    style: TextStyle(
                      color: isListening ? _textGray : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final rawType = _entry.type == 'labour'
          ? 'Wages'
          : _entry.type == 'equipment'
          ? 'Expense'
          : 'Materials';
      final qty = double.tryParse(_entry.quantity ?? '') ?? 0;
      final rate = double.tryParse(_entry.rate ?? '') ?? 0;
      final amount = qty * rate;
      final gstPct = double.tryParse(_entry.gst ?? '') ?? 0;
      final gstAmount = amount * gstPct / 100;
      final totalAmount = amount + gstAmount;
      final payload = <String, dynamic>{
        'title': _entry.itemName ?? 'Entry',
        'type': rawType,
        'project': _entry.projectId ?? '',
        'floor': _entry.floor ?? '',
        'phase': _entry.phase ?? '',
        'activity': _entry.activity ?? '',
        'category': _entry.category ?? _entry.itemName ?? '',
        'unit': _mapUnitToBackend(_entry.unit),
        'quantity': qty,
        'rate': rate,
        'amount': totalAmount,
        'paymentStatus': 'Pending',
        'paymentMode': _entry.paymentMode ?? 'Cash',
        'paidAmount': 0,
        'date': DateTime.now().toIso8601String(),
        if ((_entry.brand ?? '').isNotEmpty) 'brand': _entry.brand,
        if ((_entry.supplier ?? '').isNotEmpty) 'supplier': _entry.supplier,
        if (gstPct > 0) 'gstPercent': gstPct,
        if (gstPct > 0) 'gstAmount': gstAmount,
        if ((_entry.notes ?? '').isNotEmpty) 'notes': _entry.notes,
        if (_entry.type == 'equipment' && (_entry.operator0 ?? '').isNotEmpty)
          'operator': _entry.operator0,
        if (_entry.type == 'equipment' && (_entry.fuelCost ?? '').isNotEmpty)
          'fuelCost': double.tryParse(_entry.fuelCost ?? '') ?? 0,
        'createdBy': UserSession.userId,
      };
      final result = await ApiService.addTransaction(payload);
      if (result != null) {
        if (mounted) {
          final provider = Provider.of<ProjectProvider>(context, listen: false);
          await provider.load();
        }
        setState(() {
          _isSaving = false;
          _saveSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _isSaving = false;
          _saveError = 'Failed to save. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveError = 'Error: ${e.toString()}';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: screenHeight * 0.92,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          if (_currentStep != _StepId.review &&
              _currentStep != _StepId.entryType)
            _buildProgressBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildStepContent(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE0F0),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: _bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildMicOrb(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BuildTrack AI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _aiGreeting,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 18, color: _textGray),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMicOrb() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) {
        final scale = 1.0 + _pulseCtrl.value * 0.12;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52 * scale,
              height: 52 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _blue.withValues(alpha: 0.06 * (1 - _pulseCtrl.value)),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.primaryButton,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          ],
        );
      },
    );
  }
  Widget _buildProgressBar() {
    final progress = _totalSteps > 1
        ? (_stepIndex / (_totalSteps - 1)).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_stepIndex + 1} of $_totalSteps',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _textGray,
                ),
              ),
              Text(
                _stepLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE4E7F8),
              valueColor: const AlwaysStoppedAnimation<Color>(_blue),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStep != _StepId.entryType) ...[
            _buildWaveformRow(),
            const SizedBox(height: 12),
            _buildAnsweredSoFar(),
            const SizedBox(height: 16),
          ],
          _buildCurrentStepInput(),
          if (_currentStep != _StepId.review &&
              _currentStep != _StepId.optionals) ...[
            const SizedBox(height: 20),
            _buildTapToAnswerButton(),
          ],
        ],
      ),
    );
  }
  Widget _buildWaveformRow() {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(11, (i) {
            final phase = _waveCtrl.value + (i / 11);
            final h =
                4 + 16.0 * math.pow(math.sin(phase * math.pi * 2).abs(), 0.7);
            return Container(
              width: 3.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: AppGradients.progressBar,
              ),
            );
          }),
        );
      },
    );
  }
  Widget _buildAnsweredSoFar() {
    final chips = <Widget>[];
    void addChip(IconData icon, String? val) {
      if (val == null || val.isEmpty) return;
      chips.add(_AnswerChip(icon: icon, value: val));
    }
    addChip(
      Icons.category_outlined,
      _entry.typeLabel != 'Entry' ? _entry.typeLabel : null,
    );
    addChip(Icons.business_outlined, _entry.projectName);
    addChip(Icons.layers_outlined, _entry.floor);
    addChip(Icons.construction_outlined, _entry.phase);
    addChip(Icons.task_outlined, _entry.activity);
    addChip(Icons.inventory_2_outlined, _entry.itemName);
    if (_entry.quantity != null && _entry.rate != null) {
      addChip(
        Icons.calculate_outlined,
        '₹${_formatAmount(_entry.computedAmount)}',
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
  Widget _buildEntryTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSectionLabel('SELECT ENTRY TYPE'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTypeCard(
              'material',
              Icons.inventory_2_outlined,
              'Material',
              'Cement, Steel, Sand…',
            ),
            const SizedBox(width: 10),
            _buildTypeCard(
              'labour',
              Icons.people_outline,
              'Labour',
              'Mason, Carpenter…',
            ),
            const SizedBox(width: 10),
            _buildTypeCard(
              'equipment',
              Icons.construction_outlined,
              'Equipment',
              'JCB, Mixer…',
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildTypeCard(String type, IconData icon, String label, String sub) {
    final selected = _entry.type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _entry.type = type);
          Future.delayed(const Duration(milliseconds: 200), _goToNext);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.primaryButton : null,
            color: selected ? null : _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(color: const Color(0xFFDDE4F8), width: 1.5),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: _blue.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : _blue, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : _textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.75)
                      : _textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildProjectStep() {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final projects = provider.projects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SELECT PROJECT'),
        const SizedBox(height: 12),
        if (projects.isEmpty)
          _buildEmptyHint('No projects found. Add a project first.')
        else
          ...projects.map(
            (p) => _buildSelectableCard(
              icon: Icons.business_outlined,
              title: p.name,
              subtitle: p.city.isNotEmpty ? p.city : p.sector,
              isSelected: _entry.projectId == p.id,
              onTap: () {
                setState(() {
                  _entry.projectId = p.id;
                  _entry.projectName = p.name;
                  _entry.floor = null;
                  _entry.phase = null;
                  _entry.activity = null;
                });
                Future.delayed(const Duration(milliseconds: 200), _goToNext);
              },
            ),
          ),
      ],
    );
  }
  Widget _buildFloorStep() {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final project = provider.projects.firstWhere(
      (p) => p.id == _entry.projectId,
      orElse: () => provider.projects.isNotEmpty
          ? provider.projects.first
          : _placeholderProject(),
    );
    final floors = project.floors ?? ['Ground'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SELECT FLOOR'),
        const SizedBox(height: 12),
        ...floors.map(
          (f) => _buildSelectableCard(
            icon: Icons.layers_outlined,
            title: f,
            isSelected: _entry.floor == f,
            onTap: () {
              setState(() => _entry.floor = f);
              Future.delayed(const Duration(milliseconds: 200), _goToNext);
            },
          ),
        ),
        _buildCustomTextField(
          hint: 'Or type a custom floor…',
          onSubmit: (val) {
            if (val.trim().isNotEmpty) {
              setState(() => _entry.floor = val.trim());
              _goToNext();
            }
          },
        ),
      ],
    );
  }
  Widget _buildPhaseStep() {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final project = provider.projects.firstWhere(
      (p) => p.id == _entry.projectId,
      orElse: () => _placeholderProject(),
    );
    final phases =
        project.selectedPhases
            ?.map((p) => p.phaseName)
            .where((n) => n.isNotEmpty)
            .toList() ??
        _defaultPhases;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SELECT PHASE'),
        const SizedBox(height: 12),
        ...phases.map(
          (ph) => _buildSelectableCard(
            icon: Icons.construction_outlined,
            title: ph,
            isSelected: _entry.phase == ph,
            onTap: () {
              setState(() {
                _entry.phase = ph;
                _entry.activity = null;
              });
              Future.delayed(const Duration(milliseconds: 200), _goToNext);
            },
          ),
        ),
        _buildCustomTextField(
          hint: 'Or type a custom phase…',
          onSubmit: (val) {
            if (val.trim().isNotEmpty) {
              setState(() => _entry.phase = val.trim());
              _goToNext();
            }
          },
        ),
      ],
    );
  }
  Widget _buildActivityStep() {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final project = provider.projects.firstWhere(
      (p) => p.id == _entry.projectId,
      orElse: () => _placeholderProject(),
    );
    List<String> activities = [];
    if (project.selectedPhases != null && _entry.phase != null) {
      final phaseObj = project.selectedPhases!
          .where((p) => p.phaseName == _entry.phase)
          .toList();
      if (phaseObj.isNotEmpty) {
        activities = phaseObj.first.activities.map((a) => a.name).toList();
      }
    }
    if (activities.isEmpty) activities = _defaultActivities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SELECT ACTIVITY'),
        const SizedBox(height: 12),
        ...activities
            .take(10)
            .map(
              (act) => _buildSelectableCard(
                icon: Icons.task_outlined,
                title: act,
                isSelected: _entry.activity == act,
                onTap: () {
                  setState(() => _entry.activity = act);
                  Future.delayed(const Duration(milliseconds: 200), _goToNext);
                },
              ),
            ),
        _buildCustomTextField(
          hint: 'Or type a custom activity…',
          onSubmit: (val) {
            if (val.trim().isNotEmpty) {
              setState(() => _entry.activity = val.trim());
              _goToNext();
            }
          },
        ),
      ],
    );
  }
  Widget _buildItemNameStep() {
    final suggestions = _entry.type == 'material'
        ? _materialSuggestions
        : _entry.type == 'labour'
        ? _labourSuggestions
        : _equipmentSuggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('COMMON OPTIONS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map(
                (s) => _buildPill(
                  s,
                  selected: _entry.itemName == s,
                  onTap: () {
                    setState(() => _entry.itemName = s);
                    Future.delayed(
                      const Duration(milliseconds: 150),
                      _goToNext,
                    );
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _buildTypedTextField(
          label: _stepLabel,
          hint: 'Type here…',
          initialValue: _entry.itemName,
          onSave: (val) {
            setState(() => _entry.itemName = val);
            _goToNext();
          },
        ),
      ],
    );
  }
  Widget _buildQuantityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTypedTextField(
          label: 'Quantity',
          hint: 'e.g. 50',
          keyboardType: TextInputType.number,
          initialValue: _entry.quantity,
          onSave: (val) {
            setState(() => _entry.quantity = val);
            _goToNext();
          },
        ),
        if (_entry.rate != null && _entry.quantity != null) ...[
          const SizedBox(height: 16),
          _buildAmountPreview(),
        ],
      ],
    );
  }
  Widget _buildUnitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SELECT UNIT'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _units
              .map(
                (u) => _buildPill(
                  u,
                  selected: _entry.unit == u,
                  onTap: () {
                    setState(() => _entry.unit = u);
                    Future.delayed(
                      const Duration(milliseconds: 150),
                      _goToNext,
                    );
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        _buildCustomTextField(
          hint: 'Or type a custom unit…',
          onSubmit: (val) {
            if (val.trim().isNotEmpty) {
              setState(() => _entry.unit = val.trim());
              _goToNext();
            }
          },
        ),
      ],
    );
  }
  Widget _buildRateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTypedTextField(
          label: 'Rate per ${_entry.unit ?? 'unit'}',
          hint: 'e.g. 420',
          keyboardType: TextInputType.number,
          prefix: '₹',
          initialValue: _entry.rate,
          onSave: (val) {
            setState(() => _entry.rate = val);
            _goToNext();
          },
        ),
        if ((_entry.quantity ?? '').isNotEmpty &&
            (_entry.rate ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAmountPreview(),
        ],
      ],
    );
  }
  Widget _buildAmountPreview() {
    final q = double.tryParse(_entry.quantity ?? '') ?? 0;
    final r = double.tryParse(_entry.rate ?? '') ?? 0;
    final amount = q * r;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated Amount',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '₹${_formatAmount(amount)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildOptionalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('OPTIONAL — SKIP ANYTIME'),
        const SizedBox(height: 12),
        if (_entry.type == 'material') ...[
          _buildOptionalField(
            'Brand',
            Icons.local_offer_outlined,
            _entry.brand,
            (v) => setState(() => _entry.brand = v),
          ),
          _buildOptionalField(
            'Supplier',
            Icons.store_outlined,
            _entry.supplier,
            (v) => setState(() => _entry.supplier = v),
          ),
          _buildOptionalField(
            'Category',
            Icons.category_outlined,
            _entry.category,
            (v) => setState(() => _entry.category = v),
          ),
          _buildOptionalGst(),
        ],
        if (_entry.type == 'equipment') ...[
          _buildOptionalField(
            'Operator Name',
            Icons.person_outline,
            _entry.operator0,
            (v) => setState(() => _entry.operator0 = v),
          ),
          _buildOptionalField(
            'Fuel Cost (₹)',
            Icons.local_gas_station_outlined,
            _entry.fuelCost,
            (v) => setState(() => _entry.fuelCost = v),
            keyboardType: TextInputType.number,
          ),
        ],
        _buildPaymentModeField(),
        _buildOptionalField(
          'Notes',
          Icons.notes_outlined,
          _entry.notes,
          (v) => setState(() => _entry.notes = v),
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _buildGradientButton(
          label: 'Continue to Review',
          icon: Icons.arrow_forward_rounded,
          onTap: _goToNext,
        ),
        const SizedBox(height: 12),
        _buildSkipButton(label: 'Skip optional details', onTap: _goToNext),
      ],
    );
  }
  Widget _buildOptionalField(
    String label,
    IconData icon,
    String? value,
    void Function(String) onChanged, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7F8)),
      ),
      child: TextField(
        controller: TextEditingController(text: value),
        onChanged: onChanged,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 14,
          color: _textDark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: _blue.withValues(alpha: 0.7)),
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: _textGray,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
  Widget _buildOptionalGst() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7F8)),
      ),
      child: TextField(
        controller: TextEditingController(text: _entry.gst),
        onChanged: (v) => setState(() => _entry.gst = v),
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontSize: 14,
          color: _textDark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.percent_outlined,
            size: 20,
            color: _blue.withValues(alpha: 0.7),
          ),
          labelText: 'GST %',
          labelStyle: const TextStyle(
            fontSize: 13,
            color: _textGray,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
  Widget _buildPaymentModeField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7F8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.payment_outlined,
            size: 20,
            color: _blue.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          const Text(
            'Payment Mode',
            style: TextStyle(
              fontSize: 13,
              color: _textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _entry.paymentMode ?? 'Cash',
              style: const TextStyle(
                fontSize: 14,
                color: _textDark,
                fontWeight: FontWeight.w700,
              ),
              items: _paymentModes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _entry.paymentMode = v),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildReviewStep() {
    if (_saveSuccess) {
      return _buildSuccessState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _blue.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _entry.typeLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _reviewRow('Project', _entry.projectName),
              _reviewRow('Floor', _entry.floor),
              _reviewRow('Phase', _entry.phase),
              _reviewRow('Activity', _entry.activity),
              _reviewRow(
                _entry.type == 'material'
                    ? 'Material'
                    : _entry.type == 'labour'
                    ? 'Labour'
                    : 'Equipment',
                _entry.itemName,
              ),
              _reviewRow('Quantity', _entry.quantity),
              _reviewRow('Unit', _entry.unit),
              _reviewRow(
                'Rate',
                _entry.rate != null ? '₹${_entry.rate}' : null,
              ),
              const Divider(height: 20, color: Color(0xFFEEF0F8)),
              _reviewRowAmount(
                'Total Amount',
                '₹${_formatAmount(_entry.computedAmount)}',
              ),
              if ((_entry.gst ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                _reviewRow('GST', '${_entry.gst}%'),
                _reviewRowAmount(
                  'Amount + GST',
                  '₹${_formatAmount(_entry.computedAmount * (1 + (double.tryParse(_entry.gst ?? '') ?? 0) / 100))}',
                ),
              ],
              if ((_entry.brand ?? '').isNotEmpty)
                _reviewRow('Brand', _entry.brand),
              if ((_entry.supplier ?? '').isNotEmpty)
                _reviewRow('Supplier', _entry.supplier),
              if ((_entry.paymentMode ?? '').isNotEmpty)
                _reviewRow('Payment', _entry.paymentMode),
              if ((_entry.operator0 ?? '').isNotEmpty)
                _reviewRow('Operator', _entry.operator0),
              if ((_entry.fuelCost ?? '').isNotEmpty)
                _reviewRow('Fuel Cost', '₹${_entry.fuelCost}'),
              if ((_entry.notes ?? '').isNotEmpty)
                _reviewRow('Notes', _entry.notes),
            ],
          ),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildOutlinedButton(
          label: 'Edit',
          icon: Icons.edit_outlined,
          onTap: _goBack,
        ),
        const SizedBox(height: 12),
        _isSaving
            ? _buildLoadingButton()
            : _buildGradientButton(
                label: 'Confirm & Save',
                icon: Icons.check_circle_outline,
                onTap: _saveEntry,
              ),
      ],
    );
  }
  Widget _buildSuccessState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _successGreen.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _successGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Entry Saved!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your entry has been recorded successfully.',
            style: TextStyle(fontSize: 14, color: _textGray),
          ),
        ],
      ),
    );
  }
  Widget _reviewRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                color: _textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _reviewRowAmount(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.primaryButton.createShader(bounds),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildCurrentStepInput() {
    switch (_currentStep) {
      case _StepId.entryType:
        return _buildEntryTypeStep();
      case _StepId.project:
        return _buildProjectStep();
      case _StepId.floor:
        return _buildFloorStep();
      case _StepId.phase:
        return _buildPhaseStep();
      case _StepId.activity:
        return _buildActivityStep();
      case _StepId.itemName:
        return _buildItemNameStep();
      case _StepId.quantity:
        return _buildQuantityStep();
      case _StepId.unit:
        return _buildUnitStep();
      case _StepId.rate:
        return _buildRateStep();
      case _StepId.optionals:
        return _buildOptionalsStep();
      case _StepId.review:
        return _buildReviewStep();
    }
  }
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _textGray,
        letterSpacing: 1.1,
      ),
    );
  }
  Widget _buildSelectableCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _blue.withValues(alpha: 0.06) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _blue : const Color(0xFFDDE4F8),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? _blue.withValues(alpha: 0.12)
                    : const Color(0xFFF0F2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? _blue : _textGray,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _blue : _textDark,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: _blue, size: 20),
          ],
        ),
      ),
    );
  }
  Widget _buildPill(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.primaryButton : null,
          color: selected ? null : _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFDDE4F8), width: 1.5),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: _blue.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _textDark,
          ),
        ),
      ),
    );
  }
  Widget _buildCustomTextField({
    required String hint,
    required void Function(String) onSubmit,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE4F8)),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14,
            color: _textDark,
            fontWeight: FontWeight.w600,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmit,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13.5, color: _textGray),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send_rounded, color: _blue, size: 20),
              onPressed: () => onSubmit(ctrl.text),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildTypedTextField({
    required String label,
    required String hint,
    required void Function(String) onSave,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    int maxLines = 1,
  }) {
    final ctrl = TextEditingController(text: initialValue ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label.toUpperCase()),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE4F8)),
            boxShadow: [
              BoxShadow(color: _blue.withValues(alpha: 0.04), blurRadius: 10),
            ],
          ),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 16,
              color: _textDark,
              fontWeight: FontWeight.w700,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: onSave,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: _textGray),
              prefixText: prefix,
              prefixStyle: const TextStyle(
                fontSize: 16,
                color: _textDark,
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildGradientButton(
          label: 'Next',
          icon: Icons.arrow_forward_rounded,
          onTap: () => onSave(ctrl.text),
        ),
      ],
    );
  }
  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
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
      ),
    );
  }
  Widget _buildOutlinedButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: _blue, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _blue, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSkipButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _textGray,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
  Widget _buildLoadingButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(50),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Saving…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyHint(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: _textGray, fontSize: 14),
      ),
    );
  }
  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount >= 1000) {
      final parts = amount.toStringAsFixed(0);
      final buf = StringBuffer();
      int start = parts.length % 3;
      if (start > 0) buf.write(parts.substring(0, start));
      for (int i = start; i < parts.length; i += 3) {
        if (buf.isNotEmpty) buf.write(',');
        buf.write(parts.substring(i, i + 3));
      }
      return buf.toString();
    }
    return amount.toStringAsFixed(0);
  }
  ProjectModel _placeholderProject() {
    return ProjectModel(
      id: '',
      name: '',
      city: '',
      sector: '',
      stage: ProjectStage.preConstruction,
      progress: 0,
      totalBudget: 0,
      spentAmount: 0,
      startDate: DateTime.now(),
      location: '',
    );
  }
  static const _defaultPhases = [
    'Foundation & Plinth Work',
    'Floor Construction',
    'Finishing Work',
    'External Works',
    'Site Preparation',
    'Pre-Construction',
  ];
  static const _defaultActivities = [
    'Column Casting',
    'Slab Casting',
    'Wall Construction',
    'Plastering',
    'Painting',
    'Tile Work',
    'Electrical Work',
    'Plumbing',
    'Waterproofing',
    'Landscaping',
  ];
  static const _materialSuggestions = [
    'Cement',
    'Steel',
    'Sand',
    'Aggregate',
    'Bricks',
    'Blocks',
    'Tiles',
    'Paint',
    'Putty',
    'Pipes',
    'Electrical Materials',
    'Plumbing Materials',
    'Doors',
    'Windows',
    'Glass',
  ];
  static const _labourSuggestions = [
    'Mason',
    'Helper',
    'Carpenter',
    'Bar Bender',
    'Electrician',
    'Plumber',
    'Painter',
    'Tile Worker',
    'Fabricator',
    'Welder',
  ];
  static const _equipmentSuggestions = [
    'JCB',
    'Tractor',
    'Concrete Mixer',
    'Vibrator',
    'Scaffolding',
    'Cutting Machine',
    'Welding Machine',
    'Water Tanker',
  ];
}
class _AnswerChip extends StatelessWidget {
  final IconData icon;
  final String value;
  const _AnswerChip({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppColors.primaryBlue.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.check, size: 11, color: AppColors.primaryBlue),
        ],
      ),
    );
  }
}

