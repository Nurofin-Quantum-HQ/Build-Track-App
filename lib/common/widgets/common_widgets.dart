import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_gradients.dart';
import 'package:buildtrack_mobile/controller/nav_controller.dart';
import 'package:flutter/material.dart';
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
  const AppTopBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.leftIcon,
    this.onLeftTap,
    this.rightWidget,
    this.isSubScreen = false,
  });
  static const _primaryBlue = AppColors.primary;
  static const _textDark = AppColors.textDark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            leftIcon != null
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: onLeftTap,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(leftIcon, color: _textDark, size: 24),
                      ),
                    ),
                  )
                : const SizedBox(width: 44),
            Expanded(
              child: titleWidget ??
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSubScreen ? _textDark : _primaryBlue,
                      fontSize: isSubScreen ? 17 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
            ),
            IntrinsicWidth(child: rightWidget ?? const SizedBox(width: 32)),
          ],
        ),
      ),
    );
  }
}
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});
  static const _primaryBlue = AppColors.primary;
  static const _textGray = AppColors.textLight;
  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _navItem(context, nav, '/home', Icons.home_rounded, 'HOME'),
              if (nav.isRouteEnabled('/projects'))
                Showcase(
                  key: ShowcaseKeys.projects,
                  description: 'Click here to view your projects and create new ones.',
                  child: _navItem(
                    context,
                    nav,
                    '/projects',
                    Icons.architecture_outlined,
                    'PROJECTS',
                  ),
                ),
              if (nav.isRouteEnabled('/add-entry'))
                Showcase(
                  key: ShowcaseKeys.addEntry,
                  description: 'Click here to add daily entries.',
                  child: _entryButton(context, nav),
                ),
              if (nav.isRouteEnabled('/inventory'))
                Showcase(
                  key: ShowcaseKeys.inventoryTab,
                  description: 'Manage your materials, tools, and inventory here.',
                  tooltipBackgroundColor: const Color(0xFF1E1E2C),
                  textColor: Colors.white,
                  tooltipBorderRadius: BorderRadius.circular(16),
                  tooltipPadding: const EdgeInsets.all(16),
                  child: _navItem(
                    context,
                    nav,
                    '/inventory',
                    Icons.inventory_2_outlined,
                    'INVENTORY',
                  ),
                ),
              if (nav.isRouteEnabled('/reports'))
                Showcase(
                  key: ShowcaseKeys.reports,
                  description: 'View detailed project reports and bulk CSV imports here.',
                  child: _navItem(
                    context,
                    nav,
                    '/reports',
                    Icons.bar_chart_outlined,
                    'REPORTS',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _navItem(
    BuildContext context,
    NavController nav,
    String route,
    IconData icon,
    String label,
  ) {
    final isActive = nav.currentRoute == route;
    return InkWell(
      onTap: () => nav.setRoute(route, context),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: isActive ? _primaryBlue : _textGray),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? _primaryBlue : _textGray,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _entryButton(BuildContext context, NavController nav) {
    final isActive = nav.currentRoute == '/add-entry';
    return InkWell(
      onTap: () => nav.setRoute('/add-entry', context),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppGradients.primaryButton,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 3),
          Text(
            'ENTRY',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isActive ? _primaryBlue : _textGray,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
      backgroundColor: Colors.grey.shade800,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );
  }
}
