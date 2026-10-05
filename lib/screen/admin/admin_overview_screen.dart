import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
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
        backgroundColor: AppColors.gradientStart,
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: 'Team & Activity Overview',
                isSubScreen: true,
                leftIcon: Icons.arrow_back,
                onLeftTap: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Admin Access Only',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This screen is only accessible to Admins.\nContact your administrator for access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: () => Navigator.maybePop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            'Go Back',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Team & Activity Overview',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E5FF)),
              ),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Team (${_users.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'All Entries (${_transactions.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
      ),
    );
  }
  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_usersError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _usersError!,
              style: const TextStyle(color: AppColors.textLight),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          'No team members yet.',
          style: AppTheme.body.copyWith(color: AppColors.textLight),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _UserCard(
          user: _users[i],
          onEdit: () => Navigator.pushNamed(
            context,
            '/assign-role',
            arguments: {'editUser': _users[i]},
          ).then((_) => _loadUsers()),
        ),
      ),
    );
  }
  Widget _buildTransactionsTab() {
    if (_loadingTx) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_txError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_txError!, style: const TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No entries yet.',
          style: AppTheme.body.copyWith(color: AppColors.textLight),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _TxCard(tx: _transactions[i]),
      ),
    );
  }
}
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, this.onEdit});
  final Map<String, dynamic> user;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Unknown';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'Mason';
    final permissions = (user['permissions'] as List?)?.cast<String>() ?? [];
    final projectIds = (user['projectIds'] as List?)?.cast<String>() ?? [];
    final isAdminUser = role.toLowerCase() == 'admin';
    Color roleColor;
    Color roleBg;
    switch (role.toLowerCase()) {
      case 'admin':
        roleColor = AppColors.primary;
        roleBg = AppColors.primarySurface;
        break;
      case 'supervisor':
        roleColor = const Color(0xFF059669);
        roleBg = const Color(0xFFD1FAE5);
        break;
      default:
        roleColor = const Color(0xFFD97706);
        roleBg = const Color(0xFFFEF3C7);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isAdminUser && onEdit != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (permissions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...permissions
                    .take(5)
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                if (permissions.length > 5)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${permissions.length - 5} more',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (projectIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${projectIds.length} project${projectIds.length > 1 ? "s" : ""} assigned',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
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
    Color statusColor;
    Color statusBg;
    switch (approvalStatus.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFD1FAE5);
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusBg = const Color(0xFFFFEEEE);
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
    }
    IconData icon;
    Color iconColor;
    switch (type.toLowerCase()) {
      case 'wages':
        icon = Icons.people_outlined;
        iconColor = const Color(0xFF2E7D32);
        break;
      case 'expense':
        icon = Icons.precision_manufacturing_outlined;
        iconColor = const Color(0xFFE65100);
        break;
      default:
        icon = Icons.category_outlined;
        iconColor = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$createdByName · $projectName${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  approvalStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
