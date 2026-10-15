import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/controller/role_manager.dart';
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
      case '/inventory':
        return 3;
      case '/reports':
        return 4;
      case '/inbox':
        return 5;
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
    if (RoleManager.canManageInventory) items.add('/inventory');
    items.add('/inbox');
    if (RoleManager.canViewReports) items.add('/reports');
    return items;
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
      3: '/inventory',
      4: '/reports',
    };
    final route = routeMap[newIndex];
    if (route != null) {
      setRoute(route, context);
    }
  }
}
