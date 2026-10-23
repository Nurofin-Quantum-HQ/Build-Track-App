import 'package:buildtrack_mobile/common/widgets/entry_widgets.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'dart:convert';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
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
      'desc': 'View progress and project details',
      'view': 'view_assigned_project',
      'edit': 'edit_project',
      'delete': null,
    },
    {
      'type': 'toggle',
      'label': 'Project budget',
      'desc': 'See budgets, budget used and remaining',
      'key': RoleManager.viewProjectBudgetKey,
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
    {
      'type': 'toggle',
      'label': 'Assign Tasks',
      'desc': 'Can give work to team members (e.g. pre-construction)',
      'key': RoleManager.assignTasksKey,
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
    // Off by default for every preset (Supervisor / Mason / custom); an Admin
    // turns it on per person. Read by RoleManager.canViewProjectBudget.
    RoleManager.viewProjectBudgetKey: false,
    'delete_entry': false,
    'manage_expenses': false,
    'manage_equipment_master': false,
    'submit_daily_update': false,
    RoleManager.assignTasksKey: false,
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
        RoleManager.assignTasksKey,
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
            SnackBar(content: Text(msg), backgroundColor: const Color(0xFFC01048)),
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
            SnackBar(content: Text(msg), backgroundColor: const Color(0xFFC01048)),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFC01048)),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final isAdmin = RoleManager.canAssignRole;
    final subProvider = context.watch<SubscriptionProvider>();
    final plan = subProvider.currentPlan;
    return ShowCaseWidget(
      globalTooltipActions: [TooltipActionButton(type: TooltipDefaultActionType.skip, backgroundColor: Colors.transparent, textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), TooltipActionButton(type: TooltipDefaultActionType.next, backgroundColor: AppColors.primary, textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))], 
      enableAutoScroll: true,
      builder: (context) => Scaffold(
        backgroundColor: Bt.ground,
        appBar: BtNavBar(
          title: _isEditMode ? 'Edit user' : 'Add team member',
          close: true,
          trailing: BtIconButton(
            icon: Icons.help_outline_rounded,
            semantic: 'Help',
            color: Bt.ink2,
            onTap: () => ShowCaseWidget.of(context).startShowCase([
              ShowcaseKeys.assignRoleUserDetails,
              ShowcaseKeys.assignRoleRoleDropdown,
              ShowcaseKeys.assignRolePermissions,
              ShowcaseKeys.assignRoleProjectDropdown,
            ]),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            BtReveal(child: _subscriptionWarning(plan)),
            const SizedBox(height: 16),
            _formCard(isAdmin),
          ],
        ),
        bottomNavigationBar: isAdmin ? BtCtaBar(children: [Expanded(child: _assignButton())]) : null,
      ),
    );
  }
  Widget _subscriptionWarning(SubscriptionPlan plan) {
    final limitStr = plan == SubscriptionPlan.enterprise
        ? 'Unlimited'
        : '${plan.maxUsers} Users';
    final bt = context.bt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(color: bt.accentSoft, borderRadius: BorderRadius.circular(Bt.rTile)),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: bt.accentInk, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Admins only · ${plan.label} plan: $limitStr limit.',
              style: BtText.subhead(context, color: Bt.ink),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/subscription'),
            style: TextButton.styleFrom(foregroundColor: bt.accentInk, minimumSize: const Size(44, 40)),
            child: Text('Upgrade', style: BtText.subhead(context, weight: FontWeight.w700, color: bt.accentInk)),
          ),
        ],
      ),
    );
  }
  Widget _inlineField(String label, TextEditingController c, String hint, {TextInputType? type, bool obscure = false, Widget? suffix}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(children: [
          SizedBox(width: 112, child: Text(label, style: BtText.subhead(context))),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: type,
              obscureText: obscure,
              style: BtText.body(context),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: BtText.body(context, color: Bt.placeholder),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (suffix != null) suffix else const SizedBox(width: 12),
        ]),
      ),
    );
  }

  static const _roleTitles = {'Supervisor': 'Supervisor', 'Mason': 'Mason', _customRoleValue: 'Custom role…'};
  static const _roleDescs = {
    'Supervisor': 'Approve updates, view reports, manage expenses',
    'Mason': 'Submit updates, upload photos, report issues',
    _customRoleValue: 'Pick a name and configure permissions manually',
  };

  Widget _roleChip(String value, bool isAdmin) {
    final selected = _selectedRole == value;
    return Semantics(
      selected: selected,
      button: true,
      child: _SelectChip(
        label: _roleTitles[value]!,
        selected: selected,
        large: true,
        onTap: isAdmin ? () => _applyDefaultPermissionsForRole(value) : null,
      ),
    );
  }

  Widget _label(String text, {String? caption}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text.toUpperCase(), style: BtText.mono(context)),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption, style: BtText.caption(context)),
          ],
        ]),
      );

  Widget _formCard(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BtReveal(
          index: 1,
          child: Showcase(
            key: ShowcaseKeys.assignRoleUserDetails,
            description: 'Enter the user\'s full name and email address here.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: BtGroup(
              children: [
                _inlineField('Full name', _nameCtrl, 'Enter full name'),
                _inlineField('Email', _emailCtrl, 'Enter email address', type: TextInputType.emailAddress),
                _inlineField(
                  _isEditMode ? 'New password' : 'Temp password',
                  _passCtrl,
                  _isEditMode ? 'Optional' : 'Enter temporary password',
                  obscure: _obscurePass,
                  suffix: IconButton(
                    tooltip: _obscurePass ? 'Show password' : 'Hide password',
                    icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Bt.ink2, size: 20),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        BtReveal(
          index: 2,
          child: Showcase(
            key: ShowcaseKeys.assignRoleRoleDropdown,
            description: 'Select a standard role like Supervisor or Mason, or create a Custom Role.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Role · sets sensible permissions'),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final r in _roles) _roleChip(r, isAdmin)]),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: Bt.fast,
                  child: Padding(
                    key: ValueKey(_selectedRole),
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      _selectedRole == null ? 'Choose a role to start with its usual permissions.' : _roleDescs[_selectedRole] ?? '',
                      style: BtText.caption(context, color: Bt.ink2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Bt.medium,
          curve: Bt.ease,
          alignment: Alignment.topCenter,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_isCustomRoleSelected) ...[
              const SizedBox(height: 16),
              EntryLabeled(
                label: 'Custom role name',
                child: TextField(
                  controller: _customRoleCtrl,
                  enabled: isAdmin,
                  style: BtText.body(context),
                  decoration: btInput(context, hint: 'Type new role name'),
                ),
              ),
            ],
            if (_selectedRole == 'Supervisor' || _isCustomRoleSelected) ...[
              const SizedBox(height: 24),
              _buildOverseesRolesSelector(),
            ],
          ]),
        ),
        const SizedBox(height: 28),
        BtReveal(
          index: 3,
          child: Showcase(
            key: ShowcaseKeys.assignRoleProjectDropdown,
            description: 'Select one or more projects this role can access. Leave empty for all.',
            tooltipBackgroundColor: Bt.ink,
            textColor: Colors.white,
            tooltipBorderRadius: BorderRadius.circular(16),
            tooltipPadding: const EdgeInsets.all(16),
            child: _buildProjectMultiSelect(isAdmin),
          ),
        ),
        const SizedBox(height: 28),
        BtReveal(
          index: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _label('Permissions', caption: 'Configure what this user can see and do.'),
            Showcase(
              key: ShowcaseKeys.assignRolePermissions,
              description: 'Configure exact permissions for what this user can see or modify in the app.',
              tooltipBackgroundColor: Bt.ink,
              textColor: Colors.white,
              tooltipBorderRadius: BorderRadius.circular(16),
              tooltipPadding: const EdgeInsets.all(16),
              child: _buildPermissionsTable(isAdmin),
            ),
          ]),
        ),
      ],
    );
  }

  /// Sections the user has opened in the permissions list.
  final Set<String> _openSections = {};

  /// `_featureRows` split into (section, rows).
  List<MapEntry<String, List<Map<String, dynamic>>>> get _permissionSections {
    final out = <MapEntry<String, List<Map<String, dynamic>>>>[];
    for (final row in _featureRows) {
      if (row.containsKey('section')) {
        out.add(MapEntry(row['section'] as String, []));
      } else if (out.isNotEmpty) {
        out.last.value.add(row);
      }
    }
    return out;
  }

  Widget _buildPermissionsTable(bool isAdmin) {
    final bt = context.bt;
    final sections = _permissionSections;
    return BtCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var si = 0; si < sections.length; si++) ...[
            if (si > 0) const Divider(height: 1, color: Bt.line),
            Builder(builder: (context) {
              final name = sections[si].key;
              final rows = sections[si].value;
              final keys = <String>{
                for (final r in rows)
                  if (r['type'] == 'table') ...[
                    if (r['view'] != null) r['view'] as String,
                    if (r['edit'] != null) r['edit'] as String,
                    if (r['delete'] != null) r['delete'] as String,
                  ] else
                    r['key'] as String,
              };
              final on = keys.where((k) => _permissions[k] ?? false).length;
              final open = _openSections.contains(name);
              return AnimatedContainer(
                duration: Bt.fast,
                color: open ? bt.accent.withValues(alpha: .07) : Colors.transparent,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  InkWell(
                    onTap: () => setState(() => open ? _openSections.remove(name) : _openSections.add(name)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: BtText.body(context, weight: FontWeight.w600)),
                              Text('$on of ${keys.length} on', style: BtText.num(BtText.caption(context, color: on > 0 ? bt.accentInk : Bt.ink3))),
                            ]),
                          ),
                          AnimatedRotation(
                            turns: open ? .5 : 0,
                            duration: Bt.fast,
                            curve: Bt.ease,
                            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Bt.ink3),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: Bt.medium,
                    curve: Bt.ease,
                    alignment: Alignment.topCenter,
                    child: !open
                        ? const SizedBox(width: double.infinity)
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (final row in rows)
                              row['type'] == 'table'
                                  ? _tableRow(
                                      label: row['label'] as String,
                                      desc: row['desc'] as String,
                                      viewKey: row['view'] as String?,
                                      editKey: row['edit'] as String?,
                                      deleteKey: row['delete'] as String?,
                                      isLast: false,
                                      isAdmin: isAdmin,
                                    )
                                  : _toggleRow(
                                      label: row['label'] as String,
                                      desc: row['desc'] as String,
                                      permKey: row['key'] as String,
                                      isLast: false,
                                      isAdmin: isAdmin,
                                    ),
                            const SizedBox(height: 6),
                          ]),
                  ),
                ]),
              );
            }),
          ],
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
          const SizedBox(height: 1),
          Text(desc, style: BtText.caption(context)),
          const SizedBox(height: 8),
          Row(children: [
            _permCheckbox(viewKey, isAdmin, label: 'View'),
            const SizedBox(width: 8),
            _permCheckbox(editKey, isAdmin, label: 'Edit'),
            const SizedBox(width: 8),
            _permCheckbox(deleteKey, isAdmin, label: 'Delete'),
          ]),
        ],
      ),
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
    return InkWell(
      onTap: isAdmin ? () => setState(() => _permissions[permKey] = !enabled) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                  const SizedBox(height: 1),
                  Text(desc, style: BtText.caption(context)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CheckBox(
              value: enabled,
              semantic: label,
              onChanged: isAdmin ? (v) => setState(() => _permissions[permKey] = v) : null,
            ),
          ],
        ),
      ),
    );
  }
  Widget _permCheckbox(String? key, bool isAdmin, {required String label}) {
    if (key == null) {
      return Expanded(
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Bt.rChip), border: Border.all(color: Bt.line)),
          child: Text('$label —', style: BtText.caption(context, color: Bt.placeholder)),
        ),
      );
    }
    final value = _permissions[key] ?? false;
    final bt = context.bt;
    return Expanded(
      child: Semantics(
        checked: value,
        label: label,
        child: BtPressable(
          onTap: isAdmin ? () => setState(() => _permissions[key] = !value) : null,
          scale: .95,
          child: AnimatedContainer(
            duration: Bt.fast,
            curve: Bt.ease,
            height: 40,
            decoration: BoxDecoration(
              color: value ? bt.accentSoft : Bt.card,
              borderRadius: BorderRadius.circular(Bt.rChip),
              border: Border.all(color: value ? bt.accent : Bt.inputBorder, width: value ? 1.5 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _CheckBox(value: value, size: 18, onChanged: null),
              const SizedBox(width: 6),
              Text(label, style: BtText.caption(context, color: value ? bt.accentInk : Bt.ink2, weight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
  Widget _buildProjectMultiSelect(bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PROJECT ACCESS · OPTIONAL', style: BtText.mono(context)),
            const SizedBox(height: 4),
            Text('Select one or more projects. Leave all unchecked for org-wide access.', style: BtText.caption(context)),
          ]),
        ),
        if (_isLoadingProjects)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Bt.ink),
                ),
                const SizedBox(width: 10),
                Text('Loading projects…', style: BtText.subhead(context)),
              ],
            ),
          )
        else if (_projectsError != null && _projects.isEmpty)
          BtCard(
            variant: BtCardVariant.notice,
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Bt.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_projectsError!, style: BtText.caption(context, color: Bt.amber, weight: FontWeight.w500))),
                TextButton(
                  onPressed: _fetchProjects,
                  style: TextButton.styleFrom(foregroundColor: Bt.ink, minimumSize: const Size(44, 40)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_projects.isEmpty)
          Text('No projects found.', style: BtText.caption(context))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final project in _projects)
                Semantics(
                  checked: _selectedProjectIds.contains(project['id']),
                  child: _SelectChip(
                    label: project['name']!,
                    selected: _selectedProjectIds.contains(project['id']),
                    showCheck: true,
                    onTap: isAdmin
                        ? () => setState(() {
                              final pid = project['id']!;
                              if (_selectedProjectIds.contains(pid)) {
                                _selectedProjectIds.remove(pid);
                              } else {
                                _selectedProjectIds.add(pid);
                              }
                            })
                        : null,
                  ),
                ),
            ],
          ),
        AnimatedSize(
          duration: Bt.fast,
          curve: Bt.ease,
          alignment: Alignment.topLeft,
          child: _selectedProjectIds.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      BtBadge(
                        label: '${_selectedProjectIds.length} project${_selectedProjectIds.length > 1 ? 's' : ''} selected',
                        tone: BtTone.brand,
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => setState(() => _selectedProjectIds.clear()),
                        style: TextButton.styleFrom(foregroundColor: Bt.ink2, minimumSize: const Size(44, 36)),
                        child: Text('Clear', style: BtText.caption(context, color: Bt.ink2, weight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
  Widget _assignButton() {
    return BtButton(
      label: _isEditMode ? 'Update User' : 'Assign Role',
      icon: Icons.person_add_outlined,
      loading: _isLoading,
      onPressed: _isLoading ? null : _onAssignPressed,
    );
  }
  void _showUpgradeDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierColor: Bt.scrim,
      builder: (ctx) {
        final bt = ctx.bt;
        return AlertDialog(
          backgroundColor: Bt.card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: Bt.noir, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.auto_awesome_rounded, color: bt.accent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: BtText.d3(ctx)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: BtText.subhead(ctx)),
              const SizedBox(height: 24),
              BtButton(
                label: 'View Plans',
                variant: BtButtonVariant.accent,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/subscription');
                },
              ),
              const SizedBox(height: 6),
              BtButton(
                label: 'Maybe Later',
                variant: BtButtonVariant.quiet,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildOverseesRolesSelector() {
    final customAdded = _selectedOverseesRoles
        .where((r) => !_availableRolesToOversee.contains(r))
        .toList();
    final allRoles = [..._availableRolesToOversee, ...customAdded];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Roles to oversee', caption: 'Select the roles this user can approve entries for. You can also add a custom role below.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allRoles.map((role) {
            final isSelected = _selectedOverseesRoles.contains(role);
            final isCustom = !_availableRolesToOversee.contains(role);
            return Semantics(
              selected: isSelected,
              child: _SelectChip(
                label: role,
                selected: isSelected,
                showCheck: true,
                onTap: () => setState(() {
                  if (!isSelected) {
                    _selectedOverseesRoles.add(role);
                  } else {
                    _selectedOverseesRoles.remove(role);
                  }
                }),
                onDelete: isCustom ? () => setState(() => _selectedOverseesRoles.remove(role)) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customOverseesRoleCtrl,
                style: BtText.body(context),
                decoration: btInput(context, hint: 'Add a custom role to oversee'),
                onSubmitted: (_) => _addCustomOverseesRole(),
              ),
            ),
            const SizedBox(width: 8),
            BtIconButton(
              icon: Icons.add_rounded,
              semantic: 'Add role',
              filled: true,
              onTap: _addCustomOverseesRole,
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

/// Ink-when-selected chip used for roles, projects and roles-to-oversee.
class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.selected, this.onTap, this.onDelete, this.showCheck = false, this.large = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showCheck;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final fg = selected ? Bt.bone : Bt.ink;
    return Opacity(
      opacity: onTap == null && !selected ? .55 : 1,
      child: BtPressable(
        onTap: onTap,
        scale: .95,
        child: AnimatedContainer(
          duration: Bt.fast,
          curve: Bt.ease,
          constraints: BoxConstraints(minHeight: large ? 44 : 38),
          padding: EdgeInsets.only(left: large ? 16 : 13, right: onDelete != null ? 4 : (large ? 16 : 13)),
          decoration: BoxDecoration(
            color: selected ? Bt.ink : Bt.card,
            borderRadius: BorderRadius.circular(large ? 14 : Bt.rChip),
            border: selected ? null : Border.all(color: Bt.inputBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSize(
              duration: Bt.fast,
              curve: Bt.ease,
              child: showCheck && selected
                  ? Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_rounded, size: 16, color: context.bt.accent))
                  : const SizedBox.shrink(),
            ),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, weight: FontWeight.w500, color: fg).copyWith(fontSize: large ? 15 : 14))),
            if (onDelete != null)
              Semantics(
                button: true,
                label: 'Remove $label',
                child: GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 16, color: fg)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Square accent checkbox (animated tick).
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.value, required this.onChanged, this.size = 24, this.semantic});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final String? semantic;
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final box = AnimatedContainer(
      duration: Bt.fast,
      curve: Bt.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value ? bt.accent : Bt.card,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: value ? bt.accent : Bt.inputBorder, width: 1.5),
      ),
      child: AnimatedScale(
        scale: value ? 1 : 0,
        duration: Bt.fast,
        curve: Bt.spring,
        child: Icon(Icons.check_rounded, size: size * .72, color: bt.onAccent),
      ),
    );
    if (onChanged == null) return box;
    return Semantics(
      checked: value,
      label: semantic,
      child: GestureDetector(
        onTap: () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(width: Bt.touch, height: Bt.touch, child: Center(child: box)),
      ),
    );
  }
}
