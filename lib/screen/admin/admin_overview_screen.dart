import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
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
        setState(() {
          _users = raw.map((u) => Map<String, dynamic>.from(u as Map)).toList();
          _loadingUsers = false;
        });
      } else {
        setState(() {
          _usersError = 'Failed to load users (${response.statusCode})';
          _loadingUsers = false;
        });
      }
    } catch (e) {
      setState(() {
        _usersError = 'Network error: $e';
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
        setState(() {
          _transactions = raw
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList();
          _loadingTx = false;
        });
      } else {
        setState(() {
          _txError = 'Failed to load entries (${response.statusCode})';
          _loadingTx = false;
        });
      }
    } catch (e) {
      setState(() {
        _txError = 'Network error: $e';
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
    return Scaffold(
      backgroundColor: Bt.ground,
      appBar: BtNavBar(
        title: 'Team & activity',
        trailing: RoleManager.canAssignRole
            ? BtIconButton(
                icon: Icons.add_rounded,
                semantic: 'Add team member',
                onTap: () => Navigator.pushNamed(context, '/assign-role').then((_) => _loadUsers()),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AnimatedBuilder(
              animation: _tabCtrl,
              builder: (context, _) => BtSegmented<int>(
                segments: {0: 'People (${_users.length})', 1: 'All entries (${_transactions.length})'},
                value: _tabCtrl.index,
                onChanged: (i) => _tabCtrl.animateTo(i),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildUsersTab(), _buildTransactionsTab()],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 3));
    }
    if (_usersError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topCenter, child: BtErrorCard(message: _usersError!, onRetry: _loadUsers)),
      );
    }
    if (_users.isEmpty) {
      return const BtEmpty(icon: Icons.group_outlined, title: 'No team members yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          BtGroup(
            children: [
              for (final u in _users)
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
        ],
      ),
    );
  }
  Widget _buildTransactionsTab() {
    if (_loadingTx) {
      return const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 5));
    }
    if (_txError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topCenter, child: BtErrorCard(message: _txError!, onRetry: _loadTransactions)),
      );
    }
    if (_transactions.isEmpty) {
      return const BtEmpty(icon: Icons.receipt_long_outlined, title: 'No entries yet.');
    }
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          BtGroup(children: [for (final t in _transactions) _TxCard(tx: t)]),
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
        iconColor = const Color(0xFF067647);
        break;
      case 'expense':
        icon = Icons.precision_manufacturing_outlined;
        iconColor = const Color(0xFFB54708);
        break;
      default:
        icon = Icons.category_outlined;
        iconColor = AppColors.primary;
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
