import 'package:flutter_test/flutter_test.dart';

import 'package:buildtrack_mobile/bug_report/breadcrumbs.dart';

void main() {
  setUp(Breadcrumbs.clear);

  test('keeps only the last 30 steps', () {
    for (var i = 0; i < 45; i++) {
      Breadcrumbs.tap('Step $i');
    }
    expect(Breadcrumbs.length, 30);
    expect(Breadcrumbs.items.first.label, 'Step 15');
    expect(Breadcrumbs.items.last.label, 'Step 44');
  });

  test('consecutive identical screen changes collapse (NavController + navigator)', () {
    Breadcrumbs.screen('Reports');
    Breadcrumbs.screen('Reports');
    Breadcrumbs.tap('Export CSV report');
    Breadcrumbs.screen('Reports'); // still the same screen as the last screen entry
    Breadcrumbs.screen('Home');
    expect(Breadcrumbs.items.map((b) => '${b.kind}:${b.label}').toList(), ['screen:Reports', 'tap:Export CSV report', 'screen:Home']);
  });

  test('api failures: method + path without query + status, or network error', () {
    Breadcrumbs.apiFailure('post', '/transactions?token=abc123&x=1', 500);
    Breadcrumbs.apiFailure('GET', '/projects/64b7f0c2a1b2c3d4e5f60718/entries', null);
    final a = Breadcrumbs.items[0];
    final b = Breadcrumbs.items[1];
    expect(a.kind, 'api_error');
    expect(a.label, 'POST /transactions');
    expect(a.detail, 'status 500');
    expect(b.label, 'GET /projects/:id/entries');
    expect(b.detail, 'network error');
  });

  test('sanitise removes secrets, emails, amounts and query strings', () {
    expect(Breadcrumbs.sanitize('Authorization: Bearer abc.def.ghi', 120), isNot(contains('abc.def')));
    expect(Breadcrumbs.sanitize('token=SECRETVALUE', 120), isNot(contains('SECRETVALUE')));
    expect(Breadcrumbs.sanitize('password: hunter2', 120), isNot(contains('hunter2')));
    expect(Breadcrumbs.sanitize('mail me at a.b@example.com now', 120), 'mail me at [email] now');
    expect(Breadcrumbs.sanitize('Paid ₹12,500 to vendor', 120), 'Paid [amount] to vendor');
    expect(Breadcrumbs.sanitize('Total 1,25,000.50 due', 120), 'Total [amount] due');
    expect(Breadcrumbs.sanitize('/reports?projectId=1&q=cement', 120), '/reports');
    expect(Breadcrumbs.sanitize('eyJhbGciOi.eyJzdWIiOi.sig', 120), '[removed]');
    expect(Breadcrumbs.sanitize('x' * 40, 120), '[removed]'); // token-looking blob
  });

  test('label clipped to 120 and detail to 200', () {
    Breadcrumbs.tap('word ' * 60);
    expect(Breadcrumbs.items.last.label.length, lessThanOrEqualTo(Breadcrumbs.maxLabel));
    Breadcrumbs.error(Exception('boom ' * 100), 'Screen error');
    expect(Breadcrumbs.items.last.detail!.length, lessThanOrEqualTo(Breadcrumbs.maxDetail));
  });

  test('error details do not echo quoted input or long numbers', () {
    Breadcrumbs.error(const FormatException('Invalid number "5000000"'), 'Screen error');
    final d = Breadcrumbs.items.last.detail!;
    expect(d, isNot(contains('5000000')));
    expect(d, startsWith('FormatException'));
  });

  test('toJson matches the API contract', () {
    Breadcrumbs.now = () => DateTime.utc(2026, 11, 12, 10, 0, 0);
    Breadcrumbs.tap('Save material entry');
    Breadcrumbs.now = DateTime.now;
    expect(Breadcrumbs.toJsonList().single, {'at': '2026-11-12T10:00:00.000Z', 'kind': 'tap', 'label': 'Save material entry'});
  });

  test('sanitizePath', () {
    expect(Breadcrumbs.sanitizePath('https://api.example.com/api/reports?x=1'), '/api/reports');
    expect(Breadcrumbs.sanitizePath('/auth/reset/${'a' * 40}'), '/auth/reset/:token');
  });
}
