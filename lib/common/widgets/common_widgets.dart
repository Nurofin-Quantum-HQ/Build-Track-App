import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/design/design.dart';
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
/// Bottom dock (Design V2): floating noir bar, accent + in the middle.
/// Tabs are role-filtered exactly as before (NavController.isRouteEnabled):
/// Home · Projects · + (log sheet) · Insights · Reports.
/// Inbox moved to the bell on Home (approvals live on Home too).
class AppBottomNav extends StatelessWidget {
  AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 6, 14, bottom > 0 ? bottom : 14),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: const Color(0xF20E1015),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
          boxShadow: const [BoxShadow(color: Color(0x660A0B0E), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 22))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _tab(context, nav, '/home', Icons.home_outlined, Icons.home_rounded, 'Home'),
            if (nav.isRouteEnabled('/projects'))
              Expanded(
                child: Showcase(
                  key: ShowcaseKeys.projects,
                  description: 'Click here to view your projects and create new ones.',
                  child: _tab(context, nav, '/projects', Icons.apartment_outlined, Icons.apartment_rounded, 'Projects', expanded: false),
                ),
              ),
            if (nav.isRouteEnabled('/add-entry'))
              Expanded(
                child: Showcase(
                  key: ShowcaseKeys.addEntry,
                  description: 'Click here to add daily entries.',
                  child: const _PlusButton(),
                ),
              ),
            if (nav.isRouteEnabled('/insights'))
              _tab(context, nav, '/insights', Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
            if (nav.isRouteEnabled('/reports'))
              Expanded(
                child: Showcase(
                  key: ShowcaseKeys.reports,
                  description: 'View detailed project reports and bulk CSV imports here.',
                  child: _tab(context, nav, '/reports', Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports', expanded: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, NavController nav, String route, IconData icon, IconData activeIcon, String label, {bool expanded = true}) {
    final isActive = nav.currentRoute == route;
    final accent = context.bt.accent;
    final item = BtPressable(
      semanticLabel: label,
      scale: .9,
      onTap: isActive ? null : () => nav.setRoute(route, context),
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: Bt.fast,
              child: Icon(isActive ? activeIcon : icon, key: ValueKey(isActive), size: 23, color: isActive ? accent : const Color(0xFF8A909C)),
            ),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, style: BtText.tabLabel(context, isActive ? Bt.bone : const Color(0xFF8A909C)).copyWith(fontWeight: isActive ? FontWeight.w600 : FontWeight.w500)),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: Bt.medium,
              curve: Bt.spring,
              width: isActive ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
    return expanded ? Expanded(child: item) : item;
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton();
  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: BtPressable(
          semanticLabel: 'Log an entry',
          scale: .9,
          onTap: () => showLogSheet(context),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bt.accent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0E1015), width: 5),
              boxShadow: [BoxShadow(color: bt.accent.withValues(alpha: .55), blurRadius: 26, spreadRadius: -10, offset: const Offset(0, 12))],
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
