import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart' show PaymentStatus;
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/models/task_model.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/services/task_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum InboxTab { approvals, activity }

/// What the screen shows: both tabs (`/inbox`), only the notification list
/// (`/notifications`, opened from the Home bell) or only pending approvals
/// (`/approvals`, Home's "See all").
enum InboxMode { both, notifications, approvals }

/// Inbox = Pending approvals (was /approvals) + Notifications (was /notifications).
/// Same data, same actions, one place (SCREEN-PLAN B32/B35). With [mode] it
/// shows a single list instead (no tabs).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.initialTab, this.mode = InboxMode.both});
  final InboxTab? initialTab;
  final InboxMode mode;

  /// Who sees the "To approve" segment: people who can act on it. The backend's
  /// approve/reject (PUT /transactions/:id/approve|reject) need approve_payments /
  /// approve_updates (Admins always) — being a Supervisor alone is not enough.
  static bool get canSeeApprovals => RoleManager.canApproveUpdates;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late InboxTab _tab;
  int _pendingCount = 0;
  num _pendingTotal = 0;
  int? _unread;
  final _activityKey = GlobalKey<_ActivityPaneState>();

  @override
  void initState() {
    super.initState();
    switch (widget.mode) {
      case InboxMode.notifications:
        _tab = InboxTab.activity;
        break;
      case InboxMode.approvals:
        _tab = InboxTab.approvals;
        break;
      case InboxMode.both:
        _tab = widget.initialTab ?? (InboxScreen.canSeeApprovals ? InboxTab.approvals : InboxTab.activity);
        if (!InboxScreen.canSeeApprovals) _tab = InboxTab.activity;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = context.read<NavController>();
      // Same marker for every mode: none of them is a bottom-bar tab.
      if (!Navigator.of(context).canPop()) nav.markCurrent('/inbox');
    });
  }

  String get _title => switch (widget.mode) {
        InboxMode.notifications => 'Notifications',
        InboxMode.approvals => 'Approvals',
        InboxMode.both => 'Inbox',
      };

  /// Tabs only in the combined Inbox (and only for people who can approve).
  bool get _showTabs => widget.mode == InboxMode.both && InboxScreen.canSeeApprovals;

  Widget _body() {
    final approvals = ApprovalsPane(
      onCount: (n) => setState(() => _pendingCount = n),
      onTotal: (t) => setState(() => _pendingTotal = t),
    );
    final activity = ActivityPane(key: _activityKey, onUnread: (n) => setState(() => _unread = n));
    switch (widget.mode) {
      case InboxMode.notifications:
        return activity;
      case InboxMode.approvals:
        return approvals;
      case InboxMode.both:
        return IndexedStack(index: _tab == InboxTab.approvals ? 0 : 1, children: [
          InboxScreen.canSeeApprovals ? approvals : const SizedBox.shrink(),
          activity,
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final glass = Colors.white.withValues(alpha: .09);
    return Scaffold(
      backgroundColor: Bt.ground,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BtHero(
          padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + (canPop ? 4 : 14), Bt.gutter, 18 + 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (canPop)
              Row(children: [
                Transform.translate(
                  offset: const Offset(-6, 0),
                  child: BtIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 18, color: Bt.bone, background: glass, semantic: 'Back', onTap: () => Navigator.of(context).maybePop()),
                ),
                const Spacer(),
                AnimatedSwitcher(duration: Bt.fast, child: _tab == InboxTab.activity ? _activityMenu() : const SizedBox(width: Bt.touch, height: Bt.touch)),
              ]),
            BtReveal(
              child: Row(children: [
                Expanded(child: Text(_title, style: BtText.d1(context, color: Bt.bone))),
                if (!canPop) AnimatedSwitcher(duration: Bt.fast, child: _tab == InboxTab.activity ? _activityMenu() : const SizedBox(width: Bt.touch, height: Bt.touch)),
              ]),
            ),
            if (_showTabs) ...[
              const SizedBox(height: 18),
              BtReveal(
                index: 1,
                child: BtSegmented<InboxTab>(
                  onDark: true,
                  segments: {
                    InboxTab.approvals: _pendingCount > 0 ? 'To approve · $_pendingCount' : 'To approve',
                    InboxTab.activity: 'Activity',
                  },
                  value: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
            ],
            const SizedBox(height: 16),
            BtReveal(
              index: 2,
              child: SizedBox(
                height: 32,
                child: AnimatedSwitcher(
                  duration: Bt.fast,
                  child: _tab == InboxTab.approvals ? _approvalsSummary() : _activitySummary(),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -26),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
              child: _body(),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: canPop ? null : AppBottomNav(),
    );
  }

  Widget _approvalsSummary() {
    return Row(key: const ValueKey('a'), crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Text(_pendingCount > 0 ? 'Waiting for you' : 'Nothing waiting', style: BtText.subhead(context, color: Bt.onNoir2))),
      if (_pendingCount > 0)
        BtCountUp(
          value: _pendingTotal.toDouble(),
          format: (v) => formatInr(v),
          style: BtText.d3(context, color: Bt.bone),
        ),
    ]);
  }

  Widget _activitySummary() {
    final unread = _unread;
    return Row(key: const ValueKey('b'), children: [
      Expanded(
        child: Text(
          unread == null ? 'Activity' : (unread > 0 ? '$unread unread' : 'All caught up!'),
          style: BtText.num(BtText.subhead(context, color: Bt.onNoir2)),
        ),
      ),
      if ((unread ?? 0) > 0)
        TextButton(
          onPressed: () => _activityKey.currentState?.menu('read'),
          style: TextButton.styleFrom(foregroundColor: context.bt.accent, minimumSize: const Size(44, 32), padding: const EdgeInsets.symmetric(horizontal: 4)),
          child: Text('Mark all as read', style: BtText.subhead(context, weight: FontWeight.w600, color: context.bt.accent)),
        ),
    ]);
  }

  Widget _activityMenu() {
    return PopupMenuButton<String>(
      key: const ValueKey('menu'),
      tooltip: 'More',
      color: Bt.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) => _activityKey.currentState?.menu(v),
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'read', child: Row(children: [const Icon(Icons.done_all_rounded, size: 20), const SizedBox(width: 10), Text('Mark all as read', style: BtText.body(ctx))])),
        PopupMenuItem(value: 'clear', child: Row(children: [const Icon(Icons.delete_sweep_outlined, size: 20, color: Bt.red), const SizedBox(width: 10), Text('Clear all…', style: BtText.body(ctx, color: Bt.red))])),
      ],
      child: Container(
        width: Bt.touch,
        height: Bt.touch,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: Bt.bone),
      ),
    );
  }
}

// ───────────────────────────────────────────── To approve (logic from ApprovalsScreen)

class ApprovalsPane extends StatefulWidget {
  const ApprovalsPane({super.key, this.onCount, this.onTotal});
  final ValueChanged<int>? onCount;

  /// Total ₹ waiting (shown in the Inbox hero).
  final ValueChanged<num>? onTotal;
  @override
  State<ApprovalsPane> createState() => _ApprovalsPaneState();
}

class _ApprovalsPaneState extends State<ApprovalsPane> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  /// Pending daily / project updates (GET /approvals/pending → projectUpdates),
  /// approved with PUT /project-updates/:id/approve|reject.
  List<dynamic> _projectUpdates = [];

  /// The last load failed. With nothing on screen this shows an error + Retry
  /// (not "You're all caught up").
  bool _failed = false;
  bool _loadedOnce = false;
  final Set<String> _busy = {};

  /// Approved items that are animating out (tick + slide) until the refresh lands.
  final Set<String> _leaving = {};

  @override
  void initState() {
    super.initState();
    _fetchPendingApprovals();
  }

  Future<void> _fetchPendingApprovals() async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? data;
    try {
      data = await ApiService.fetchPendingApprovals();
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    final hadData = _loadedOnce;
    setState(() {
      _isLoading = false;
      _failed = data == null;
      if (data != null) {
        _loadedOnce = true;
        _transactions = (data['transactions'] as List?) ?? [];
        _projectUpdates = (data['projectUpdates'] as List?) ?? [];
      }
    });
    if (data == null) {
      // A refresh that fails keeps the list on screen; tell the user.
      if (hadData) btToast(context, "Couldn't refresh approvals — check your connection.", error: true);
      return;
    }
    widget.onCount?.call(_transactions.length + _projectUpdates.length);
    widget.onTotal?.call(_transactions.fold<num>(0, (a, t) => a + _num(t['amount'])));
    final ids = {
      ..._transactions.map((t) => (t['_id'] ?? t['id']).toString()),
      ..._projectUpdates.map((u) => (u['_id'] ?? u['id']).toString()),
    };
    _leaving.removeWhere((id) => !ids.contains(id));
  }

  Future<void> _handleApproveTx(String id) async {
    setState(() => _busy.add(id));
    final success = await ApiService.approveTransaction(id);
    if (!mounted) return;
    setState(() {
      _busy.remove(id);
      if (success) _leaving.add(id);
    });
    if (success) {
      btToast(context, 'Transaction approved');
      _fetchPendingApprovals();
    } else {
      btToast(context, "Couldn't approve — check your connection and try again.", error: true);
    }
  }

  Future<void> _handleRejectTx(dynamic tx) async {
    final id = (tx['_id'] ?? tx['id']).toString();
    final ok = await _confirmReject(tx);
    if (!ok || !mounted) return;
    setState(() => _busy.add(id));
    final success = await ApiService.rejectTransaction(id, 'Rejected by supervisor/admin');
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (success) {
      btToast(context, 'Transaction rejected');
      _fetchPendingApprovals();
    } else {
      btToast(context, "Couldn't reject — check your connection and try again.", error: true);
    }
  }

  // PUT /project-updates/:id/approve needs `approve_updates`; reject takes
  // approve_updates or reject_updates (Admins always) — see backend
  // projectUpdateRoutes.js. `approve_payments` alone is not enough here.
  static bool get _canApproveProjectUpdates => RoleManager.isAdmin || UserSession.hasPermission('approve_updates');
  static bool get _canRejectProjectUpdates => _canApproveProjectUpdates || UserSession.hasPermission('reject_updates');

  Future<void> _handleApproveUpdate(String id) async {
    setState(() => _busy.add(id));
    final success = await ApiService.approveProjectUpdate(id);
    if (!mounted) return;
    setState(() {
      _busy.remove(id);
      if (success) _leaving.add(id);
    });
    if (success) {
      btToast(context, 'Update approved');
      _fetchPendingApprovals();
    } else {
      btToast(context, "Couldn't approve the update — try again.", error: true);
    }
  }

  Future<void> _handleRejectUpdate(dynamic u) async {
    final id = (u['_id'] ?? u['id']).toString();
    final by = u['createdBy'];
    final who = by is Map ? (by['name'] ?? '').toString() : '';
    final ok = await _rejectSheet('Reject this update?', [
      TextSpan(text: _updateTitle(u)),
      TextSpan(text: who.isNotEmpty ? ' from $who.' : '.'),
      const TextSpan(text: '\nThe person who sent it will see it as rejected.'),
    ]);
    if (!ok || !mounted) return;
    setState(() => _busy.add(id));
    final success = await ApiService.rejectProjectUpdate(id, 'Rejected by supervisor/admin');
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (success) {
      btToast(context, 'Update rejected');
      _fetchPendingApprovals();
    } else {
      btToast(context, "Couldn't reject the update — try again.", error: true);
    }
  }

  static String _updateTitle(dynamic u) {
    final stage = (u['stage'] ?? '').toString();
    final project = u['project'] is Map ? (u['project']['projectName'] ?? '').toString() : '';
    final t = [if (stage.isNotEmpty) stage, if (project.isNotEmpty) project].join(' · ');
    return t.isEmpty ? 'Project update' : t;
  }

  static num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

  /// Reject confirmation for an entry. Returns true to reject.
  Future<bool> _confirmReject(dynamic tx) {
    final by = tx['createdBy'];
    final who = by is Map ? (by['name'] ?? '') : '';
    return _rejectSheet('Reject this entry?', [
      TextSpan(text: '${tx['title'] ?? 'Transaction'} · '),
      TextSpan(text: formatInr(_num(tx['amount'])), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
      TextSpan(text: who.toString().isNotEmpty ? ' from $who.' : '.'),
      const TextSpan(text: '\nThe person who logged it will see it as rejected.'),
    ]);
  }

  /// Reject confirmation as a bottom sheet (Reject-Sheet board). Returns true to reject.
  Future<bool> _rejectSheet(String heading, List<InlineSpan> detail) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Bt.card,
      barrierColor: Bt.scrim,
      useSafeArea: true,
      sheetAnimationStyle: btSheetStyle(context, ms: 460, reverseMs: 240),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 20),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: Bt.reduceMotion(ctx) ? 1 : .6, end: 1),
                duration: Bt.slow,
                curve: Bt.spring,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Bt.redSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Bt.red, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(heading, textAlign: TextAlign.center, style: BtText.d2(ctx)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: detail),
              textAlign: TextAlign.center,
              style: BtText.body(ctx, color: Bt.ink2),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              child: BtPressable(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  height: Bt.buttonH,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Bt.redBright, borderRadius: BorderRadius.circular(Bt.rButton)),
                  child: Text('Reject', style: BtText.button(ctx, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            BtButton(label: 'Cancel', variant: BtButtonVariant.quiet, onPressed: () => Navigator.pop(ctx, false)),
          ]),
        ),
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_loadedOnce) {
      return const Padding(padding: EdgeInsets.fromLTRB(16, 22, 16, 16), child: BtSkeletonList(count: 4));
    }
    if (_failed && !_loadedOnce) {
      return RefreshIndicator(
        onRefresh: _fetchPendingApprovals,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 22, 16, 16), children: [
          BtErrorCard(message: "Couldn't load approvals. Check your connection.", onRetry: _fetchPendingApprovals),
        ]),
      );
    }
    final total = _transactions.fold<num>(0, (a, t) => a + _num(t['amount']));
    return RefreshIndicator(
      onRefresh: _fetchPendingApprovals,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 66),
        children: [
          if (_transactions.isEmpty && _projectUpdates.isEmpty)
            const BtEmpty(icon: Icons.task_alt_rounded, title: "You're all caught up", message: 'No pending approvals at this time.'),
          if (_projectUpdates.isNotEmpty) ...[
            BtSectionHeader(title: 'Project updates · ${_projectUpdates.length}', caption: true),
            for (var i = 0; i < _projectUpdates.length; i++)
              BtReveal(
                key: ValueKey('u-${(_projectUpdates[i]['_id'] ?? _projectUpdates[i]['id'])}'),
                index: i < 8 ? i : 8,
                child: _updateRow(_projectUpdates[i]),
              ),
            if (_transactions.isNotEmpty) ...[
              const SizedBox(height: 10),
              BtSectionHeader(title: 'Entries · ${_transactions.length}', caption: true),
            ],
          ],
          if (_transactions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text('${formatInr(total)} waiting across ${_transactions.length} ${_transactions.length == 1 ? 'entry' : 'entries'}', textAlign: TextAlign.center, style: BtText.num(BtText.caption(context, color: Bt.ink2))),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Approve with the tick. Reject asks you to confirm first.', textAlign: TextAlign.center, style: BtText.caption(context)),
            ),
            for (var i = 0; i < _transactions.length; i++)
              BtReveal(
                key: ValueKey('r-${(_transactions[i]['_id'] ?? _transactions[i]['id'])}'),
                index: i < 8 ? i : 8,
                child: _row(_transactions[i]),
              ),
          ],
        ],
      ),
    );
  }

  /// A pending project / daily update: stage, project, who, work done,
  /// remarks, photo count; Approve / Reject… (confirm) like entries.
  Widget _updateRow(dynamic u) {
    final id = (u['_id'] ?? u['id']).toString();
    final by = u['createdBy'];
    final who = by is Map ? (by['name'] ?? 'Unknown') : 'Unknown';
    final role = by is Map ? (by['role'] ?? 'Worker') : 'Worker';
    final project = u['project'] is Map ? (u['project']['projectName'] ?? 'Unknown') : 'Unknown';
    final stage = (u['stage'] ?? '').toString();
    final workDone = u['workDone'];
    final remarks = (u['remarks'] ?? '').toString().trim();
    final media = u['media'] is List ? (u['media'] as List).length : 0;
    DateTime? created;
    try {
      created = DateTime.parse((u['createdAt'] ?? '').toString()).toLocal();
    } catch (_) {}
    final meta = [
      if (workDone is num) '${workDone % 1 == 0 ? workDone.toInt() : workDone}% done',
      if (media > 0) '$media photo${media == 1 ? '' : 's'}',
      if (created != null) '${formatDayGroup(created)}, ${formatTime(created)}',
    ].join(' · ');
    final busy = _busy.contains(id);
    final leaving = _leaving.contains(id);
    final canApprove = _canApproveProjectUpdates;
    final canReject = _canRejectProjectUpdates;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BtTile(icon: Icons.add_task_rounded, bg: context.bt.accentSoft, fg: context.bt.accentInk, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stage.isNotEmpty ? 'Update · $stage' : 'Project update', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$who ($role) · $project', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.ink2)),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(meta, style: BtText.num(BtText.caption(context))),
            ],
          ]),
        ),
      ]),
      if (remarks.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(remarks, maxLines: 3, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.ink)),
      ],
      if (canApprove || canReject) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: busy
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : Row(children: [
                  if (canReject)
                    Expanded(
                      child: _ActionButton(
                        label: 'Reject…',
                        icon: Icons.close_rounded,
                        fg: Bt.red,
                        bg: Bt.card,
                        border: Bt.inputBorder,
                        onTap: leaving ? null : () => _handleRejectUpdate(u),
                      ),
                    ),
                  if (canReject && canApprove) const SizedBox(width: 8),
                  if (canApprove)
                    Expanded(
                      child: _ActionButton(
                        label: 'Approve',
                        semantic: 'Approve update',
                        icon: Icons.check_rounded,
                        fg: Colors.white,
                        bg: Bt.green,
                        onTap: leaving ? null : () => _handleApproveUpdate(id),
                      ),
                    ),
                ]),
        ),
      ],
    ]);
    return _animatedCard(id, body);
  }

  Widget _row(dynamic tx) {
    final id = (tx['_id'] ?? tx['id']).toString();
    final by = tx['createdBy'];
    final who = by is Map ? (by['name'] ?? 'Unknown') : 'Unknown';
    final role = by is Map ? (by['role'] ?? 'Worker') : 'Worker';
    final project = tx['project'] is Map ? (tx['project']['projectName'] ?? 'Unknown') : 'Unknown';
    final busy = _busy.contains(id);
    final leaving = _leaving.contains(id);
    return _animatedCard(
      id,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BtTypeTile(type: '${tx['category'] ?? ''} ${tx['type'] ?? ''} ${tx['title'] ?? ''}'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx['title']?.toString() ?? 'Transaction', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$who ($role) · $project', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: Bt.ink2)),
              ]),
            ),
            const SizedBox(width: 10),
            Text(formatInr(_num(tx['amount'])), style: BtText.num(BtText.body(context, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: busy
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Reject…',
                        icon: Icons.close_rounded,
                        fg: Bt.red,
                        bg: Bt.card,
                        border: Bt.inputBorder,
                        onTap: leaving ? null : () => _handleRejectTx(tx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Approve',
                        semantic: 'Approve',
                        icon: Icons.check_rounded,
                        fg: Colors.white,
                        bg: Bt.green,
                        onTap: leaving ? null : () => _handleApproveTx(id),
                      ),
                    ),
                  ]),
          ),
        ]),
    );
  }

  /// Card + "Approved" overlay + slide-out while [id] is leaving.
  Widget _animatedCard(String id, Widget content) {
    final leaving = _leaving.contains(id);
    final reduce = Bt.reduceMotion(context);
    final card = BtCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Stack(children: [
        content,
        // Approved: green wash + tick draws in while the card slides away.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: leaving ? 1 : 0,
              duration: Bt.fast,
              child: Container(
                decoration: BoxDecoration(color: Bt.greenSoft.withValues(alpha: .94), borderRadius: BorderRadius.circular(Bt.rCard - 6)),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: leaving ? 1 : .4,
                  duration: Bt.medium,
                  curve: Bt.spring,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Bt.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text('Approved', style: BtText.headline(context).copyWith(color: Bt.green)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 380),
      curve: Bt.ease,
      alignment: Alignment.topCenter,
      child: leaving
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
              curve: const Interval(.45, 1, curve: Curves.easeInCubic),
              builder: (_, t, child) => ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1 - Curves.easeInOut.transform(((t - .55) / .45).clamp(0.0, 1.0)),
                  child: Opacity(
                    opacity: 1 - t,
                    child: Transform.translate(offset: Offset(MediaQuery.sizeOf(context).width * .6 * t, 0), child: child),
                  ),
                ),
              ),
              child: Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
            )
          : Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
    );
  }
}

/// Compact action button for approval cards (42 h, radius 14).
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.fg, required this.bg, this.border, this.onTap, this.semantic});
  final String label;
  final String? semantic;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color? border;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: BtPressable(
        onTap: onTap,
        scale: .96,
        child: Container(
          height: 42,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: border == null ? null : Border.all(color: border!)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(label, style: BtText.button(context, size: 14, color: fg)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────── Activity (logic from NotificationsScreen)

class ActivityPane extends StatefulWidget {
  const ActivityPane({super.key, this.onUnread});

  /// Unread count (shown in the Inbox hero).
  final ValueChanged<int>? onUnread;
  @override
  State<ActivityPane> createState() => _ActivityPaneState();
}

class _ActivityPaneState extends State<ActivityPane> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasError = false;
  int _page = 1;
  int _pages = 1;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    final targetPage = append ? _page + 1 : 1;
    try {
      final data = await ApiService.fetchNotificationPage(page: targetPage, limit: 50);
      if (!mounted) return;
      setState(() {
        final items = (data['items'] as List?) ?? <dynamic>[];
        if (append) {
          final existing = _notifications.map((n) => n['_id']).toSet();
          final incoming = items.where((n) => !existing.contains(n['_id'])).toList();
          _notifications = [..._notifications, ...incoming];
        } else {
          _notifications = items;
        }
        _page = (data['page'] as int?) ?? targetPage;
        _pages = (data['pages'] as int?) ?? 1;
        _isLoading = false;
        _loadingMore = false;
        _hasError = false;
      });
      widget.onUnread?.call(_notifications.where((n) => n['read'] == false).length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingMore = false;
        _hasError = !append;
      });
    }
  }

  void _retry() => _fetchNotifications();

  Future<void> menu(String v) async {
    if (v == 'read') {
      await _markAllRead();
    } else if (v == 'clear') {
      if (_notifications.isEmpty) return;
      final ok = await btConfirm(context, title: 'Clear all notifications?', message: 'This removes every notification from your inbox.', confirmLabel: 'Clear all');
      if (ok) await _clearAll();
    }
  }

  Future<void> _markAllRead() async {
    bool ok;
    try {
      ok = await ApiService.markAllNotificationsAsRead();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) btToast(context, "Couldn't mark notifications as read — try again.", error: true);
    _fetchNotifications();
  }

  Future<void> _clearAll() async {
    bool ok;
    try {
      ok = await ApiService.clearAllNotifications();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) btToast(context, "Couldn't clear notifications — try again.", error: true);
    _fetchNotifications();
  }

  /// Where a (non-transaction) notification opens — only screens this user may
  /// open (same gates as the dock / RoleManager). Task notifications are
  /// handled in [_openTask]. Before: a Mason's task opened `/` (Login, over a
  /// live session) and inventory / assign-task opened without any check.
  String? _targetRoute(dynamic n) {
    final nav = context.read<NavController>();
    switch (n['relatedModel']) {
      case 'Transaction':
        return nav.isRouteEnabled('/logs') ? '/logs' : null;
      case 'Inventory':
        if (nav.isRouteEnabled('/inventory')) return '/inventory';
        if (RoleManager.canAddTransactions) return '/add-material';
        return null;
      case 'Project':
        return nav.isRouteEnabled('/projects') ? '/projects' : null;
      case 'Payment':
        return RoleManager.isAdmin ? '/subscription' : null;
      default:
        return null;
    }
  }

  /// Task notification ("New Task Assigned" / "Task Completed"). There's no
  /// GET /tasks/:id, so the task is looked up in GET /tasks/daily (tasks
  /// assigned to or created by me). My open task → the daily-update screen
  /// with that task (same arguments Home's task cards pass); anything else →
  /// Home, where "Tasks assigned" lists it.
  Future<void> _openTask(String? notificationId, String taskId) async {
    if (_opening != null) return;
    setState(() => _opening = notificationId ?? taskId);
    TaskModel? task;
    var failed = false;
    try {
      final tasks = await TaskService.getDailyTasks();
      for (final t in tasks) {
        if (t.id == taskId) {
          task = t;
          break;
        }
      }
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _opening = null);
    if (failed) {
      btToast(context, "Couldn't open this task — check your connection.", error: true);
      return;
    }
    if (task == null) {
      btToast(context, 'This task is no longer available.', error: true);
      return;
    }
    final me = UserSession.userId;
    final assignee = (task.assignedTo?['_id'] ?? task.assignedTo?['id'])?.toString();
    if (me.isNotEmpty && assignee == me && task.status != 'Completed') {
      Navigator.pushNamed(context, '/update-progress', arguments: {'task': task});
      return;
    }
    context.read<NavController>().setRoute('/home', context);
  }

  /// Notification currently being opened (its entry is being fetched).
  String? _opening;

  void _openNotification(dynamic n) {
    final id = n['_id'] as String?;
    if (id != null && n['read'] != true) {
      ApiService.markNotificationAsRead(id).then((_) {
        if (mounted) _fetchNotifications();
      });
    }
    final relatedId = n['relatedId']?.toString() ?? '';
    if (n['relatedModel'] == 'Transaction' && relatedId.isNotEmpty) {
      _openTransaction(id, relatedId);
      return;
    }
    if (n['relatedModel'] == 'Task') {
      if (relatedId.isNotEmpty) {
        _openTask(id, relatedId);
      } else {
        context.read<NavController>().setRoute('/home', context);
      }
      return;
    }
    final route = _targetRoute(n);
    if (route != null && mounted) {
      Navigator.pushNamed(context, route);
    }
  }

  /// "Entry Approved / Rejected / Payment Received" → that entry's detail
  /// (`/entry-detail`), not the project log. The notification only carries the
  /// id, so the entry is fetched and mapped to the arguments the detail screen
  /// reads (same mapping as the project screen's entry tiles).
  Future<void> _openTransaction(String? notificationId, String txId) async {
    if (_opening != null) return;
    setState(() => _opening = notificationId ?? txId);
    final tx = await ApiService.fetchTransactionById(txId);
    if (!mounted) return;
    setState(() => _opening = null);
    if (tx == null) {
      btToast(context, "This entry can't be opened — it may have been deleted.", error: true);
      return;
    }
    final type = (tx['type'] ?? '').toString().toLowerCase().trim();
    if (type == 'income' || type == 'revenue') {
      // Client money lives on Home (Client money → history), not in entry detail.
      context.read<NavController>().setRoute('/home', context);
      return;
    }
    Navigator.pushNamed(context, '/entry-detail', arguments: entryDetailArgs(tx));
  }

  /// Raw transaction (GET /transactions/:id) → `/entry-detail` arguments.
  static Map<String, dynamic> entryDetailArgs(Map<String, dynamic> tx) {
    final rawCat = (tx['category'] ?? '').toString().trim().toLowerCase();
    final rawType = (tx['type'] ?? '').toString().trim().toLowerCase();
    var category = 'material';
    if (rawCat.contains('labour') || rawCat == 'wages' || rawCat == 'labor' || rawType == 'wages' || rawType == 'labour') {
      category = 'labour';
    } else if (rawCat == 'equipment' || rawCat == 'machinery' || rawCat == 'expense' || rawType == 'expense' || rawType == 'equipment') {
      category = 'equipment';
    }
    final isPositive = tx['subType']?.toString().toLowerCase() != 'consumption';
    final id = (tx['_id'] ?? tx['id'] ?? '').toString();
    final project = tx['project'];
    final projectId = project is Map ? (project['_id'] ?? '').toString() : (project ?? '').toString();
    final projectName = project is Map ? project['projectName']?.toString() : null;
    final createdBy = tx['createdBy'];
    final pay = (tx['paymentStatus'] ?? '').toString().toLowerCase();
    final payStatus = pay == 'paid'
        ? PaymentStatus.paid
        : pay == 'partial'
            ? PaymentStatus.partial
            : pay == 'overdue'
                ? PaymentStatus.overdue
                : PaymentStatus.pending;
    final approval = (tx['approvalStatus'] ?? '').toString().toLowerCase();
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    final attachments = tx['attachments'];
    return {
      ...tx,
      'id': id,
      'title': tx['title'] ?? tx['materialName'] ?? 'Entry',
      'ref': id.length > 4 ? '#${id.substring(id.length - 4)}' : '#$id',
      'amount': '${isPositive ? '+' : '-'}${tx['quantity'] ?? 0}',
      'date': tx['date']?.toString() ?? '',
      'isPositive': isPositive,
      'type': category,
      'name': tx['title'] ?? tx['materialName'] ?? 'Entry',
      'receipt': (attachments is List && attachments.isNotEmpty) ? attachments.first?.toString() : null,
      'attachment': null,
      'createdBy': createdBy is Map ? (createdBy['_id'] ?? '').toString() : (createdBy ?? '').toString(),
      'project': projectId,
      'projectId': projectId,
      'projectName': ?projectName,
      'status': approval == 'approved' ? 'approved' : (approval == 'rejected' ? 'rejected' : 'pending'),
      'paymentStatus': payStatus,
      'billAmount': d(tx['amount']),
      'paidAmount': d(tx['paidAmount']),
      'supplier': tx['supplier'] ?? '',
      'paymentMethod': tx['paymentMode'] ?? '',
      'lastUpdated': tx['updatedAt'] ?? tx['date'] ?? '',
      'paymentHistory': tx['paymentHistory'],
      'rate': d(tx['rate']),
      'brand': tx['brand'] ?? '',
      'notes': tx['notes'] ?? '',
      'remarks': tx['remarks'] ?? '',
      'categoryName': tx['category'] ?? '',
      'quantity': d(tx['quantity']),
      'overtime': d(tx['overtime']),
      'subType': tx['subType'] ?? '',
      'materialType': tx['materialType'] ?? '',
      'floor': tx['floor']?.toString(),
      'phase': tx['phase']?.toString(),
      'activity': tx['activity']?.toString(),
      'paymentReceipt': tx['paymentReceipt']?.toString(),
    };
  }

  IconData _icon(String type) {
    switch (type) {
      case 'approval':
        return Icons.task_alt_rounded;
      case 'payment':
        return Icons.account_balance_wallet_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'project':
        return Icons.apartment_outlined;
      case 'worker':
        return Icons.person_outline_rounded;
      case 'task':
        return Icons.assignment_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  DateTime? _date(dynamic n) {
    try {
      return DateTime.parse(n['createdAt']?.toString() ?? '').toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Tile colours per notification type (read items go neutral).
  ({Color bg, Color fg}) _tone(BuildContext context, dynamic n) {
    if (n['read'] == true) return (bg: Bt.fill, fg: Bt.ink2);
    final bt = context.bt;
    final text = '${n['title'] ?? ''} ${n['message'] ?? ''}'.toLowerCase();
    if (text.contains('reject')) return (bg: Bt.redSoft, fg: Bt.red);
    if (text.contains('approved')) return (bg: Bt.greenSoft, fg: Bt.green);
    return (bg: bt.accentSoft, fg: bt.accentInk);
  }

  String _moduleLabel(dynamic n) {
    final m = n['relatedModel']?.toString() ?? '';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.fromLTRB(16, 22, 16, 16), child: BtSkeletonList(count: 5));
    if (_hasError) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 22, 16, 16), children: [BtErrorCard(message: "Couldn't load notifications", onRetry: _retry)]);
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(onRefresh: _fetchNotifications, child: ListView(padding: const EdgeInsets.only(top: 20), children: const [BtEmpty(icon: Icons.notifications_none_rounded, title: 'No notifications', message: 'All caught up!')]));
    }
    final unread = _notifications.where((n) => n['read'] == false).length;
    // group by day, keep server order
    final groups = <String, List<dynamic>>{};
    for (final n in _notifications) {
      groups.putIfAbsent(formatDayGroup(_date(n)), () => []).add(n);
    }
    var gi = 0;
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 66),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(unread > 0 ? '$unread unread' : 'All caught up!', style: BtText.num(BtText.caption(context, color: Bt.ink2)))),
          for (final g in groups.entries)
            BtReveal(
              index: gi++,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  BtSectionHeader(title: g.key, caption: true),
                  BtGroup(children: [for (final n in g.value) _tile(n)]),
                ]),
              ),
            ),
          if (_page < _pages)
            Center(
              child: _loadingMore
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                  : BtButton(label: 'Load more', variant: BtButtonVariant.secondary, small: true, expand: false, onPressed: () => _fetchNotifications(append: true)),
            ),
        ],
      ),
    );
  }

  Widget _tile(dynamic n) {
    final read = n['read'] == true;
    final tone = _tone(context, n);
    final meta = [_moduleLabel(n), formatTime(_date(n))].where((s) => s.isNotEmpty).join(' · ');
    final message = n['message']?.toString() ?? '';
    return InkWell(
      onTap: () => _openNotification(n),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: Bt.fast,
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(_icon(n['type']?.toString() ?? ''), size: 18, color: tone.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, weight: read ? FontWeight.w500 : FontWeight.w700, color: Bt.ink)),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: read ? Bt.ink2 : Bt.ink)),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(meta, style: BtText.caption(context).copyWith(fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          if (_opening != null && _opening == (n['_id'] ?? n['relatedId'])?.toString())
            const Padding(padding: EdgeInsets.only(top: 4), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            AnimatedOpacity(
              opacity: read ? 0 : 1,
              duration: Bt.fast,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: context.bt.accent, shape: BoxShape.circle)),
              ),
            ),
        ]),
      ),
    );
  }
}
