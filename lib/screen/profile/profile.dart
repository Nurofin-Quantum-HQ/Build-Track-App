import 'dart:convert';
import 'dart:typed_data';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/subscription_card.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/controller/inventory_provider.dart';
import 'package:buildtrack_mobile/controller/subscription_provider.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';
class ProfileUserData {
  const ProfileUserData({
    required this.name,
    required this.email,
    required this.role,
    this.profilePhoto,
    this.companyName = '',
    this.companyFontStyle = 'Inter',
    this.companyLogo,
  });
  final String name;
  final String email;
  final String role;
  final String? profilePhoto;
  final String companyName;
  final String companyFontStyle;
  final String? companyLogo;
  factory ProfileUserData.fromJson(Map<String, dynamic> json) {
    return ProfileUserData(
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Mason',
      profilePhoto: json['profilePhoto']?.toString(),
      companyName: json['companyName']?.toString() ?? '',
      companyFontStyle: json['companyFontStyle']?.toString() ?? 'Inter',
      companyLogo: json['companyLogo']?.toString(),
    );
  }
  static ProfileUserData get sessionFallback => ProfileUserData(
    name: UserSession.userId.isNotEmpty ? UserSession.userId : 'Guest User',
    email: '${UserSession.userId}@buildtrack.app',
    role: UserSession.roleLabel,
    companyName: UserSession.companyName,
    companyFontStyle: UserSession.companyFontStyle,
    companyLogo: UserSession.companyLogo,
  );
}
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  Uint8List? _avatarBytes;
  ProfileUserData? _user;
  bool _isLoadingProfile = true;
  String? _profileError;
  final GlobalKey _settingsCardKey = GlobalKey();
  final GlobalKey _teamAccessKey = GlobalKey();
  final GlobalKey _logoutKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadNotificationPrefs();
  }
  Future<void> _loadNotificationPrefs() async {
    final prefs = await ApiService.getNotificationPreferences();
    if (mounted && prefs.containsKey('push')) {
      setState(() => _notificationsEnabled = prefs['push'] == true);
    }
  }
  Future<void> _setNotificationsEnabled(bool val) async {
    setState(() => _notificationsEnabled = val);
    final ok = await ApiService.saveNotificationPreferences({'push': val});
    if (!ok && mounted) setState(() => _notificationsEnabled = !val);
  }
  Future<void> _fetchProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });
    try {
      final response = await ApiService.get('/users/profile');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final userJson = decoded['user'] ?? decoded;
        final data = ProfileUserData.fromJson(userJson as Map<String, dynamic>);
        UserSession.fromLoginResponse(Map<String, dynamic>.from(userJson));
        setState(() {
          _user = data;
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _user = ProfileUserData.sessionFallback;
          _profileError = 'Could not load profile (${response.statusCode})';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _user = ProfileUserData.sessionFallback;
        _profileError = 'Network error. Showing cached data.';
        _isLoadingProfile = false;
      });
    }
  }
  Future<void> _showImageOptions() async {
    final hasPhoto =
        _avatarBytes != null ||
        (_user?.profilePhoto != null && _user!.profilePhoto!.isNotEmpty);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFC01048)),
                title: const Text(
                  'Remove Profile Photo',
                  style: TextStyle(color: Color(0xFFC01048)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeProfilePhoto();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Future<void> _removeProfilePhoto() async {
    try {
      final response = await ApiService.put('/users/profile/photo', {
        'profilePhoto': 'delete',
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            backgroundColor: Color(0xFF067647),
          ),
        );
        final decoded = json.decode(response.body);
        final userJson = decoded['user'] ?? decoded;
        await UserSession.fromLoginResponse(
          Map<String, dynamic>.from(userJson),
        );
        setState(() {
          _avatarBytes = null;
          _user = ProfileUserData.fromJson(userJson as Map<String, dynamic>);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo (${response.statusCode})'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing photo: $e'),
          backgroundColor: const Color(0xFFC01048),
        ),
      );
    }
  }
  Future<void> _pickImage() async {
    final picked = await pickImageFromGallery(context);
    debugPrint('picked: $picked');
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
    });
    await _uploadProfilePhoto(bytes, picked.path);
  }
  Future<void> _uploadProfilePhoto(Uint8List bytes, String path) async {
    try {
      final base64Image = base64Encode(bytes);
      final ext = path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final response = await ApiService.put('/users/profile/photo', {
        'profilePhoto': 'data:$mimeType;base64,$base64Image',
      });
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            backgroundColor: Color(0xFF067647),
          ),
        );
        await _fetchProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo (${response.statusCode})'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
        if (mounted) {
          setState(() {
            _avatarBytes = null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: const Color(0xFFC01048),
        ),
      );
      setState(() {
        _avatarBytes = null;
      });
    }
  }
  List<GlobalKey> get _tourKeys => <GlobalKey>[
        ShowcaseKeys.profileFields,
        _settingsCardKey,
        ShowcaseKeys.profileSubscription,
        if (RoleManager.canViewTeamAccess) _teamAccessKey,
        _logoutKey,
      ];

  Widget _tour(GlobalKey key, String description, Widget child) => Showcase(
        key: key,
        description: description,
        tooltipBackgroundColor: Bt.ink,
        textColor: Colors.white,
        tooltipBorderRadius: BorderRadius.circular(16),
        tooltipPadding: const EdgeInsets.all(16),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      globalTooltipActions: [TooltipActionButton(type: TooltipDefaultActionType.skip, backgroundColor: Colors.transparent, textStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), TooltipActionButton(type: TooltipDefaultActionType.next, backgroundColor: AppColors.primary, textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))], enableAutoScroll: true,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final projProvider = Provider.of<ProjectProvider>(context, listen: false);
          if (projProvider.projectsLoaded && projProvider.projects.isEmpty && !UserSession.hasSkippedTour && !UserSession.visitedModules.contains('profile')) {
            UserSession.markModuleVisited('profile');
            ShowCaseWidget.of(context).startShowCase(_tourKeys);
          }
        });
        final sub = context.watch<SubscriptionProvider>();
        return Scaffold(
          backgroundColor: Bt.ground,
          appBar: BtNavBar(
            title: 'Account',
            trailing: BtIconButton(
              icon: Icons.help_outline_rounded,
              semantic: 'App guidelines',
              color: Bt.ink2,
              onTap: () => ShowCaseWidget.of(context).startShowCase(_tourKeys),
            ),
          ),
          body: _isLoadingProfile
              ? const Padding(padding: EdgeInsets.all(16), child: BtSkeletonList(count: 4))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_profileError != null) ...[
                      _ErrorBanner(message: _profileError!),
                      const SizedBox(height: 12),
                    ],
                    _tour(ShowcaseKeys.profileFields, 'This is your profile summary and role.', _buildProfileCard(_user!)),
                    const SizedBox(height: 20),
                    _tour(ShowcaseKeys.profileSubscription, 'View your current subscription plan and limits.', SubscriptionCard(showUpgradeButton: RoleManager.isAdmin)),
                    const SizedBox(height: 24),
                    // ── Workspace (was the side menu) ──
                    BtSectionHeader(title: 'Workspace', caption: true),
                    _tour(
                      _teamAccessKey,
                      'Assign roles and manage team access from here.',
                      BtGroup(children: [
                        BtRow(
                          leading: const BtTile(icon: Icons.supervisor_account_outlined),
                          title: 'Team Overview',
                          showChevron: true,
                          onTap: () => Navigator.pushNamed(context, '/admin-overview'),
                        ),
                        if (RoleManager.canViewTeamAccess)
                          BtRow(
                            leading: const BtTile(icon: Icons.manage_accounts_outlined),
                            title: 'Assign Role',
                            subtitle: 'Manage user roles, permissions, and project access.',
                            showChevron: true,
                            onTap: () => Navigator.pushNamed(context, '/assign-role'),
                          ),
                        BtRow(
                          leading: const BtTile(icon: Icons.workspace_premium_outlined),
                          title: 'Upgrade Plan',
                          trailing: Text(sub.currentPlan.label, style: BtText.subhead(context)),
                          showChevron: true,
                          onTap: () => Navigator.pushNamed(context, '/subscription'),
                        ),
                        if (UserSession.isAdmin)
                          BtRow(
                            leading: const BtTile(icon: Icons.receipt_long_outlined),
                            title: 'Transaction Logs',
                            showChevron: true,
                            onTap: () => Navigator.pushNamed(context, '/logs'),
                          ),
                        if (UserSession.isAdmin)
                          BtRow(
                            leading: const BtTile(icon: Icons.workspaces_outline),
                            title: 'Create Workspace',
                            showChevron: true,
                            onTap: () => Navigator.pushNamed(context, '/create-workspace'),
                          ),
                      ]),
                    ),
                    if (RoleManager.canViewTeamAccess)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text('Assign Role is only available to Admins.', style: BtText.caption(context)),
                      ),
                    const SizedBox(height: 24),
                    // ── Account settings ──
                    BtSectionHeader(title: 'Account settings', caption: true),
                    _tour(_settingsCardKey, 'Manage your profile and notification settings here.', _buildSettingsCard()),
                    const SizedBox(height: 24),
                    // ── Help ──
                    BtSectionHeader(title: 'Help', caption: true),
                    BtGroup(children: [
                      BtRow(
                        leading: const BtTile(icon: Icons.help_outline_rounded),
                        title: 'App Guidelines',
                        subtitle: 'Replay the guided tour',
                        showChevron: true,
                        onTap: () => ShowCaseWidget.of(context).startShowCase(_tourKeys),
                      ),
                      BtRow(
                        leading: const BtTile(icon: Icons.language_rounded),
                        title: 'Web Portal',
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Bt.placeholder),
                        onTap: () async {
                          final url = Uri.parse('https://buildtrack.nurofin.com');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _tour(_logoutKey, 'Click here to log out securely.', _buildActions()),
                    const SizedBox(height: 20),
                    Center(child: Text('BuildTrack Version 2.4.0 (2024)', style: BtText.caption(context))),
                  ],
                ),
        );
      },
    );
  }
  Widget _buildProfileCard(ProfileUserData user) {
    return BtCard(
      onTap: () async {
        await Navigator.pushNamed(context, '/edit-profile', arguments: _user);
        _fetchProfile();
      },
      child: Row(children: [
        _buildAvatar(user.profilePhoto),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.headline(context)),
            Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context)),
            const SizedBox(height: 6),
            _buildRoleBadge(user.role),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Bt.placeholder),
      ]),
    );
  }
  Widget _buildAvatar(String? photoUrl) {
    ImageProvider? imageProvider;
    if (_avatarBytes != null) {
      imageProvider = MemoryImage(_avatarBytes!);
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      imageProvider = getProfileImageProvider(photoUrl);
    }
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        onTap: _showImageOptions,
        child: Stack(clipBehavior: Clip.none, children: [
          BtAvatar(name: _user?.name ?? '', image: imageProvider, size: 60, self: true),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Bt.line)),
              child: Icon(Icons.photo_camera_outlined, color: context.bt.brand, size: 14),
            ),
          ),
        ]),
      ),
    );
  }
  Widget _buildRoleBadge(String role) => BtBadge(label: role, tone: BtTone.brand);
  Widget _buildSettingsCard() {
    final theme = context.watch<ThemeProvider>();
    const names = {BtPreset.harbor: 'Harbor', BtPreset.nurofin: 'Nurofin', BtPreset.site: 'Site', BtPreset.custom: 'Custom colour'};
    return BtGroup(children: [
      BtRow(
        leading: const BtTile(icon: Icons.person_outline),
        title: 'Edit Profile',
        showChevron: true,
        onTap: () async {
          await Navigator.pushNamed(context, '/edit-profile', arguments: _user);
          _fetchProfile();
        },
      ),
      BtRow(
        leading: const BtTile(icon: Icons.lock_outline),
        title: 'Change Password',
        showChevron: true,
        onTap: () => Navigator.pushNamed(context, '/forgot-password'),
      ),
      BtRow(
        leading: const BtTile(icon: Icons.notifications_outlined),
        title: 'Notifications',
        trailing: BtSwitch(value: _notificationsEnabled, onChanged: _setNotificationsEnabled),
        onTap: () => _setNotificationsEnabled(!_notificationsEnabled),
      ),
      BtRow(
        leading: BtTile(icon: Icons.palette_outlined, bg: context.bt.brandSoft, fg: context.bt.brand),
        title: 'App Theme',
        trailing: Text(names[theme.preset] ?? '', style: BtText.subhead(context)),
        showChevron: true,
        onTap: () => _showAppearance(context),
      ),
    ]);
  }
  Widget _buildActions() {
    return BtGroup(insetDividers: false, children: [
      BtRow(
        leading: const BtTile(icon: Icons.logout_rounded, bg: Bt.redSoft, fg: Bt.red),
        title: 'Logout',
        titleColor: Bt.red,
        onTap: _onLogoutPressed,
      ),
      if (RoleManager.isAdmin)
        BtRow(
          leading: const BtTile(icon: Icons.delete_outline, bg: Bt.redSoft, fg: Bt.red),
          title: 'Delete Account…',
          titleColor: Bt.red,
          onTap: _onDeleteAccountPressed,
        ),
    ]);
  }
  void _showAppearance(BuildContext context) {
    showBtSheet(
      context,
      title: 'App Theme',
      subtitle: 'Applies to your whole workspace',
      builder: (ctx) => const _ThemePicker(),
    );
  }
  Future<void> _onDeleteAccountPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your admin account and ALL data associated with it — projects, team members, transactions, and more. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete My Account',
              style: TextStyle(color: Color(0xFFC01048), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ApiService.delete('/auth/account');
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await AuthService.logout();
        if (!mounted) return;
        context.read<ProjectProvider>().clear();
        context.read<InventoryProvider>().clear();
        context.read<SubscriptionProvider>().clear();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account (${response.statusCode})'),
            backgroundColor: const Color(0xFFC01048),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: const Color(0xFFC01048),
        ),
      );
    }
  }
  void _onLogoutPressed() async {
    await AuthService.logout();
    if (mounted) {
      context.read<ProjectProvider>().clear();
      context.read<InventoryProvider>().clear();
      context.read<SubscriptionProvider>().clear();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTheme.caption.copyWith(color: AppColors.textMedium),
            ),
          ),
        ],
      ),
    );
  }
}



class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final current = themeProvider.preset;
        Widget preset(BtPreset p, String name, String note) {
          final t = BtTheme.forPreset(p);
          final selected = current == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => themeProvider.setPreset(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Bt.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? t.brand : Bt.line, width: selected ? 2 : 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Bt.ground, borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 6, width: 40, decoration: BoxDecoration(color: Bt.ink, borderRadius: BorderRadius.circular(3))),
                      const Spacer(),
                      Container(height: 16, decoration: BoxDecoration(gradient: t.signature, borderRadius: BorderRadius.circular(5))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text(name, style: BtText.subhead(context, weight: FontWeight.w600, color: Bt.ink)),
                  Text(note, style: BtText.caption(context)),
                ]),
              ),
            ),
          );
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            preset(BtPreset.harbor, 'Harbor', 'Default'),
            const SizedBox(width: 8),
            preset(BtPreset.nurofin, 'Nurofin', 'Brand'),
            const SizedBox(width: 8),
            preset(BtPreset.site, 'Site', 'Navy + orange'),
          ]),
          const SizedBox(height: 20),
          Text('Or pick a colour', style: BtText.subhead(context, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final t in themeProvider.availableThemes)
              Semantics(
                button: true,
                label: t['name'] as String,
                child: GestureDetector(
                  onTap: () => themeProvider.setTheme(t['color'] as Color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (themeProvider.currentColor.toARGB32() == (t['color'] as Color).toARGB32()) ? Bt.ink : Colors.white,
                        width: 3,
                      ),
                      boxShadow: const [BoxShadow(color: Color(0x22101828), blurRadius: 2)],
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          BtButton(
            label: 'Choose Custom Color',
            icon: Icons.colorize_rounded,
            variant: BtButtonVariant.secondary,
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  Color tempColor = themeProvider.currentColor;
                  return AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: tempColor,
                        onColorChanged: (color) {
                          tempColor = color;
                        },
                        pickerAreaHeightPercent: 0.8,
                        enableAlpha: false,
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Apply'),
                        onPressed: () {
                          themeProvider.setTheme(tempColor);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Text('Very light colours are darkened automatically so buttons stay readable.', style: BtText.caption(context)),
        ]);
      },
    );
  }
}
