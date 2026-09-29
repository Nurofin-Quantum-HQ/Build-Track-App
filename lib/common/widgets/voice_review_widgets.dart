import 'dart:async';
import 'dart:math';
import 'package:buildtrack_mobile/common/controllers/voice_recording_controller.dart';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:flutter/material.dart';
export 'package:buildtrack_mobile/common/controllers/voice_recording_controller.dart'
    show VoiceEngineState, VoiceRecordingController;
typedef VoiceEntryState = VoiceEngineState;
class ExtractedField {
  const ExtractedField({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmpty = false,
    this.isHighlight = false,
    this.confidence = 1.0,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isEmpty;
  final bool isHighlight;
  final double confidence;
}
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    super.key,
    required this.state,
    this.onTap,
    this.size = 52,
  });
  final VoiceEngineState state;
  final VoidCallback? onTap;
  final double size;
  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}
class _VoiceMicButtonState extends State<VoiceMicButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _spinCtrl;
  late Animation<double> _pulseAnim;
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(
      begin: 0.82,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }
  @override
  void dispose() {
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }
  LinearGradient _gradient(VoiceEngineState s) {
    if (s == VoiceEngineState.parsed) {
      return const LinearGradient(
        colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
      );
    }
    if (s == VoiceEngineState.error) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
      );
    }
    if (s == VoiceEngineState.idle) {
      return const LinearGradient(
        colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)],
      );
    }
    return AppGradients.primaryButton;
  }
  Color _shadowColor(VoiceEngineState s) {
    if (s == VoiceEngineState.parsed) return const Color(0xFF16A34A);
    if (s == VoiceEngineState.error) return const Color(0xFFDC2626);
    return AppColors.primary;
  }
  IconData _icon(VoiceEngineState s) {
    if (s == VoiceEngineState.parsed) return Icons.check_rounded;
    if (s == VoiceEngineState.error) return Icons.mic_off_rounded;
    return Icons.mic_rounded;
  }
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final btnSize = widget.size * 0.82;
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (s == VoiceEngineState.listening)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Container(
                  width: widget.size * _pulseAnim.value,
                  height: widget.size * _pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
              ),
            Container(
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _gradient(s),
                boxShadow: [
                  BoxShadow(
                    color: _shadowColor(s).withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: s == VoiceEngineState.processing
                  ? AnimatedBuilder(
                      animation: _spinCtrl,
                      builder: (_, child) => Transform.rotate(
                        angle: _spinCtrl.value * 2 * pi,
                        child: child,
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : Icon(
                      _icon(s),
                      color: Colors.white,
                      size: widget.size * 0.38,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
class VoiceStatusHeader extends StatelessWidget {
  const VoiceStatusHeader({
    super.key,
    required this.state,
    required this.entryTypeLabel,
    this.confidence = 98.4,
    this.timestamp,
    this.onMicTap,
    this.partialTranscript = '',
    this.elapsedDisplay = '00:00',
    this.onStop,
    this.onCancel,
  });
  final VoiceEngineState state;
  final String entryTypeLabel;
  final double confidence;
  final String? timestamp;
  final VoidCallback? onMicTap;
  final String partialTranscript;
  final String elapsedDisplay;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;
  static String _fmtNow() {
    final dt = DateTime.now();
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
  }
  (String label, Color text, Color bg) _resolveState() {
    switch (state) {
      case VoiceEngineState.parsed:
        return (
          'Parsed from Voice',
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
        );
      case VoiceEngineState.listening:
        return ('Listening…', AppColors.primary, Color(0xFFEEF0FF));
      case VoiceEngineState.processing:
        return (
          'Processing voice entry…',
          AppColors.primary,
          const Color(0xFFEEF0FF),
        );
      case VoiceEngineState.error:
        return (
          'Parse Failed — Tap to Retry',
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
        );
      case VoiceEngineState.idle:
        return (
          'Tap Mic to Record',
          AppColors.textLight,
          const Color(0xFFF1F5F9),
        );
    }
  }
  @override
  Widget build(BuildContext context) {
    final ts = timestamp ?? _fmtNow();
    final (statusText, textColor, bgColor) = _resolveState();
    final isActive = state == VoiceEngineState.listening;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.35)
              : const Color(0xFFEEEBF8),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isActive ? 18 : 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                VoiceMicButton(
                  state: state,
                  onTap: isActive ? null : onMicTap,
                  size: 50,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              entryTypeLabel.toUpperCase(),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    elapsedDisplay,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (!isActive)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 3,
                          runSpacing: 2,
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 11,
                              color: AppColors.textLight,
                            ),
                            Text(
                              '${confidence.toStringAsFixed(1)}% confidence',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.schedule_outlined,
                              size: 11,
                              color: AppColors.textLight,
                            ),
                            Text(
                              ts,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      if (isActive)
                        const Text(
                          'Speak naturally — pauses are allowed',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
                if (state == VoiceEngineState.parsed)
                  TextButton.icon(
                    onPressed: onMicTap,
                    icon: const Icon(Icons.refresh_rounded, size: 13),
                    label: const Text(
                      'Re-record',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          if (isActive) ...[
            const Divider(height: 1, color: Color(0xFFF0EEF8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      partialTranscript.isEmpty
                          ? 'Waiting for speech…'
                          : partialTranscript,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.55,
                        color: partialTranscript.isEmpty
                            ? AppColors.textLight
                            : AppColors.textDark,
                        fontStyle: partialTranscript.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textLight,
                        side: const BorderSide(color: Color(0xFFDDD8F5)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onStop,
                      icon: const Icon(Icons.stop_circle_outlined, size: 15),
                      label: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
class ExtractedDataSummaryCard extends StatefulWidget {
  const ExtractedDataSummaryCard({
    super.key,
    required this.fields,
    this.subtitle = 'Review the detected values below',
    this.animateReveal = false,
  });
  final List<ExtractedField> fields;
  final String subtitle;
  final bool animateReveal;
  @override
  State<ExtractedDataSummaryCard> createState() =>
      _ExtractedDataSummaryCardState();
}
class _ExtractedDataSummaryCardState extends State<ExtractedDataSummaryCard> {
  int _visibleCount = 0;
  Timer? _revealTimer;
  @override
  void initState() {
    super.initState();
    _visibleCount = widget.animateReveal ? 0 : widget.fields.length;
    if (widget.animateReveal) _startReveal();
  }
  @override
  void didUpdateWidget(covariant ExtractedDataSummaryCard old) {
    super.didUpdateWidget(old);
    if (widget.animateReveal && !old.animateReveal) {
      _visibleCount = 0;
      _startReveal();
    } else if (!widget.animateReveal && _visibleCount < widget.fields.length) {
      _visibleCount = widget.fields.length;
    }
  }
  void _startReveal() {
    _revealTimer?.cancel();
    _revealTimer = Timer.periodic(const Duration(milliseconds: 280), (t) {
      if (!mounted || _visibleCount >= widget.fields.length) {
        t.cancel();
        return;
      }
      setState(() => _visibleCount++);
    });
  }
  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final detected = widget.fields
        .where((f) => !f.isEmpty && f.value.isNotEmpty)
        .length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEBF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF173EEA), Color(0xFFB137FF)],
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Extracted Fields',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 10,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$detected/${widget.fields.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EEF8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: List.generate(widget.fields.length, (i) {
                if (i >= _visibleCount) return const SizedBox.shrink();
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: _FieldRow(
                    field: widget.fields[i],
                    isLast: i == widget.fields.length - 1,
                  ),
                );
              }),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Tap any field below to correct. AI extracted — please verify.',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field, this.isLast = false});
  final ExtractedField field;
  final bool isLast;
  Color _confidenceColor(double c) {
    if (c >= 0.85) return const Color(0xFF16A34A);
    if (c >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
  @override
  Widget build(BuildContext context) {
    final empty = field.isEmpty || field.value.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: empty
                  ? const Color(0xFFF1F5F9)
                  : field.isHighlight
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : const Color(0xFFF4F3FE),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              field.icon,
              size: 14,
              color: empty
                  ? AppColors.textLight
                  : field.isHighlight
                  ? AppColors.primary
                  : const Color(0xFF7C5CFC),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              field.label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: empty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Not detected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          field.value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: field.isHighlight
                                ? AppColors.primary
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _confidenceColor(field.confidence),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
class ExtractionProcessingCard extends StatefulWidget {
  const ExtractionProcessingCard({super.key, required this.stages});
  final List<String> stages;
  @override
  State<ExtractionProcessingCard> createState() =>
      _ExtractionProcessingCardState();
}
class _ExtractionProcessingCardState extends State<ExtractionProcessingCard> {
  int _completed = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (!mounted || _completed >= widget.stages.length) {
        t.cancel();
        return;
      }
      setState(() => _completed++);
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEBF8)),
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
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Analyzing voice entry…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(widget.stages.length, (i) {
            final done = i < _completed;
            final active = i == _completed;
            return AnimatedOpacity(
              opacity: (done || active) ? 1.0 : 0.25,
              duration: const Duration(milliseconds: 280),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: done
                          ? const Color(0xFF16A34A)
                          : AppColors.textLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.stages[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: done ? AppColors.textDark : AppColors.textLight,
                        fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
class ExpandableTranscript extends StatefulWidget {
  const ExpandableTranscript({super.key, required this.transcript});
  final String transcript;
  @override
  State<ExpandableTranscript> createState() => _ExpandableTranscriptState();
}
class _ExpandableTranscriptState extends State<ExpandableTranscript>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEBF8)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_align_left_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Voice Transcript',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    _expanded ? 'Hide' : 'View',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _expanded
                ? FadeTransition(
                    opacity: _fade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: Color(0xFFF0EEF8)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Text(
                            '"${widget.transcript}"',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                              fontStyle: FontStyle.italic,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
