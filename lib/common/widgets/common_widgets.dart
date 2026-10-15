import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:buildtrack_mobile/services/api_service.dart';
import 'package:buildtrack_mobile/common/widgets/log_sheet.dart';
import 'package:provider/provider.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/common/utils/image_pick_helper.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:buildtrack_mobile/controller/showcase_keys.dart';

class AppTopBar extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final IconData? leftIcon;
  final VoidCallback? onLeftTap;
  final Widget? rightWidget;
  final bool isSubScreen;
  AppTopBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.leftIcon,
    this.onLeftTap,
    this.rightWidget,
    this.isSubScreen = false,
  });
  @override
  Widget build(BuildContext context) {
    final icon = (leftIcon == Icons.arrow_back || leftIcon == Icons.arrow_back_ios) ? Icons.arrow_back_ios_new_rounded : leftIcon;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          icon != null
              ? BtIconButton(icon: icon, size: icon == Icons.arrow_back_ios_new_rounded ? 20 : 24, semantic: 'Back', onTap: onLeftTap)
              : const SizedBox(width: 44),
          Expanded(
            child: titleWidget ??
                Text(
                  title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: BtText.navTitle(context),
                ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44),
            child: Padding(padding: const EdgeInsets.only(right: 8), child: rightWidget ?? const SizedBox(width: 36)),
          ),
        ],
      ),
    );
  }
}
/// Bottom tab bar (DESIGN.md §6 BtTabBar). Tabs are role-filtered exactly as before
/// (NavController.isRouteEnabled). Centre + opens the Log sheet. Inbox shows unread count.
class AppBottomNav extends StatefulWidget {
  AppBottomNav({super.key});
  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  static int _lastUnread = 0;
  int _unread = _lastUnread;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUnread();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchUnread());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnread() async {
    try {
      final count = await ApiService.getUnreadNotificationCount();
      _lastUnread = count;
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF5FFFFFF),
        border: Border(top: BorderSide(color: Bt.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _navItem(context, nav, '/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
              if (nav.isRouteEnabled('/projects'))
                Expanded(
                  child: Showcase(
                    key: ShowcaseKeys.projects,
                    description: 'Click here to view your projects and create new ones.',
                    child: _navItem(context, nav, '/projects', Icons.apartment_outlined, Icons.apartment_rounded, 'Projects', expanded: false),
                  ),
                ),
              if (nav.isRouteEnabled('/add-entry'))
                Expanded(
                  child: Showcase(
                    key: ShowcaseKeys.addEntry,
                    description: 'Click here to add daily entries.',
                    child: _entryButton(context),
                  ),
                ),
              _navItem(context, nav, '/inbox', Icons.inbox_outlined, Icons.inbox_rounded, 'Inbox', badge: _unread),
              if (nav.isRouteEnabled('/reports'))
                Expanded(
                  child: Showcase(
                    key: ShowcaseKeys.reports,
                    description: 'View detailed project reports and bulk CSV imports here.',
                    child: _navItem(context, nav, '/reports', Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports', expanded: false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, NavController nav, String route, IconData icon, IconData activeIcon, String label, {bool expanded = true, int badge = 0}) {
    final isActive = nav.currentRoute == route;
    final color = isActive ? context.bt.brand : Bt.ink3;
    final item = Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: InkWell(
        onTap: () => nav.setRoute(route, context),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(clipBehavior: Clip.none, children: [
                Icon(isActive ? activeIcon : icon, size: 24, color: color),
                if (badge > 0) Positioned(top: -4, right: -12, child: BtCountBadge(count: badge)),
              ]),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, style: BtText.tabLabel(context, color).copyWith(fontWeight: isActive ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
    return expanded ? Expanded(child: item) : item;
  }

  Widget _entryButton(BuildContext context) {
    final bt = context.bt;
    return Semantics(
      button: true,
      label: 'Log an entry',
      child: Center(
        child: InkWell(
          onTap: () => showLogSheet(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 56,
            height: 44,
            decoration: BoxDecoration(
              gradient: bt.signature,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_rounded, color: bt.onAccent, size: 28),
          ),
        ),
      ),
    );
  }
}
class ProfileAvatar extends StatelessWidget {
  final double radius;
  const ProfileAvatar({super.key, this.radius = 18});
  @override
  Widget build(BuildContext context) {
    context.watch<UserSession>();
    final imageProvider = getProfileImageProvider(UserSession.profilePhoto);
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF344054),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );
  }
}
