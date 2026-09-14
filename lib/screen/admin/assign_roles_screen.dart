import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:buildtrack_mobile/common/widgets/common_widgets.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
class AssignRolesScreen extends StatefulWidget {
  const AssignRolesScreen({super.key});
  @override
  State<AssignRolesScreen> createState() => _AssignRolesScreenState();
}
class _AssignRolesScreenState extends State<AssignRolesScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _customRoleCtrl = TextEditingController();
  static const List<Map<String, dynamic>> _featureRows = [
    {'section': 'Project'},
    {
      'type': 'table',
      'label': 'Project Status',
      'desc': 'View progress, budget, and project details',
      'view': 'view_assigned_project',
      'edit': 'edit_project',
      'delete': null,
    },
    {
      'type': 'table',
      'label': 'Activities & Entries',
      'desc': 'View, edit or delete material/labour/equipment entries',
      'view': 'view_assigned_project',
      'edit': 'manage_expenses',
      'delete': 'delete_entry',
    },
    {'section': 'Daily Work'},
    {
      'type': 'toggle',
      'label': 'Add Entries',
      'desc': 'Can add material, labour, and equipment entries',
      'key': 'manage_expenses',
    },
    {
      'type': 'toggle',
      'label': 'Add Equipment Entries',
      'desc': 'Can specifically add and manage equipment entries',
      'key': 'manage_equipment_master',
    },
    {
      'type': 'toggle',
      'label': 'Submit Daily Progress Update',
      'desc': 'Can file a daily update with photos and checklist',
      'key': 'submit_daily_update',
    },
    {'section': 'Approvals & Payments'},
    {
      'type': 'toggle',
      'label': 'Approve Payments',
      'desc': 'Can mark entries as paid and record payment details',
      'key': 'approve_payments',
    },
    {
      'type': 'toggle',
      'label': 'Approve Updates',
      'desc': 'Can approve or reject daily progress submissions',
      'key': 'approve_updates',
    },
    {'section': 'Visibility'},
    {
      'type': 'table',
      'label': 'Reports & Analytics',
      'desc': 'Access to charts, cost summaries and analytics',
      'view': 'view_reports',
      'edit': null,
      'delete': null,
    },
    {
      'type': 'table',
      'label': 'Transaction Logs',
      'desc': 'Access to the full list of expense entries',
      'view': 'view_payment_reports',
      'edit': null,
      'delete': null,
    },
    {'section': 'Administration'},
    {
      'type': 'table',
      'label': 'Assign Roles',
      'desc': 'Can create accounts and assign roles to team members',
      'view': null,
      'edit': 'assign_roles',
      'delete': null,
    },
  ];
  final Map<String, bool> _permissions = {
    'view_assigned_project': false,
    'edit_project': false,
    'delete_entry': false,
    'manage_expenses': false,
    'manage_equipment_master': false,
    'submit_daily_update': false,
    'approve_payments': false,
    'approve_updates': false,
    'view_reports': false,
    'view_payment_reports': false,
    'assign_roles': false,
  };
  bool _obscurePass = true;
  String? _selectedRole;
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _editingUserId;
  final Set<String> _selectedProjectIds = {};
  List<Map<String, String>> _projects = [];
  bool _isLoadingProjects = true;
  String? _projectsError;
  final Set<String> _selectedOverseesRoles = {};
  static const _availableRolesToOversee = ['Mason', 'Contractor', 'Labourer'];
  final _customOverseesRoleCtrl = TextEditingController();
  static const _customRoleValue = '__custom_role__';
  static const _roles = ['Supervisor', 'Mason', _customRoleValue];
  @override
  void initState() {
    super.initState();
    _fetchProjects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.hasSkippedTour && !UserSession.visitedModules.contains('AssignRolesScreen')) {
        ShowCaseWidget.of(context).startShowCase([
          ShowcaseKeys.assignRoleUserDetails,
          ShowcaseKeys.assignRoleRoleDropdown,
          ShowcaseKeys.assignRolePermissions,
          ShowcaseKeys.assignRoleProjectDropdown,
        ]);
        UserSession.markModuleVisited('AssignRolesScreen');
      }
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingUserId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('editUser')) {
      _prefillFromExistingUser(
        Map<String, dynamic>.from(args['editUser'] as Map),
      );
    }
  }
  void _prefillFromExistingUser(Map<String, dynamic> userData) {
    _isEditMode = true;
    _editingUserId = (userData['_id'] ?? userData['id'])?.toString();
    _nameCtrl.text = userData['name']?.toString() ?? '';
    _emailCtrl.text = userData['email']?.toString() ?? '';
    final role = userData['role']?.toString() ?? '';
    final isKnownRole = _roles.contains(role);
    if (isKnownRole) {
      _selectedRole = role;
    } else if (role.isNotEmpty) {
      _selectedRole = _customRoleValue;
      _customRoleCtrl.text = role;
    }
    final perms = (userData['permissions'] as List?)?.cast<String>() ?? [];
    for (final key in _permissions.keys) {
      _permissions[key] = perms.contains(key);
    }
    final overseesRoles =
        (userData['overseesRoles'] as List?)?.cast<String>() ?? [];
    _selectedOverseesRoles
      ..clear()
      ..addAll(overseesRoles);
    final projectIds = (userData['projectIds'] as List?)?.cast<String>() ?? [];
    _selectedProjectIds
      ..clear()
      ..addAll(projectIds);
    setState(() {});
  }
  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _customRoleCtrl.dispose();
    _customOverseesRoleCtrl.dispose();
    super.dispose();
  }
  bool get _isCustomRoleSelected => _selectedRole == _customRoleValue;
  Future<void> _fetchProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsError = null;
    });
    try {
      final response = await ApiService.get('/projects/mine');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> raw = [];
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map) {
          raw =
              (decoded['projects'] ??
                      decoded['data'] ??
                      decoded['items'] ??
                      decoded['results'] ??
                      [])
                  as List<dynamic>;
        }
        final parsed = raw
            .map<Map<String, String>>((p) {
              final map = Map<String, dynamic>.from(p as Map);
              final id = (map['_id'] ?? map['id'] ?? '').toString();
              final name =
                  (map['projectName'] ??
                          map['name'] ??
                          map['title'] ??
                          'Unnamed Project')
                      .toString()
                      .trim();
              return {
                'id': id,
                'name': name.isEmpty ? 'Unnamed Project' : name,
              };
            })
            .where((p) => p['id']!.isNotEmpty)
            .toList();
        setState(() {
          _projects = parsed;
          _isLoadingProjects = false;
        });
      } else {
        setState(() {
          _projectsError = 'Could not load projects (${response.statusCode})';
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsError = 'Network error loading projects';
        _isLoadingProjects = false;
      });
    }
  }
  void _applyDefaultPermissionsForRole(String? role) {
    if (role == null) return;
    for (final k in _permissions.keys) {
      _permissions[k] = false;
    }
    if (role == 'Supervisor') {
      for (final k in [
        'view_assigned_project',
        'manage_expenses',
        'manage_equipment_master',
        'submit_daily_update',
        'approve_payments',
        'approve_updates',
        'view_reports',
        'view_payment_reports',
      ]) {
        if (_permissions.containsKey(k)) _permissions[k] = true;
      }
    } else if (role == 'Mason') {
      for (final k in [
        'view_assigned_project',
        'manage_expenses',
        'submit_daily_update',
      ]) {
        if (_permissions.containsKey(k)) _permissions[k] = true;
      }
    }
    setState(() {
      _selectedRole = role;
      if (role != _customRoleValue) _customRoleCtrl.clear();
    });
  }
  Future<void> _onAssignPressed() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final roleToSend = _isCustomRoleSelected
        ? _customRoleCtrl.text.trim()
        : (_selectedRole ?? '').trim();
    if (name.isEmpty || email.isEmpty || roleToSend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all required fields and select a role.',
          ),
        ),
      );
      return;
    }
    if (!_isEditMode && pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a temporary password.')),
      );
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }
    final selectedPermissions = _permissions.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (!_isEditMode) {
      final subProvider = context.read<SubscriptionProvider>();
      final response = await ApiService.get('/auth/users');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List raw = decoded is List
            ? decoded
            : (decoded['users'] ?? decoded['data'] ?? []) as List;
        final currentUserCount = raw.length;
        final maxUsers = subProvider.currentPlan.maxUsers;
        if (maxUsers != -1 && currentUserCount >= maxUsers) {
          if (!mounted) return;
          _showUpgradeDialog(
            context,
            'Team Member Limit Reached',
            'Your ${subProvider.currentPlan.label} plan allows up to $maxUsers users. '
                'Upgrade to add more team members.',
          );
          return;
        }
      }
    }
    setState(() => _isLoading = true);
    try {
      if (_isEditMode && _editingUserId != null) {
        final payload = <String, dynamic>{
          'name': name,
          'email': email,
          'role': roleToSend,
          'permissions': selectedPermissions,
          if (_selectedProjectIds.isNotEmpty)
            'projectIds': _selectedProjectIds.toList(),
          'overseesRoles': _selectedOverseesRoles.toList(),
          if (pass.isNotEmpty) 'password': pass,
        };
        final response = await ApiService.put(
          '/auth/users/$_editingUserId',
          payload,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name updated successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        } else {
          final body = json.decode(response.body);
          final msg = body['message']?.toString() ?? 'Failed to update user.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      } else {
        final payload = <String, dynamic>{
          'name': name,
          'email': email,
          'temporaryPassword': pass,
          'role': roleToSend,
          'permissions': selectedPermissions,
          if (_selectedProjectIds.isNotEmpty)
            'projectIds': _selectedProjectIds.toList(),
          if (_selectedOverseesRoles.isNotEmpty)
            'overseesRoles': _selectedOverseesRoles.toList(),
        };
        final response = await ApiService.post('/auth/provision', payload);
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final projCount = _selectedProjectIds.length;
          final projLabel = projCount == 0
              ? 'all projects'
              : '$projCount project${projCount > 1 ? 's' : ''}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name assigned as $roleToSend ($projLabel).'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        } else {
          final body = json.decode(response.body);
          final msg = body['message']?.toString() ?? 'Failed to assign role.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final isAdmin = RoleManager.canAssignRole;
    final subProvider = context.watch<SubscriptionProvider>();
    final plan = subProvider.currentPlan;
    return ShowCaseWidget(
      globalTooltipActions: const [TooltipActionButton(type: TooltipDefaultActionType.skip, backgroundColor: Colors.transparent, textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), TooltipActionButton(type: TooltipDefaultActionType.next, backgroundColor: AppColors.primary, textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))], 
      enableAutoScroll: true,
      builder: (context) => Scaffold(
          backgroundColor: AppColors.gradientStart,
          body: SafeArea(
            bottom: false,
            child: Column(
          children: [
            AppTopBar(
              title: _isEditMode ? 'Edit User' : 'Assign Role',
              isSubScreen: true,
              leftIcon: Icons.arrow_back,
              onLeftTap: () => Navigator.maybePop(context),
              rightWidget: GestureDetector(
                onTap: () => ShowCaseWidget.of(context).startShowCase([
                  ShowcaseKeys.assignRoleUserDetails,
                  ShowcaseKeys.assignRoleRoleDropdown,
                  ShowcaseKeys.assignRolePermissions,
                  ShowcaseKeys.assignRoleProjectDropdown,
                ]),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _adminBadge(),
                    const SizedBox(height: 6),
                    Text(
                      'Only Admins can assign roles and manage team access.',
                      style: AppTheme.body.copyWith(color: AppColors.textLight),
                    ),
                    const SizedBox(height: 12),
                    _subscriptionWarning(plan),
                    const SizedBox(height: 20),
                    _formCard(isAdmin),
                    const SizedBox(height: 12),
                    if (isAdmin) _assignButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
  Widget _adminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: AppColors.primary, size: 13),
          const SizedBox(width: 6),
          Text(
            'Admin Access Only',
            style: AppTheme.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  Widget _subscriptionWarning(SubscriptionPlan plan) {
    final limitStr = plan == SubscriptionPlan.enterprise
        ? 'Unlimited'
        : '${plan.maxUsers} Users';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${plan.label} Plan: $limitStr limit.',
              style: AppTheme.body.copyWith(
                fontSize: 12,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _formCard(bool isAdmin) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Showcase(
            key: ShowcaseKeys.assignRoleUserDetails,
            description: 'Enter the user\'s full name and email address here.',
            tooltipBackgroundColor: const Color(0xFF1E1E2C),
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  hint: 'Enter full name',
                  prefixIcon: Icons.person_outline,
                  enabled: true,
                ),
                AppTextField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  hint: 'Enter email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: true,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode ? 'New Password (optional)' : 'Temporary Password',
                style: AppTheme.label.copyWith(color: AppTheme.textMedium),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                enabled: true,
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.textDark),
                decoration: InputDecoration(
                  hintText: 'Enter temporary password',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
            ],
          ),
          Showcase(
            key: ShowcaseKeys.assignRoleRoleDropdown,
            description: 'Select a standard role like Supervisor or Mason, or create a Custom Role.',
            tooltipBackgroundColor: const Color(0xFF1E1E2C),
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: AppDropdownField<String>(
              label: 'Role',
              value: _selectedRole,
              hint: 'Select role',
              items: _roles
                  .map(
                    (r) => DropdownMenuItem<String>(
                      value: r,
                      child: Text(r == _customRoleValue ? 'Custom Role' : r),
                    ),
                  )
                  .toList(),
              onChanged: isAdmin
                  ? (v) => _applyDefaultPermissionsForRole(v)
                  : (_) {},
            ),
          ),
          if (_isCustomRoleSelected) ...[
            const SizedBox(height: AppTheme.spacingMd),
            AppTextField(
              label: 'Custom Role Name',
              controller: _customRoleCtrl,
              hint: 'Type new role name',
              prefixIcon: Icons.badge_outlined,
              enabled: isAdmin,
            ),
          ],
          if (_selectedRole == 'Supervisor' || _isCustomRoleSelected) ...[
            const SizedBox(height: AppTheme.spacingMd),
            _buildOverseesRolesSelector(),
          ],
          _roleHints(),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Permissions',
            style: AppTheme.heading3.copyWith(
              color: AppColors.textDark,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure what this user can see and do.',
            style: AppTheme.caption.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 14),
          Showcase(
            key: ShowcaseKeys.assignRolePermissions,
            description: 'Configure exact permissions for what this user can see or modify in the app.',
            tooltipBackgroundColor: const Color(0xFF1E1E2C),
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: _buildPermissionsTable(isAdmin),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Showcase(
            key: ShowcaseKeys.assignRoleProjectDropdown,
            description: 'Select one or more projects this role can access. Leave empty for all.',
            tooltipBackgroundColor: const Color(0xFF1E1E2C),
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: _buildProjectMultiSelect(isAdmin),
          ),
        ],
      ),
    );
  }
  Widget _buildPermissionsTable(bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E5FF)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLight,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                _colHeader('View'),
                _colHeader('Edit'),
                _colHeader('Delete'),
              ],
            ),
          ),
          ..._featureRows.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;
            if (row.containsKey('section')) {
              return _sectionDivider(row['section'] as String);
            }
            final type = row['type'] as String;
            final label = row['label'] as String;
            final desc = row['desc'] as String;
            final isLast = idx == _featureRows.length - 1;
            if (type == 'table') {
              final viewKey = row['view'] as String?;
              final editKey = row['edit'] as String?;
              final deleteKey = row['delete'] as String?;
              return _tableRow(
                label: label,
                desc: desc,
                viewKey: viewKey,
                editKey: editKey,
                deleteKey: deleteKey,
                isLast: isLast,
                isAdmin: isAdmin,
              );
            } else {
              final key = row['key'] as String;
              return _toggleRow(
                label: label,
                desc: desc,
                permKey: key,
                isLast: isLast,
                isAdmin: isAdmin,
              );
            }
          }),
        ],
      ),
    );
  }
  Widget _colHeader(String label) {
    return SizedBox(
      width: 52,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  Widget _sectionDivider(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      color: const Color(0xFFF8F9FF),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
  Widget _tableRow({
    required String label,
    required String desc,
    required String? viewKey,
    required String? editKey,
    required String? deleteKey,
    required bool isLast,
    required bool isAdmin,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _permCheckbox(viewKey, isAdmin),
              _permCheckbox(editKey, isAdmin),
              _permCheckbox(deleteKey, isAdmin),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF0EEF8)),
      ],
    );
  }
  Widget _toggleRow({
    required String label,
    required String desc,
    required String permKey,
    required bool isLast,
    required bool isAdmin,
  }) {
    final enabled = _permissions[permKey] ?? false;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.primary,
                onChanged: isAdmin
                    ? (v) => setState(() => _permissions[permKey] = v)
                    : null,
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF0EEF8)),
      ],
    );
  }
  Widget _permCheckbox(String? key, bool isAdmin) {
    if (key == null) {
      return const SizedBox(
        width: 52,
        child: Center(
          child: Text(
            '—',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final value = _permissions[key] ?? false;
    return SizedBox(
      width: 52,
      child: Checkbox(
        value: value,
        activeColor: AppColors.primary,
        side: const BorderSide(color: AppColors.textLight, width: 1.5),
        onChanged: isAdmin
            ? (v) => setState(() => _permissions[key] = v ?? false)
            : null,
      ),
    );
  }
  Widget _buildProjectMultiSelect(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Project Access',
              style: AppTheme.heading3.copyWith(
                color: AppColors.textDark,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(Optional)',
              style: AppTheme.caption.copyWith(color: AppColors.textLight),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select one or more projects. Leave all unchecked for org-wide access.',
          style: AppTheme.caption.copyWith(color: AppColors.textLight),
        ),
        const SizedBox(height: 10),
        if (_isLoadingProjects)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
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
                Text(
                  'Loading projects…',
                  style: AppTheme.body.copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          )
        else if (_projectsError != null && _projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _projectsError!,
                    style: AppTheme.caption.copyWith(color: AppColors.warning),
                  ),
                ),
                TextButton(
                  onPressed: _fetchProjects,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_projects.isEmpty)
          Text(
            'No projects found.',
            style: AppTheme.caption.copyWith(color: AppColors.textLight),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: _projects.asMap().entries.map((entry) {
                final idx = entry.key;
                final project = entry.value;
                final pid = project['id']!;
                final checked = _selectedProjectIds.contains(pid);
                final isLast = idx == _projects.length - 1;
                return Column(
                  children: [
                    CheckboxListTile(
                      value: checked,
                      onChanged: isAdmin
                          ? (value) => setState(() {
                              if (value == true) {
                                _selectedProjectIds.add(pid);
                              } else {
                                _selectedProjectIds.remove(pid);
                              }
                            })
                          : null,
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      dense: true,
                      title: Text(
                        project['name']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: checked
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: checked
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        if (_selectedProjectIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedProjectIds.length} project${_selectedProjectIds.length > 1 ? 's' : ''} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedProjectIds.clear()),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppTheme.spacingMd),
      ],
    );
  }
  Widget _roleHints() {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gradientStart,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roleHintRow(
            'Supervisor',
            'Approve updates, view reports, manage expenses',
          ),
          const SizedBox(height: 4),
          _roleHintRow('Mason', 'Submit updates, upload photos, report issues'),
          const SizedBox(height: 4),
          _roleHintRow(
            'Custom Role',
            'Pick a name and configure permissions manually',
          ),
        ],
      ),
    );
  }
  Widget _roleHintRow(String role, String desc) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12.5, height: 1.4),
        children: [
          TextSpan(
            text: '• ',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: '$role: ',
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: desc,
            style: const TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
  Widget _assignButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _onAssignPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      _isEditMode ? 'Update User' : 'Assign Role',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  void _showUpgradeDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A6CF7), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/subscription');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Plans',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Maybe Later',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildOverseesRolesSelector() {
    final customAdded = _selectedOverseesRoles
        .where((r) => !_availableRolesToOversee.contains(r))
        .toList();
    final allRoles = [..._availableRolesToOversee, ...customAdded];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roles to Oversee',
          style: AppTheme.heading3.copyWith(
            color: AppColors.textDark,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the roles this user can approve entries for. You can also add a custom role below.',
          style: AppTheme.caption.copyWith(color: AppColors.textLight),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allRoles.map((role) {
            final isSelected = _selectedOverseesRoles.contains(role);
            final isCustom = !_availableRolesToOversee.contains(role);
            return FilterChip(
              label: Text(role),
              selected: isSelected,
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              deleteIcon: isCustom ? const Icon(Icons.close, size: 16) : null,
              onDeleted: isCustom
                  ? () => setState(() => _selectedOverseesRoles.remove(role))
                  : null,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _selectedOverseesRoles.add(role);
                  } else {
                    _selectedOverseesRoles.remove(role);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customOverseesRoleCtrl,
                decoration: InputDecoration(
                  hintText: 'Add a custom role to oversee',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _addCustomOverseesRole(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addCustomOverseesRole,
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              tooltip: 'Add role',
            ),
          ],
        ),
      ],
    );
  }
  void _addCustomOverseesRole() {
    final value = _customOverseesRoleCtrl.text.trim();
    if (value.isEmpty) return;
    final alreadyExists = _selectedOverseesRoles.any(
      (r) => r.toLowerCase() == value.toLowerCase(),
    );
    if (alreadyExists) {
      _customOverseesRoleCtrl.clear();
      return;
    }
    setState(() {
      _selectedOverseesRoles.add(value);
      _customOverseesRoleCtrl.clear();
    });
  }
}
