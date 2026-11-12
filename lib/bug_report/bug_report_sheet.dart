import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:buildtrack_mobile/config/navigator_key.dart';
import 'package:buildtrack_mobile/design/design.dart';

import 'bug_report_service.dart';
import 'report_model.dart';
import 'shake_service.dart';

/// Body of the "Report a problem" bottom sheet.
class BugReportForm extends StatefulWidget {
  const BugReportForm({super.key, required this.base, this.offerTurnOff = true});

  /// Everything auto-filled (screen, device, steps, project, screenshot…).
  final BugReportDraft base;
  final bool offerTurnOff;

  @override
  State<BugReportForm> createState() => _BugReportFormState();
}

enum _Phase { editing, sending, sent, queued }

class _BugReportFormState extends State<BugReportForm> {
  final _what = TextEditingController();
  final _trying = TextEditingController();
  Uint8List? _shot;
  bool _shotRemoved = false;
  bool _detailsOpen = false;
  _Phase _phase = _Phase.editing;
  String? _error;
  String? _code;

  @override
  void initState() {
    super.initState();
    _shot = widget.base.screenshot;
    _what.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _what.dispose();
    _trying.dispose();
    super.dispose();
  }

  bool get _canSend => _what.text.trim().isNotEmpty && _phase == _Phase.editing;

  Future<void> _send() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    final draft = widget.base.copyWith(
      description: _what.text.trim(),
      tryingTo: _trying.text.trim(),
      screenshot: _shot,
      clearScreenshot: _shot == null,
    );
    final result = await BugReportService.instance.submit(draft);
    if (!mounted) return;
    switch (result.status) {
      case SubmitStatus.sent:
        setState(() {
          _phase = _Phase.sent;
          _code = result.code;
        });
        break;
      case SubmitStatus.queued:
        setState(() => _phase = _Phase.queued);
        break;
      case SubmitStatus.rejected:
        setState(() {
          _phase = _Phase.editing;
          _error = result.message ?? "We couldn't send that. Please try again.";
        });
        break;
    }
  }

  Future<void> _turnOffShake() async {
    await ShakeService.instance.setEnabled(false);
    final nav = Navigator.of(context);
    nav.maybePop();
    final ctx = globalNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      btToast(ctx, 'Shake to report is off. Turn it back on in Account → Shake to report a problem.');
    }
  }

  void _viewShot() {
    final bytes = _shot;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Bt.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: InteractiveViewer(maxScale: 4, child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: BtIconButton(icon: Icons.close_rounded, size: 18, semantic: 'Close', background: Colors.white, onTap: () => Navigator.of(ctx).pop()),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.sent || _phase == _Phase.queued) return _done(context);
    final sending = _phase == _Phase.sending;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (_shot != null) _screenshotCard(context) else if (_shotRemoved && widget.base.screenshot != null) _screenshotRemoved(context),
      if (_shot != null || (_shotRemoved && widget.base.screenshot != null)) const SizedBox(height: 16),
      BtField(
        label: 'What went wrong?',
        helper: _what.text.length > BugReportLimits.description - 200 ? '${_what.text.length}/${BugReportLimits.description}' : null,
        child: TextField(
          controller: _what,
          enabled: !sending,
          minLines: 3,
          maxLines: 6,
          maxLength: BugReportLimits.description,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          style: BtText.body(context),
          decoration: btInput(context, hint: 'Describe it in your own words').copyWith(counterText: ''),
        ),
      ),
      const SizedBox(height: 14),
      BtField(
        label: 'What were you trying to do?',
        optional: true,
        child: TextField(
          controller: _trying,
          enabled: !sending,
          minLines: 2,
          maxLines: 4,
          maxLength: BugReportLimits.tryingTo,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          style: BtText.body(context),
          decoration: btInput(context, hint: 'For example: save a material entry').copyWith(counterText: ''),
        ),
      ),
      const SizedBox(height: 14),
      _whatWeSend(context),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: BtText.subhead(context, color: Bt.red)),
      ],
      const SizedBox(height: 16),
      BtButton(label: 'Send', loading: sending, onPressed: _canSend ? _send : null),
      if (widget.offerTurnOff && ShakeService.instance.enabled.value) ...[
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: sending ? null : _turnOffShake,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: Bt.ink3),
            child: Text('Turn off shake to report', style: BtText.caption(context, color: Bt.ink3, weight: FontWeight.w500)),
          ),
        ),
      ],
    ]);
  }

  Widget _screenshotCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(Bt.rInput), border: Border.all(color: Bt.line)),
      child: Row(children: [
        Semantics(
          button: true,
          label: 'View screenshot full size',
          child: GestureDetector(
            onTap: _viewShot,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                height: 84,
                color: Bt.card,
                child: Image.memory(_shot!, fit: BoxFit.cover, alignment: Alignment.topCenter, gaplessPlayback: true),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Picture of this screen', style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text('Tap to view. Remove it if it shows anything private.', style: BtText.caption(context)),
          ]),
        ),
        BtIconButton(
          icon: Icons.close_rounded,
          size: 18,
          semantic: 'Remove screenshot',
          background: Bt.fill,
          onTap: () => setState(() {
            _shot = null;
            _shotRemoved = true;
          }),
        ),
      ]),
    );
  }

  Widget _screenshotRemoved(BuildContext context) {
    return Row(children: [
      Expanded(child: Text('Screenshot removed.', style: BtText.caption(context))),
      TextButton(
        onPressed: () => setState(() {
          _shot = widget.base.screenshot;
          _shotRemoved = false;
        }),
        style: TextButton.styleFrom(minimumSize: const Size(44, 36), foregroundColor: Bt.ink2),
        child: Text('Add it back', style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _whatWeSend(BuildContext context) {
    final b = widget.base;
    final steps = b.breadcrumbs.length;
    final when = DateFormat('d MMM, h:mm a').format(b.occurredAt.toLocal());
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 78, child: Text(k, style: BtText.caption(context))),
            Expanded(child: Text(v, style: BtText.caption(context, color: Bt.ink)))
          ]),
        );
    return Container(
      decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(Bt.rInput)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          expanded: _detailsOpen,
          child: InkWell(
            borderRadius: BorderRadius.circular(Bt.rInput),
            onTap: () => setState(() => _detailsOpen = !_detailsOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(child: Text("What we'll send", style: BtText.subhead(context, color: Bt.ink, weight: FontWeight.w500))),
                AnimatedRotation(turns: _detailsOpen ? .5 : 0, duration: Bt.fast, child: const Icon(Icons.expand_more_rounded, color: Bt.ink3)),
              ]),
            ),
          ),
        ),
        if (_detailsOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Along with your message, we include these so we can find the problem faster. Your name and contact details come from your account.', style: BtText.caption(context)),
              line('Screen', b.screenName),
              line('Time', when),
              line('App', b.device.appVersion.isEmpty ? 'Unknown' : '${b.device.appVersion}${b.device.buildNumber.isEmpty ? '' : ' (${b.device.buildNumber})'}'),
              line('Device', [b.device.model, b.device.osVersion].where((s) => s.isNotEmpty).join(' · ').ifEmpty('Unknown')),
              if (b.projectName != null) line('Project', b.projectName!),
              line('Recent steps', steps == 0 ? 'None yet' : '$steps recent steps (screens opened, buttons tapped, errors — never what you typed)'),
              line('Picture', _shot != null ? 'Yes, of this screen' : 'No'),
            ]),
          ),
      ]),
    );
  }

  Widget _done(BuildContext context) {
    final sent = _phase == _Phase.sent;
    final bt = context.bt;
    final text = sent
        ? (_code != null && _code!.isNotEmpty ? "Thanks — we've got it. Reference $_code." : "Thanks — we've got it.")
        : BugReportService.savedOfflineMessage;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: BtTile(icon: sent ? Icons.check_rounded : Icons.cloud_off_rounded, size: 60, bg: bt.accentSoft, fg: bt.accentInk)),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: BtText.title(context, size: 19)),
        if (sent) ...[
          const SizedBox(height: 6),
          Text('You can follow it under Account → Your reports.', textAlign: TextAlign.center, style: BtText.subhead(context)),
        ],
        const SizedBox(height: 22),
        BtButton(label: 'Done', onPressed: () => Navigator.of(context).maybePop()),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
