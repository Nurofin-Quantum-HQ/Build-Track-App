import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:buildtrack_mobile/design/design.dart';

import 'bug_report_service.dart';
import 'report_model.dart';

/// `/my-reports` — "Your reports": what you sent and where it stands.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});
  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<MyReport> _reports = const [];
  List<QueuedReport> _waiting = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = BugReportService.instance;
    if (mounted && _reports.isEmpty) setState(() => _loading = true);
    // Try to send anything saved offline first, so it shows up in the list.
    await svc.flushQueue();
    final waiting = await svc.waiting();
    try {
      final r = await svc.fetchMine();
      if (!mounted) return;
      setState(() {
        _reports = r;
        _waiting = waiting;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waiting = waiting;
        _loading = false;
        _failed = _reports.isEmpty;
      });
    }
  }

  static BtTone _tone(String status) {
    switch (status) {
      case 'in_progress':
        return BtTone.brand;
      case 'resolved':
        return BtTone.green;
      case 'closed':
        return BtTone.neutral;
      default:
        return BtTone.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: const BtNavBar(title: 'Your reports'),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(Bt.gutter), child: BtSkeletonList(count: 4));
    final empty = _reports.isEmpty && _waiting.isEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Bt.gutter, 8, Bt.gutter, 32),
        children: [
          if (_failed)
            BtErrorCard(message: "Couldn't load your reports", onRetry: _load)
          else if (empty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: BtEmpty(
                title: 'No reports yet',
                message: "If something isn't working, tell us from Account → Report a problem. We'll show it here.",
                icon: Icons.chat_bubble_outline_rounded,
              ),
            ),
          for (final q in _waiting) ...[_waitingCard(context, q), const SizedBox(height: 10)],
          for (final r in _reports) ...[_card(context, r), const SizedBox(height: 10)],
        ],
      ),
    );
  }

  Widget _waitingCard(BuildContext context, QueuedReport q) {
    return BtCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('NOT SENT YET', style: BtText.mono(context))),
          const BtBadge(label: 'Waiting to send', tone: BtTone.amber),
        ]),
        const SizedBox(height: 8),
        Text(q.draft.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: BtText.body(context)),
        const SizedBox(height: 6),
        Text("Saved on this phone — we'll send it when you're back online.", style: BtText.caption(context)),
      ]),
    );
  }

  Widget _card(BuildContext context, MyReport r) {
    final fmt = DateFormat('d MMM yyyy');
    final sub = [
      if (r.screenName != null && r.screenName!.isNotEmpty) r.screenName!,
      if (r.createdAt != null) fmt.format(r.createdAt!),
    ].join(' · ');
    return BtCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.code, style: BtText.mono(context))),
          BtBadge(label: MyReport.statusLabel(r.status), tone: _tone(r.status)),
        ]),
        const SizedBox(height: 8),
        Text(r.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: BtText.body(context)),
        if (sub.isNotEmpty) ...[const SizedBox(height: 6), Text(sub, style: BtText.caption(context))],
        if ((r.status == 'resolved' || r.status == 'closed') && r.resolutionNote != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(12)),
            child: Text(r.resolutionNote!, style: BtText.subhead(context, color: Bt.ink)),
          ),
        ],
      ]),
    );
  }
}
