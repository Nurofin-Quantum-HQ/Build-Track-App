/// Plain-language screen names for problem reports ("/add-material" →
/// "Add material"). Pure functions, no Flutter dependency.
class RouteNames {
  RouteNames._();

  static const String unknown = 'Unknown screen';

  static const Map<String, String> _names = {
    '/': 'Sign in',
    '/login': 'Sign in',
    '/forgot-password': 'Forgot password',
    '/create-workspace': 'Create workspace',
    '/home': 'Home',
    '/projects': 'Projects',
    '/project-detail': 'Project details',
    '/add-entry': 'Add entry',
    '/execution-context': 'Add entry · Where',
    '/choose-entry-mode': 'Add entry · How',
    '/add-material': 'Add material',
    '/add-labour': 'Add labour',
    '/add-equipment': 'Add equipment',
    '/review-material': 'Review material entry',
    '/review-labour': 'Review labour entry',
    '/review-equipment': 'Review equipment entry',
    '/entry-detail': 'Entry details',
    '/update-progress': 'Update progress',
    '/assign-task': 'Assign task',
    '/inventory': 'Inventory',
    '/cement-history': 'Material history',
    '/receipt-viewer': 'Receipt',
    '/fulfillment-payment': 'Payment',
    '/payment-webview': 'Payment page',
    '/reports': 'Reports',
    '/report-insights': 'Report insights',
    '/project-report': 'Project report',
    '/ai-chat': 'Ask AI',
    '/insights': 'Insights',
    '/approvals': 'Approvals',
    '/inbox': 'Inbox',
    '/notifications': 'Notifications',
    '/admin-overview': 'Team overview',
    '/assign-role': 'Assign roles',
    '/logs': 'Transaction logs',
    '/profile': 'Account',
    '/edit-profile': 'Edit profile',
    '/subscription': 'Plans and billing',
    '/my-reports': 'Your reports',
    '/sign-receipt': 'Sign receipt',
  };

  /// Routes where nobody is signed in (shake stays off here).
  static const Set<String> signedOutRoutes = {'/', '/login', '/forgot-password', '/create-workspace', '/sign-receipt'};

  static bool isSignedOutRoute(String? route) {
    if (route == null) return false;
    return signedOutRoutes.contains(stripQuery(route));
  }

  static String stripQuery(String route) {
    final q = route.indexOf('?');
    return q < 0 ? route : route.substring(0, q);
  }

  /// Name for a route path, or null when we have no mapping.
  static String? forRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final path = stripQuery(route);
    final mapped = _names[path];
    if (mapped != null) return mapped;
    // Unknown named route: make the path readable ("/some-thing" → "Some thing").
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    if (seg.isEmpty) return null;
    return humanize(seg.last);
  }

  /// "AddMaterialScreen" / "add-material" / "add_material" → "Add material".
  static String humanize(String raw) {
    var s = raw.replaceAll(RegExp(r'[-_]+'), ' ');
    s = s.replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceFirst(RegExp(r'\s+(Screen|Page|View)$', caseSensitive: false), '');
    if (s.isEmpty) return unknown;
    s = s.toLowerCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Best name for a screen given what we know. Prefers the observed route
  /// name, then the widget type name of an unnamed page, then the tab route.
  static String resolve({String? routeName, String? widgetTypeName, String? tabRoute}) {
    final fromRoute = forRoute(routeName);
    if (fromRoute != null) return fromRoute;
    if (widgetTypeName != null && widgetTypeName.isNotEmpty && !widgetTypeName.startsWith('_')) {
      return humanize(widgetTypeName);
    }
    final fromTab = forRoute(tabRoute);
    if (fromTab != null) return fromTab;
    return unknown;
  }
}
