import 'package:flutter_test/flutter_test.dart';

import 'package:buildtrack_mobile/bug_report/route_names.dart';

void main() {
  test('known routes map to plain names', () {
    expect(RouteNames.forRoute('/reports'), 'Reports');
    expect(RouteNames.forRoute('/add-material'), 'Add material');
    expect(RouteNames.forRoute('/profile'), 'Account');
    expect(RouteNames.forRoute('/reports?projectId=1'), 'Reports');
  });

  test('unknown named routes are made readable', () {
    expect(RouteNames.forRoute('/vendor-ledger'), 'Vendor ledger');
    expect(RouteNames.forRoute('/'), 'Sign in');
    expect(RouteNames.forRoute(null), isNull);
    expect(RouteNames.forRoute(''), isNull);
  });

  test('humanize widget type names', () {
    expect(RouteNames.humanize('SignaturePage'), 'Signature');
    expect(RouteNames.humanize('AddMaterialScreen'), 'Add material');
    expect(RouteNames.humanize('add_labour'), 'Add labour');
  });

  test('resolve: route name, then widget type, then tab, then Unknown screen', () {
    expect(RouteNames.resolve(routeName: '/inventory', widgetTypeName: 'Foo', tabRoute: '/home'), 'Inventory');
    expect(RouteNames.resolve(widgetTypeName: 'ReceiptViewerScreen', tabRoute: '/home'), 'Receipt viewer');
    expect(RouteNames.resolve(widgetTypeName: '_Private', tabRoute: '/reports'), 'Reports');
    expect(RouteNames.resolve(), 'Unknown screen');
  });

  test('signed-out routes', () {
    for (final r in ['/', '/login', '/forgot-password', '/create-workspace', '/sign-receipt?token=abc']) {
      expect(RouteNames.isSignedOutRoute(r), isTrue, reason: r);
    }
    expect(RouteNames.isSignedOutRoute('/home'), isFalse);
    expect(RouteNames.isSignedOutRoute(null), isFalse);
  });
}
