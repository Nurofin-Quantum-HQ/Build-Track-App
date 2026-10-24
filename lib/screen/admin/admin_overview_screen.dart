import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});
  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}
class _AdminOverviewScreenState extends State<AdminOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _loadingUsers = true;
  bool _loadingTx = true;
  String? _usersError;
  String? _txError;
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadTransactions();
  }
  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }
  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final response = await ApiService.get('/auth/users');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List raw = decoded is List
            ? decoded
            : (decoded['users'] ?? decoded['data'] ?? []) as List;
        if (!mounted) return;
        setState(() {
          _users = raw.map((u) => Map<String, dynamic>.from(u as Map)).toList();
          _loadingUsers = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _usersError = 'Failed to load users (${response.statusCode})';
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = "Couldn't load users — check your connection.";
        _loadingUsers = false;
      });
    }
  }
  Future<void> _loadTransactions() async {
    setState(() {
      _loadingTx = true;
      _txError = null;
    });
    try {
      final response = await ApiService.get('/transactions');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List raw = decoded is List
            ? decoded
            : (decoded['transactions'] ?? decoded['data'] ?? []) as List;
        if (!mounted) return;
        setState(() {
          _transactions = raw
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();
          _loadingTx = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _txError = 'Failed to load entries (${response.statusCode})';
          _loadingTx = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _txError = "Couldn't load entries — check your connection.";
        _loadingTx = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (!RoleManager.canViewTeamAccess) {
      return Scaffold(
        backgroundColor: Bt.ground,
        appBar: const BtNavBar(title: 'Team & activity'),
        body: BtEmpty(
          icon: Icons.lock_outline_rounded,
          title: 'Admin access only',
          message: 'This screen is only accessible to Admins.\nContact your administrator for access.',
          action: 'Go Back',
          onAction: () => Navigator.maybePop(context),
        ),
      );
    }
    final glass = Colors.white.withValues(alpha: .09);
    return Scaffold(
      backgroundColor: Bt.ground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BtHero(
            padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + 4, Bt.gutter, 18 + 26),
            child: AnimatedBuilder(
              animation: _tabCtrl,
              builder: (context, _) {
                final onPeople = _tabCtrl.index == 0;
                final count = onPeople ? _users.length : _transactions.length;
                final loading = onPeople ? _loadingUsers : _loadingTx;
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Transform.translate(
                      offset: const Offset(-6, 0),
                      child: BtIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 18, color: Bt.bone, background: glass, semantic: 'Back', onTap: () => Navigator.of(context).maybePop()),
                    ),
                    Expanded(child: Text('Team & activity', textAlign: TextAlign.center, style: BtText.navTitle(context).copyWith(color: Bt.bone))),
                    const SizedBox(width: Bt.touch - 6),
                  ]),
                  const SizedBox(height: 12),
                  BtReveal(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          loading
                              ? Text('—', style: BtText.d0(context, color: Bt.bone))
                              : BtCountUp(
                                  key: ValueKey(onPeople),
                                  value: count.toDouble(),
                                  format: (v) => v.round().toString(),
                                  style: BtText.d0(context, color: Bt.bone),
                                ),
                          const SizedBox(height: 4),
                          Text(onPeople ? 'people on your team' : 'entries across the workspace', style: BtText.subhead(context, color: Bt.onNoir2)),
                        ]),
                      ),
                      if (RoleManager.canAssignRole)
                        BtButton(
                          label: 'Add member',
                          icon: Icons.add_rounded,
                          small: true,
                          expand: false,
                          variant: BtButtonVariant.accent,
                          onPressed: () => Navigator.pushNamed(context, '/assign-role').then((_) => _loadUsers()),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  BtReveal(
                    index: 1,
                    child: BtSegmented<int>(
                      onDark: true,
                      segments: {0: 'People (${_users.length})', 1: 'All entries (${_transactions.length})'},
                      value: _tabCtrl.index,
                      onChanged: (i) => _tabCtrl.animateTo(i),
                    ),
                  ),
                ]);
              },
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [_buildUsersTab(), _buildTransactionsTab()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Users grouped by role (in order of first appearance): "SUPERVISOR · 2".
  List<MapEntry<String, List<Map<String, dynamic>>>> get _usersByRole {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final u in _users) {
      final role = u['role']?.toString() ?? 'Mason';
      groups.putIfAbsent(role, () => []).add(u);
    }
    return groups.entries.toList();
  }

  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return const Padding(padding: EdgeInsets.fromLTRB(16, 22, 16, 16), child: BtSkeletonList(count: 3));
    }
    if (_usersError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
        child: Align(alignment: Alignment.topCenter, child: BtErrorCard(message: _usersError!, onRetry: _loadUsers)),
      );
    }
    if (_users.isEmpty) {
      return const BtEmpty(icon: Icons.group_outlined, title: 'No team members yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 66),
        children: [
          for (final (i, g) in _usersByRole.indexed)
            BtReveal(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  BtSectionHeader(title: '${g.key} · ${g.value.length}', caption: true),
                  BtGroup(
                    children: [
                      for (final u in g.value)
                        _UserCard(
                          user: u,
                          onEdit: () => Navigator.pushNamed(
                            context,
                            '/assign-role',
                            arguments: {'editUser': u},
                          ).then((_) => _loadUsers()),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildTransactionsTab() {
    if (_loadingTx) {
      return const Padding(padding: EdgeInsets.fromLTRB(16, 22, 16, 16), child: BtSkeletonList(count: 5));
    }
    if (_txError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
        child: Align(alignment: Alignment.topCenter, child: BtErrorCard(message: _txError!, onRetry: _loadTransactions)),
      );
    }
    if (_transactions.isEmpty) {
      return const BtEmpty(icon: Icons.receipt_long_outlined, title: 'No entries yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 66),
        children: [
          BtSectionHeader(title: 'All entries · ${_transactions.length}', caption: true),
          BtReveal(child: BtGroup(children: [for (final t in _transactions) _TxCard(tx: t)])),
        ],
      ),
    );
  }
}
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, this.onEdit});
  final Map<String, dynamic> user;
  final VoidCallback? onEdit;
  static String _human(String p) {
    final t = p.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Unknown';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'Mason';
    final permissions = (user['permissions'] as List?)?.cast<String>() ?? [];
    final projectIds = (user['projectIds'] as List?)?.cast<String>() ?? [];
    final isAdminUser = role.toLowerCase() == 'admin';
    final canEdit = !isAdminUser && onEdit != null;
    final tone = role.toLowerCase() == 'admin'
        ? BtTone.neutral
        : role.toLowerCase() == 'supervisor'
        ? BtTone.brand
        : BtTone.amber;
    final sub = [
      if (email.isNotEmpty) email,
      if (projectIds.isNotEmpty) '${projectIds.length} project${projectIds.length > 1 ? "s" : ""} assigned',
    ].join(' · ');
    void openDetails() {
      showBtSheet(
        context,
        title: name,
        subtitle: email.isEmpty ? role : '$role · $email',
        builder: (sheetCtx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BtGroup(children: [
              BtValueRow(label: 'Role', value: role),
              BtValueRow(label: 'Projects', value: projectIds.isEmpty ? 'All / none set' : '${projectIds.length} assigned'),
              BtValueRow(label: 'Permissions', value: '${permissions.length}'),
            ]),
            if (permissions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final p in permissions) BtBadge(label: _human(p))],
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 20),
              BtButton(
                label: 'Edit user',
                icon: Icons.edit_outlined,
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  onEdit!();
                },
              ),
            ],
          ],
        ),
      );
    }

    return BtRow(
      leading: BtAvatar(name: name, size: 40),
      title: name,
      subtitle: sub.isEmpty ? '${permissions.length} permissions' : sub,
      minHeight: 64,
      onTap: openDetails,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        BtBadge(label: role, tone: tone),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: Bt.placeholder, size: 22),
      ]),
    );
  }
}
class _TxCard extends StatelessWidget {
  const _TxCard({required this.tx});
  final Map<String, dynamic> tx;
  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
  @override
  Widget build(BuildContext context) {
    final title = tx['title']?.toString() ?? 'Untitled';
    final type = tx['type']?.toString() ?? '';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final approvalStatus = tx['approvalStatus']?.toString() ?? 'Pending';
    final createdByName =
        (tx['createdBy'] is Map ? tx['createdBy']['name'] : null)?.toString() ??
        'Unknown';
    final projectName =
        (tx['project'] is Map ? tx['project']['projectName'] : null)
            ?.toString() ??
        'No Project';
    String dateStr = '';
    final rawDate = tx['date'] ?? tx['createdAt'];
    if (rawDate != null) {
      try {
        final d = DateTime.parse(rawDate.toString()).toLocal();
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
        dateStr = '${d.day} ${months[d.month - 1]}';
      } catch (_) {}
    }
    IconData icon;
    Color iconColor;
    switch (type.toLowerCase()) {
      case 'wages':
        icon = Icons.people_outlined;
        iconColor = Bt.green;
        break;
      case 'expense':
        icon = Icons.precision_manufacturing_outlined;
        iconColor = Bt.amber;
        break;
      default:
        icon = Icons.category_outlined;
        iconColor = Bt.ink;
    }
    return BtRow(
      leading: BtTile(icon: icon, fg: iconColor),
      title: title,
      subtitle: '$createdByName · $projectName${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
      minHeight: 64,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_fmt(amount), style: BtText.num(BtText.body(context, weight: FontWeight.w600))),
          const SizedBox(height: 4),
          BtBadge(label: approvalStatus, tone: BtBadge.toneFor(approvalStatus)),
        ],
      ),
    );
  }
}
