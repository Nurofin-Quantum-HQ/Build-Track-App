import 'package:buildtrack_mobile/common/themes/app_colors.dart';
import 'package:buildtrack_mobile/common/themes/app_theme.dart';
import 'package:buildtrack_mobile/common/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.showAppBar = true,
    this.centerTitle = true,
    this.backgroundColor = AppTheme.background,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool showAppBar;
  final bool centerTitle;
  final Color backgroundColor;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              centerTitle: centerTitle,
              leading: leading,
              actions: actions,
              elevation: 0,
              backgroundColor: AppColors.cardBg,
              foregroundColor: AppColors.textDark,
            )
          : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
class AppScrollLayout extends StatelessWidget {
  const AppScrollLayout({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.showAppBar = true,
    this.backgroundColor = AppTheme.background,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool showAppBar;
  final Color backgroundColor;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              centerTitle: true,
              leading: leading,
              actions: actions,
              elevation: 0,
              backgroundColor: AppColors.cardBg,
              foregroundColor: AppColors.textDark,
            )
          : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
class AppSubScreenLayout extends StatelessWidget {
  const AppSubScreenLayout({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.spacingMd,
      AppTheme.spacingSm,
      AppTheme.spacingMd,
      AppTheme.spacingLg,
    ),
    this.scrollable = false,
    this.backgroundColor = AppTheme.background,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final Color backgroundColor;
  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: scrollable
          ? SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            )
          : child,
    );
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingMd),
              child: trailing,
            ),
          ...?actions,
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(bottom: false, child: body),
    );
  }
}
class AppTabLayout extends StatelessWidget {
  const AppTabLayout({
    super.key,
    required this.title,
    required this.child,
    required this.selectedIndex,
    required this.onTabChanged,
    this.tabs = const [
      AppTabItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
      ),
      AppTabItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: 'Projects',
      ),
      AppTabItem(
        icon: Icons.add_circle_outline,
        activeIcon: Icons.add_circle,
        label: 'Add',
      ),
      AppTabItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'Stock',
      ),
      AppTabItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: 'Reports',
      ),
    ],
    this.actions,
    this.backgroundColor = AppTheme.background,
  });
  final String title;
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final List<AppTabItem> tabs;
  final List<Widget>? actions;
  final Color backgroundColor;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textDark,
        actions: actions,
      ),
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: _AppBottomNav(
        selectedIndex: selectedIndex,
        onTabChanged: onTabChanged,
        tabs: tabs,
      ),
    );
  }
}
class AppTabItem {
  const AppTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav({
    required this.selectedIndex,
    required this.onTabChanged,
    required this.tabs,
  });
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final List<AppTabItem> tabs;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTabChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? tab.activeIcon : tab.icon,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textLight,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });
  final bool isLoading;
  final Widget child;
  final String? message;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXl,
                  vertical: AppTheme.spacingLg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    if (message != null) ...[
                      const SizedBox(height: AppTheme.spacingMd),
                      Text(message!, style: AppTheme.body),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
