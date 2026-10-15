import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum InboxTab { approvals, activity }

/// Inbox = Pending approvals (was /approvals) + Notifications (was /notifications).
/// Same data, same actions, one place (SCREEN-PLAN B32/B35).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.initialTab});
  final InboxTab? initialTab;

  /// Who sees the "To approve" segment (same people who saw pending approvals before).
  static bool get canSeeApprovals => UserSession.isAdmin || UserSession.isSupervisor || RoleManager.canApproveUpdates;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late InboxTab _tab;
  int _pendingCount = 0;
  final _activityKey = GlobalKey<_ActivityPaneState>();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ?? (InboxScreen.canSeeApprovals ? InboxTab.approvals : InboxTab.activity);
    if (!InboxScreen.canSeeApprovals) _tab = InboxTab.activity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = context.read<NavController>();
      if (!Navigator.of(context).canPop()) nav.markCurrent('/inbox');
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Bt.ground,
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (canPop) BtNavBar(title: 'Inbox', trailing: _tab == InboxTab.activity ? _activityMenu() : null)
          else BtLargeHeader(title: 'Inbox', trailing: _tab == InboxTab.activity ? _activityMenu() : null),
          if (InboxScreen.canSeeApprovals)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: BtSegmented<InboxTab>(
                segments: {
                  InboxTab.approvals: _pendingCount > 0 ? 'To approve · $_pendingCount' : 'To approve',
                  InboxTab.activity: 'Activity',
                },
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _tab == InboxTab.approvals ? 0 : 1, children: [
              InboxScreen.canSeeApprovals ? ApprovalsPane(onCount: (n) => setState(() => _pendingCount = n)) : const SizedBox.shrink(),
              ActivityPane(key: _activityKey),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: canPop ? null : AppBottomNav(),
    );
  }

  Widget _activityMenu() {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz_rounded, color: Bt.ink),
      color: Bt.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) => _activityKey.currentState?.menu(v),
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'read', child: Row(children: [const Icon(Icons.done_all_rounded, size: 20), const SizedBox(width: 10), Text('Mark all as read', style: BtText.body(ctx))])),
        PopupMenuItem(value: 'clear', child: Row(children: [const Icon(Icons.delete_sweep_outlined, size: 20, color: Bt.red), const SizedBox(width: 10), Text('Clear all…', style: BtText.body(ctx, color: Bt.red))])),
      ],
    );
  }
}

// ───────────────────────────────────────────── To approve (logic from ApprovalsScreen)

class ApprovalsPane extends StatefulWidget {
  const ApprovalsPane({super.key, this.onCount});
  final ValueChanged<int>? onCount;
  @override
  State<ApprovalsPane> createState() => _ApprovalsPaneState();
}

class _ApprovalsPaneState extends State<ApprovalsPane> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  // ignore: unused_field
  List<dynamic> _projectUpdates = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _fetchPendingApprovals();
  }

  Future<void> _fetchPendingApprovals() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchPendingApprovals();
    if (data != null && mounted) {
      setState(() {
        _transactions = data['transactions'] ?? [];
        _projectUpdates = data['projectUpdates'] ?? [];
      });
      widget.onCount?.call(_transactions.length);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleApproveTx(String id) async {
    setState(() => _busy.add(id));
    final success = await ApiService.approveTransaction(id);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (success) {
      btToast(context, 'Transaction approved');
      _fetchPendingApprovals();
    }
  }

  Future<void> _handleRejectTx(dynamic tx) async {
    final id = (tx['_id'] ?? tx['id']).toString();
    final ok = await btConfirm(
      context,
      title: 'Reject this entry?',
      message: '${tx['title'] ?? 'Transaction'} · ${formatInr(_num(tx['amount']))}\nThe person who logged it will see it as rejected.',
      confirmLabel: 'Reject',
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(id));
    final success = await ApiService.rejectTransaction(id, 'Rejected by supervisor/admin');
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (success) {
      btToast(context, 'Transaction rejected');
      _fetchPendingApprovals();
    }
  }

  static num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _transactions.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 4));
    }
    final total = _transactions.fold<num>(0, (a, t) => a + _num(t['amount']));
    return RefreshIndicator(
      onRefresh: _fetchPendingApprovals,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (_transactions.isEmpty)
            const BtEmpty(icon: Icons.task_alt_rounded, title: "You're all caught up", message: 'No pending approvals at this time.')
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text('${formatInr(total)} waiting across ${_transactions.length} ${_transactions.length == 1 ? 'entry' : 'entries'}', style: BtText.subhead(context)),
            ),
            BtGroup(children: [for (final tx in _transactions) _row(tx)]),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Approve with the tick. Reject asks you to confirm first.', textAlign: TextAlign.center, style: BtText.caption(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(dynamic tx) {
    final id = (tx['_id'] ?? tx['id']).toString();
    final by = tx['createdBy'];
    final who = by is Map ? (by['name'] ?? 'Unknown') : 'Unknown';
    final role = by is Map ? (by['role'] ?? 'Worker') : 'Worker';
    final project = tx['project'] is Map ? (tx['project']['projectName'] ?? 'Unknown') : 'Unknown';
    final busy = _busy.contains(id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BtTypeTile(type: '${tx['category'] ?? ''} ${tx['type'] ?? ''} ${tx['title'] ?? ''}'),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx['title']?.toString() ?? 'Transaction', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(formatInr(_num(tx['amount'])), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
            const SizedBox(height: 2),
            Text('$who ($role) · $project', maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.caption(context)),
          ]),
        ),
        const SizedBox(width: 8),
        if (busy)
          const SizedBox(width: 44, height: 44, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
        else
          Column(mainAxisSize: MainAxisSize.min, children: [
            Semantics(
              button: true,
              label: 'Approve',
              child: Material(
                color: Bt.greenSoft,
                shape: const CircleBorder(),
                child: InkWell(customBorder: const CircleBorder(), onTap: () => _handleApproveTx(id), child: const SizedBox(width: 44, height: 44, child: Icon(Icons.check_rounded, color: Bt.green))),
              ),
            ),
            TextButton(
              onPressed: () => _handleRejectTx(tx),
              style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 6), foregroundColor: Bt.red),
              child: Text('Reject', style: BtText.caption(context, color: Bt.red, weight: FontWeight.w600)),
            ),
          ]),
      ]),
    );
  }
}

// ───────────────────────────────────────────── Activity (logic from NotificationsScreen)

class ActivityPane extends StatefulWidget {
  const ActivityPane({super.key});
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
    await ApiService.markAllNotificationsAsRead();
    _fetchNotifications();
  }

  Future<void> _clearAll() async {
    await ApiService.clearAllNotifications();
    _fetchNotifications();
  }

  String? _targetRoute(dynamic n) {
    final isWorker = UserSession.isMason;
    switch (n['relatedModel']) {
      case 'Transaction':
        return '/logs';
      case 'Inventory':
        if (isWorker) return '/add-material';
        return '/inventory';
      case 'Task':
        if (isWorker) return '/';
        return '/assign-task';
      case 'Project':
        return '/projects';
      case 'Payment':
        return '/subscription';
      default:
        return null;
    }
  }

  void _openNotification(dynamic n) {
    final id = n['_id'] as String?;
    if (id != null && n['read'] != true) {
      ApiService.markNotificationAsRead(id).then((_) {
        if (mounted) _fetchNotifications();
      });
    }
    final route = _targetRoute(n);
    if (route != null && mounted) {
      Navigator.pushNamed(context, route);
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 5));
    if (_hasError) {
      return ListView(padding: const EdgeInsets.all(16), children: [BtErrorCard(message: "Couldn't load notifications", onRetry: _retry)]);
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(onRefresh: _fetchNotifications, child: ListView(children: const [BtEmpty(icon: Icons.notifications_none_rounded, title: 'No notifications', message: 'All caught up!')]));
    }
    final unread = _notifications.where((n) => n['read'] == false).length;
    // group by day, keep server order
    final groups = <String, List<dynamic>>{};
    for (final n in _notifications) {
      groups.putIfAbsent(formatDayGroup(_date(n)), () => []).add(n);
    }
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text(unread > 0 ? '$unread unread' : 'All caught up!', style: BtText.subhead(context))),
          for (final g in groups.entries) ...[
            BtSectionHeader(title: g.key, caption: true),
            BtGroup(children: [
              for (final n in g.value)
                BtRow(
                  leading: BtTile(icon: _icon(n['type']?.toString() ?? ''), bg: n['read'] == true ? Bt.fill : context.bt.brandSoft, fg: n['read'] == true ? Bt.ink2 : context.bt.brand),
                  title: n['title']?.toString() ?? '',
                  titleWeight: n['read'] == true ? FontWeight.w400 : FontWeight.w600,
                  subtitle: [n['message']?.toString() ?? '', formatTime(_date(n))].where((s) => s.isNotEmpty).join(' · '),
                  subtitleMaxLines: 3,
                  trailing: n['read'] == true ? null : Container(width: 8, height: 8, decoration: BoxDecoration(color: context.bt.brand, shape: BoxShape.circle)),
                  onTap: () => _openNotification(n),
                ),
            ]),
            const SizedBox(height: 16),
          ],
          if (_page < _pages)
            Center(
              child: _loadingMore
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                  : BtButton(label: 'Load more', variant: BtButtonVariant.secondary, small: true, expand: false, onPressed: () => _fetchNotifications(append: true)),
            ),
        ],
      ),
    );
  }
}
