import 'package:flutter/widgets.dart';

import 'breadcrumbs.dart';
import 'route_names.dart';

/// Watches the navigator so a problem report can say which screen the user was
/// on. Add [ScreenTracker.instance] to `MaterialApp.navigatorObservers`.
///
/// Only full pages count: dialogs and bottom sheets are overlays on a screen,
/// not screens. The bottom-tab routes also come in through NavController (see
/// the report host); both feed the same breadcrumb, which de-duplicates.
class ScreenTracker extends NavigatorObserver {
  ScreenTracker._();
  static final ScreenTracker instance = ScreenTracker._();

  final List<Route<dynamic>> _pages = [];

  /// Fallback tab route (NavController.currentRoute), set by the report host.
  String Function()? tabRoute;

  Route<dynamic>? get _top => _pages.isEmpty ? null : _pages.last;

  /// Raw route name of the visible page, if it has one.
  String? get currentRouteName => _top?.settings.name;

  /// Forgets everything (tests).
  void reset() => _pages.clear();

  /// Current screen as (route, plain name).
  ({String? route, String name}) current() {
    final top = _top;
    final routeName = top?.settings.name;
    final name = RouteNames.resolve(
      routeName: routeName,
      widgetTypeName: top == null ? null : widgetTypeNameOf(top),
      tabRoute: tabRoute?.call(),
    );
    return (route: routeName != null ? RouteNames.stripQuery(routeName) : tabRoute?.call(), name: name);
  }

  /// True while the visible page is a signed-out screen (login, sign-up, …).
  bool get onSignedOutScreen => RouteNames.isSignedOutRoute(currentRouteName);

  // ── NavigatorObserver ─────────────────────────────────────────────────

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _pages.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final i = _pages.indexOf(oldRoute);
      if (i >= 0) {
        _pages.removeAt(i);
        if (newRoute is PageRoute) _pages.insert(i, newRoute);
      } else if (newRoute is PageRoute) {
        _pages.add(newRoute);
      }
    } else if (newRoute is PageRoute) {
      _pages.add(newRoute);
    }
    _changed();
  }

  void _changed() {
    final top = _top;
    if (top == null) return;
    if (top.settings.name != null) {
      Breadcrumbs.screen(current().name);
      return;
    }
    // Unnamed page: its widget only exists after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_top, top)) Breadcrumbs.screen(current().name);
    });
  }

  // ── widget type name of an unnamed page ───────────────────────────────

  static const Set<String> _wrappers = {
    'Builder', 'StatefulBuilder', 'Consumer', 'Selector', 'Consumer2', 'ShowCaseWidget', 'Showcase', 'Material', 'Scaffold',
    'AnnotatedRegion', 'SafeArea', 'Padding', 'Container', 'Center', 'Column', 'Row', 'Expanded', 'Stack', 'ListView', 'GestureDetector',
    'RepaintBoundary', 'Semantics', 'Focus', 'FocusScope', 'PopScope', 'Theme', 'Directionality', 'Overlay',
  };

  /// First app-level Stateless/Stateful widget under the page, e.g. "SignaturePage".
  static String? widgetTypeNameOf(Route<dynamic> route) {
    if (route is! ModalRoute) return null;
    final ctx = route.subtreeContext;
    if (ctx is! Element) return null;
    String? found;
    var depth = 0;
    void visit(Element e) {
      if (found != null || depth > 12) return;
      final w = e.widget;
      if (w is StatelessWidget || w is StatefulWidget) {
        final n = w.runtimeType.toString().split('<').first;
        if (!n.startsWith('_') && !_wrappers.contains(n)) {
          found = n;
          return;
        }
      }
      depth++;
      e.visitChildren(visit);
      depth--;
    }

    try {
      ctx.visitChildren(visit);
    } catch (_) {
      return null;
    }
    return found;
  }
}
