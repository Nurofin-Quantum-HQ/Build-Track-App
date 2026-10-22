import 'dart:convert';
import 'dart:typed_data';
import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/subscription_card.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
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
      // Don't leave the page on its loading skeleton for ApiService's 90 s
      // timeout on a slow/unreachable network — fall back to the cached
      // session data (the catch below) after 20 s.
      final response = await ApiService.get('/users/profile').timeout(const Duration(seconds: 20));
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
    showBtSheet(
      context,
      title: 'Profile photo',
      builder: (ctx) => BtGroup(children: [
        BtRow(
          leading: const BtTile(icon: Icons.photo_library_outlined),
          title: 'Choose from Gallery',
          onTap: () {
            Navigator.pop(ctx);
            _pickImage();
          },
        ),
        if (hasPhoto)
          BtRow(
            leading: const BtTile(icon: Icons.delete_outline, bg: Bt.redSoft, fg: Bt.red),
            title: 'Remove Profile Photo',
            titleColor: Bt.red,
            onTap: () {
              Navigator.pop(ctx);
              _removeProfilePhoto();
            },
          ),
        BtRow(
          leading: const BtTile(icon: Icons.close),
          title: 'Cancel',
          onTap: () => Navigator.pop(ctx),
        ),
      ]),
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
          // The tour targets only exist once the profile has loaded; starting
          // earlier marked the module visited and ended the tour at step 1.
          if (!mounted || _isLoadingProfile) return;
          final projProvider = Provider.of<ProjectProvider>(context, listen: false);
          if (projProvider.projectsLoaded && projProvider.projects.isEmpty && !UserSession.hasSkippedTour && !UserSession.visitedModules.contains('profile')) {
            UserSession.markModuleVisited('profile');
            ShowCaseWidget.of(context).startShowCase(_tourKeys);
          }
        });
        final sub = context.watch<SubscriptionProvider>();
        if (_isLoadingProfile) {
          return Scaffold(
            backgroundColor: Bt.ground,
            body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BtHero(child: _heroTopBar(context)),
              const Expanded(child: BtSheet(child: BtSkeletonList(count: 4))),
            ]),
          );
        }
        return Scaffold(
          backgroundColor: Bt.ground,
          body: BtHeroScroll(
            hero: BtHero(
              overlap: 26,
              padding: EdgeInsets.fromLTRB(Bt.gutter, MediaQuery.paddingOf(context).top + 4, Bt.gutter, 24 + 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _heroTopBar(context),
                const SizedBox(height: 10),
                _tour(ShowcaseKeys.profileFields, 'This is your profile summary and role.', BtReveal(child: _buildProfileCard(_user!, sub))),
                const SizedBox(height: 20),
                BtReveal(index: 1, child: _buildWorkspaceStrip()),
              ]),
            ),
            children: [
              if (_profileError != null) ...[
                _ErrorBanner(message: _profileError!),
                const SizedBox(height: 12),
              ],
              BtReveal(
                index: 2,
                child: _tour(ShowcaseKeys.profileSubscription, 'View your current subscription plan and limits.', SubscriptionCard(showUpgradeButton: RoleManager.isAdmin)),
              ),
              const SizedBox(height: 24),
              // ── Workspace (was the side menu) ── Admin only: Team Overview is
              // admin-gated (non-admins hit a lock screen), the plan is
              // "managed by your admin", and the other rows were already admin-only.
              if (RoleManager.isAdmin) ...[
              BtReveal(
                index: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const BtSectionHeader(title: 'Workspace', caption: true),
                  _tour(
                    _teamAccessKey,
                    'Assign roles and manage team access from here.',
                    BtGroup(children: [
                      BtRow(
                        leading: const BtTile(icon: Icons.supervisor_account_outlined, size: 34),
                        title: 'Team Overview',
                        subtitle: 'People, roles and recent activity',
                        showChevron: true,
                        onTap: () => Navigator.pushNamed(context, '/admin-overview'),
                      ),
                      if (RoleManager.canViewTeamAccess)
                        BtRow(
                          leading: const BtTile(icon: Icons.manage_accounts_outlined, size: 34),
                          title: 'Assign Role',
                          subtitle: 'Manage user roles, permissions, and project access.',
                          showChevron: true,
                          onTap: () => Navigator.pushNamed(context, '/assign-role'),
                        ),
                      BtRow(
                        leading: BtTile(icon: Icons.workspace_premium_outlined, size: 34, bg: context.bt.accentSoft, fg: context.bt.accentInk),
                        title: 'Upgrade Plan',
                        trailing: Text(sub.currentPlan.label, style: BtText.subhead(context)),
                        showChevron: true,
                        onTap: () => Navigator.pushNamed(context, '/subscription'),
                      ),
                      if (UserSession.isAdmin)
                        BtRow(
                          leading: const BtTile(icon: Icons.receipt_long_outlined, size: 34),
                          title: 'Transaction Logs',
                          showChevron: true,
                          onTap: () => Navigator.pushNamed(context, '/logs'),
                        ),
                      if (UserSession.isAdmin)
                        BtRow(
                          leading: const BtTile(icon: Icons.workspaces_outline, size: 34),
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
                ]),
              ),
              const SizedBox(height: 24),
              ],
              // ── You ──
              BtReveal(
                index: 4,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const BtSectionHeader(title: 'You', caption: true),
                  _tour(_settingsCardKey, 'Manage your profile and notification settings here.', _buildSettingsCard()),
                ]),
              ),
              const SizedBox(height: 24),
              // ── Help ──
              BtReveal(
                index: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const BtSectionHeader(title: 'Help', caption: true),
                  BtGroup(children: [
                    BtRow(
                      leading: const BtTile(icon: Icons.help_outline_rounded, size: 34),
                      title: 'App Guidelines',
                      subtitle: 'Replay the guided tour',
                      showChevron: true,
                      onTap: _replayAppTour,
                    ),
                    BtRow(
                      leading: const BtTile(icon: Icons.language_rounded, size: 34),
                      title: 'Web Portal',
                      subtitle: 'buildtrack.nurofin.com',
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Bt.ink3),
                      onTap: () async {
                        final url = Uri.parse('https://buildtrack.nurofin.com');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),
              _tour(_logoutKey, 'Click here to log out securely.', _buildActions()),
              const SizedBox(height: 14),
              Row(children: [
                if (RoleManager.isAdmin)
                  TextButton(
                    onPressed: _onDeleteAccountPressed,
                    style: TextButton.styleFrom(foregroundColor: Bt.red, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4)),
                    child: Text('Delete Account…', style: BtText.caption(context, color: Bt.red, weight: FontWeight.w500)),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('BUILDTRACK VERSION 2.4.0 (2024)', style: BtText.mono(context)),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  /// Back · help (replay tour) · edit profile — glass buttons on the hero.
  Widget _heroTopBar(BuildContext context) {
    final glass = Colors.white.withValues(alpha: .09);
    return Row(children: [
      Transform.translate(
        offset: const Offset(-6, 0),
        child: BtIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 18, color: Bt.bone, background: glass, semantic: 'Back', onTap: () => Navigator.of(context).maybePop()),
      ),
      Expanded(child: Center(child: Text('ACCOUNT', style: BtText.mono(context, color: Bt.onNoir2)))),
      BtIconButton(
        icon: Icons.help_outline_rounded,
        size: 20,
        color: Bt.bone,
        background: glass,
        semantic: 'Tour this page',
        onTap: () => ShowCaseWidget.of(context).startShowCase(_tourKeys),
      ),
      const SizedBox(width: 8),
      Transform.translate(
        offset: const Offset(6, 0),
        child: BtIconButton(
          icon: Icons.edit_outlined,
          size: 19,
          color: Bt.bone,
          background: glass,
          semantic: 'Edit profile',
          onTap: _user == null
              ? null
              : () async {
                  await Navigator.pushNamed(context, '/edit-profile', arguments: _user);
                  _fetchProfile();
                },
        ),
      ),
    ]);
  }

  Widget _buildProfileCard(ProfileUserData user, SubscriptionProvider sub) {
    return BtPressable(
      onTap: () async {
        await Navigator.pushNamed(context, '/edit-profile', arguments: _user);
        _fetchProfile();
      },
      child: Row(children: [
        _buildAvatar(user.profilePhoto),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.d2(context, color: Bt.bone)),
            const SizedBox(height: 2),
            Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.subhead(context, color: Bt.onNoir2)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _buildRoleBadge(user.role),
              _heroPill('${sub.currentPlan.label} plan'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _heroPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
        child: Text(label, maxLines: 1, style: BtText.caption(context, color: Bt.bone.withValues(alpha: .8), weight: FontWeight.w600).copyWith(fontSize: 12)),
      );

  /// Glass strip with the workspace (company) name + logo.
  Widget _buildWorkspaceStrip() {
    final company = (_user?.companyName.isNotEmpty ?? false) ? _user!.companyName : UserSession.companyName;
    if (company.isEmpty) return const SizedBox.shrink();
    final logo = _user?.companyLogo ?? UserSession.companyLogo;
    final logoImage = (logo != null && logo.isNotEmpty) ? getProfileImageProvider(logo) : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Bt.bone,
            borderRadius: BorderRadius.circular(11),
            image: logoImage != null ? DecorationImage(image: logoImage, fit: BoxFit.contain) : null,
          ),
          child: logoImage == null ? Text(BtAvatar.initials(company), style: BtText.caption(context, color: Bt.noir, weight: FontWeight.w700)) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(company, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.body(context, weight: FontWeight.w600, color: Bt.bone)),
            Text('Workspace', style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
          ]),
        ),
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: Bt.reduceMotion(context) ? 1 : .7, end: 1),
            duration: Bt.slow,
            curve: Bt.spring,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .08), width: 4)),
              child: BtAvatar(name: _user?.name ?? '', image: imageProvider, size: 68, self: true),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: Bt.bone, shape: BoxShape.circle, border: Border.all(color: Bt.noir, width: 2)),
              child: const Icon(Icons.photo_camera_outlined, color: Bt.noir, size: 14),
            ),
          ),
        ]),
      ),
    );
  }
  Widget _buildRoleBadge(String role) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: context.bt.accent, borderRadius: BorderRadius.circular(12)),
        child: Text(role, maxLines: 1, style: BtText.caption(context, color: context.bt.onAccent, weight: FontWeight.w700).copyWith(fontSize: 12)),
      );
  Widget _buildSettingsCard() {
    final theme = context.watch<ThemeProvider>();
    const names = {BtPreset.brass: 'Brass', BtPreset.ember: 'Ember', BtPreset.cobalt: 'Cobalt', BtPreset.jade: 'Jade', BtPreset.custom: 'Custom colour'};
    return BtGroup(children: [
      BtRow(
        leading: const BtTile(icon: Icons.person_outline, size: 34),
        title: 'Edit Profile',
        showChevron: true,
        onTap: () async {
          await Navigator.pushNamed(context, '/edit-profile', arguments: _user);
          _fetchProfile();
        },
      ),
      BtRow(
        leading: const BtTile(icon: Icons.palette_outlined, size: 34),
        title: 'App Theme',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: Bt.fast,
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: theme.btTheme.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(names[theme.preset] ?? '', style: BtText.subhead(context)),
        ]),
        showChevron: true,
        onTap: () => _showAppearance(context),
      ),
      BtRow(
        leading: const BtTile(icon: Icons.notifications_outlined, size: 34),
        title: 'Notifications',
        trailing: BtSwitch(value: _notificationsEnabled, onChanged: _setNotificationsEnabled),
        onTap: () => _setNotificationsEnabled(!_notificationsEnabled),
      ),
      BtRow(
        leading: const BtTile(icon: Icons.lock_outline, size: 34),
        title: 'Change Password',
        showChevron: true,
        onTap: () => Navigator.pushNamed(context, '/forgot-password'),
      ),
    ]);
  }
  Widget _buildActions() {
    return BtPressable(
      onTap: _onLogoutPressed,
      semanticLabel: 'Logout',
      child: Container(
        height: Bt.buttonH,
        decoration: BoxDecoration(color: Bt.card, borderRadius: BorderRadius.circular(Bt.rButton), border: Border.all(color: Bt.inputBorder)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.logout_rounded, color: Bt.red, size: 20),
          const SizedBox(width: 8),
          Text('Logout', style: BtText.button(context, color: Bt.red)),
        ]),
      ),
    );
  }
  void _showAppearance(BuildContext context) {
    showBtSheet(
      context,
      title: 'Appearance',
      subtitle: 'App theme colour · applies to your whole workspace',
      builder: (ctx) => const _ThemePicker(),
    );
  }
  Future<void> _onDeleteAccountPressed() async {
    final confirmed = await btConfirm(
      context,
      title: 'Delete Account?',
      message: 'This will permanently delete your admin account and ALL data associated with it — projects, team members, transactions, and more. This cannot be undone.',
      confirmLabel: 'Delete My Account',
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ApiService.delete('/auth/account');
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        final projects = context.read<ProjectProvider>();
        final inventory = context.read<InventoryProvider>();
        final subscription = context.read<SubscriptionProvider>();
        await AuthService.logout(); // navigates to /login
        projects.clear();
        inventory.clear();
        subscription.clear();
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
  /// App Guidelines: restart the whole guided app tour (all tabs) from Home.
  Future<void> _replayAppTour() async {
    await UserSession.restartAppTour();
    if (!mounted) return;
    context.read<NavController>().setRoute('/home', context);
  }

  void _onLogoutPressed() async {
    // Read the providers before the await — this page is removed by the
    // navigation inside AuthService.logout().
    final projects = context.read<ProjectProvider>();
    final inventory = context.read<InventoryProvider>();
    final subscription = context.read<SubscriptionProvider>();
    // Intentional logout: AuthService clears the session, ignores any 401s from
    // requests still in flight (no "Session expired" alert) and returns to
    // /login itself, so no second navigation here.
    await AuthService.logout();
    projects.clear();
    inventory.clear();
    subscription.clear();
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

  static const _presetNames = {BtPreset.brass: 'Brass', BtPreset.ember: 'Ember', BtPreset.cobalt: 'Cobalt', BtPreset.jade: 'Jade'};

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final current = themeProvider.preset;
        final live = themeProvider.btTheme;

        Widget swatch({required Color color, required bool selected, required String label, required VoidCallback onTap, Gradient? gradient, String? caption}) {
          return Semantics(
            button: true,
            selected: selected,
            label: label,
            child: BtPressable(
              onTap: onTap,
              scale: .9,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: Bt.fast,
                  curve: Bt.ease,
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? Bt.ink : Colors.transparent, width: 2)),
                  child: Container(
                    decoration: BoxDecoration(color: gradient == null ? color : null, gradient: gradient, shape: BoxShape.circle),
                    child: AnimatedSwitcher(
                      duration: Bt.fast,
                      child: selected ? Icon(Icons.check_rounded, key: const ValueKey(true), size: 20, color: gradient == null ? BtTheme.fromAccent(color).onAccent : Colors.white) : const SizedBox.shrink(),
                    ),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(caption, style: BtText.caption(context, color: selected ? Bt.ink : Bt.ink3, weight: selected ? FontWeight.w600 : FontWeight.w400).copyWith(fontSize: 12)),
                ],
              ]),
            ),
          );
        }

        void pickCustom() {
          showDialog(
            context: context,
            barrierColor: Bt.scrim,
            builder: (BuildContext context) {
              Color tempColor = themeProvider.currentColor;
              return AlertDialog(
                backgroundColor: Bt.card,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                title: Text('Pick a color', style: BtText.d3(context)),
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
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                actions: <Widget>[
                  Row(children: [
                    Expanded(
                      child: BtButton(
                        label: 'Cancel',
                        small: true,
                        variant: BtButtonVariant.secondary,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BtButton(
                        label: 'Apply',
                        small: true,
                        onPressed: () {
                          themeProvider.setTheme(tempColor);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ]),
                ],
              );
            },
          );
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Live preview — noir mini card in the current accent.
          _AccentPreview(theme: live),
          const SizedBox(height: 24),
          Text('APP THEME COLOUR', style: BtText.mono(context)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in _presetNames.keys)
              swatch(
                color: BtTheme.presetColors[p]!,
                selected: current == p,
                label: _presetNames[p]!,
                caption: p == BtPreset.brass ? 'Brass ·  Default' : _presetNames[p],
                onTap: () => themeProvider.setPreset(p),
              ),
            swatch(
              color: themeProvider.currentColor,
              selected: current == BtPreset.custom,
              label: 'Choose Custom Color',
              caption: 'Custom',
              gradient: const SweepGradient(colors: [Color(0xFFE5484D), Color(0xFFF2A33A), Color(0xFF16B981), Color(0xFF4F6BFF), Color(0xFFE5484D)]),
              onTap: pickCustom,
            ),
          ]),
          const SizedBox(height: 24),
          Text('OR PICK A COLOUR', style: BtText.mono(context)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final t in themeProvider.availableThemes)
              swatch(
                color: t['color'] as Color,
                selected: themeProvider.currentColor.toARGB32() == (t['color'] as Color).toARGB32(),
                label: t['name'] as String,
                onTap: () => themeProvider.setTheme(t['color'] as Color),
              ),
          ]),
          const SizedBox(height: 24),
          BtButton(
            label: 'Choose Custom Color',
            icon: Icons.colorize_rounded,
            variant: BtButtonVariant.secondary,
            onPressed: pickCustom,
          ),
          const SizedBox(height: 10),
          Text('Very light colours are darkened automatically so buttons stay readable.', style: BtText.caption(context)),
        ]);
      },
    );
  }
}

/// Noir mini card: a total, an accent button and accent bricks — shows the
/// chosen theme colour live (purely visual).
class _AccentPreview extends StatelessWidget {
  const _AccentPreview({required this.theme});
  final BtTheme theme;
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: Bt.medium,
        curve: Bt.ease,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Bt.noir,
          borderRadius: BorderRadius.circular(Bt.rCard),
          boxShadow: Bt.shadowLg,
          gradient: RadialGradient(center: const Alignment(1.1, -1.2), radius: 1.2, colors: [theme.accent.withValues(alpha: .32), Bt.noir]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PREVIEW', style: BtText.mono(context, color: Bt.onNoir2)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total cost so far', style: BtText.caption(context, color: Bt.onNoir2).copyWith(fontSize: 12)),
                Text('₹1.81 Cr', style: BtText.num(BtText.d2(context, color: Bt.bone))),
              ]),
            ),
            AnimatedContainer(
              duration: Bt.medium,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(12)),
              child: Text('Log entry', style: BtText.button(context, size: 14, color: theme.onAccent)),
            ),
          ]),
          const SizedBox(height: 14),
          BtBricks(value: .65, onDark: true, color: theme.accent),
        ]),
      ),
    );
  }
}
