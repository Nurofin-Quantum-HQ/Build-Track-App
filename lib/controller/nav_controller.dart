import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';
class NavController extends ChangeNotifier {
  String _currentRoute = '/home';
  String get currentRoute => _currentRoute;
  int get index {
    switch (_currentRoute) {
      case '/home':
        return 0;
      case '/projects':
        return 1;
      case '/add-entry':
        return 2;
      case '/insights':
        return 3;
      case '/reports':
        return 4;
      case '/inventory':
        return 5;
      case '/inbox':
        return 6;
      default:
        return 0;
    }
  }
  bool isRouteEnabled(String route) {
    if (route == '/home') return true;
    if (route == '/projects') return RoleManager.canViewProjects;
    if (route == '/add-entry') return RoleManager.canAddEntries;
    if (route == '/inventory') return RoleManager.canManageInventory;
    if (route == '/reports') return RoleManager.canViewReports;
    // Insights uses the same permission as the project insights entry point.
    if (route == '/insights') return RoleManager.canViewReports;
    if (route == '/inbox') return true;
    if (route == '/logs') return RoleManager.canNavigate('/logs');
    return false;
  }
  void setRoute(String route, BuildContext context) {
    if (!isRouteEnabled(route)) return;
    _currentRoute = route;
    notifyListeners();
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }
  List<String> get routes {
    final items = <String>['/home'];
    if (RoleManager.canViewProjects) items.add('/projects');
    if (RoleManager.canAddEntries) items.add('/add-entry');
    if (RoleManager.canViewReports) items.add('/insights');
    if (RoleManager.canViewReports) items.add('/reports');
    return items;
  }
  /// Order of the guided app tour across tabs. Inventory is not part of it
  /// (it left the bottom bar); Insights has no tour steps of its own.
  static const tourOrder = ['/home', '/projects', '/add-entry', '/reports'];

  /// Called by each tab's tour `onFinish`: moves to the next tab in
  /// [tourOrder] that this user can open, or ends the tour when none is left.
  /// (Before, a disabled next tab made `setRoute` silently do nothing and the
  /// tour got stuck — e.g. for new / restricted accounts.)
  void continueTour(BuildContext context, {required String from}) {
    if (!UserSession.globalTourActive) return;
    final i = tourOrder.indexOf(from);
    for (final next in tourOrder.skip(i + 1)) {
      if (isRouteEnabled(next)) {
        setRoute(next, context);
        return;
      }
    }
    UserSession.setGlobalTourActive(false);
    if (_currentRoute != '/home') setRoute('/home', context);
  }

  /// Record the visible tab without navigating (screen opened directly).
  void markCurrent(String route) {
    if (_currentRoute == route) return;
    _currentRoute = route;
    notifyListeners();
  }

  void setIndex(int newIndex, BuildContext context) {
    final routeMap = {
      0: '/home',
      1: '/projects',
      2: '/add-entry',
      3: '/insights',
      4: '/reports',
    };
    final route = routeMap[newIndex];
    if (route != null) {
      setRoute(route, context);
    }
  }
}
