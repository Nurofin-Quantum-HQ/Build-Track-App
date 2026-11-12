import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:buildtrack_mobile/bug_report/breadcrumbs.dart';
import 'package:buildtrack_mobile/bug_report/report_model.dart';
import 'package:buildtrack_mobile/bug_report/screenshot_capture.dart';

BugReportDraft sample({Uint8List? shot, String description = 'Save does nothing'}) => BugReportDraft(
      clientReportId: newClientReportId(Random(7)),
      description: description,
      tryingTo: ' save a material entry ',
      screenRoute: '/add-material',
      screenName: 'Add material',
      breadcrumbs: [
        Breadcrumb(at: DateTime.utc(2026, 11, 12, 9, 59), kind: 'screen', label: 'Add material'),
        Breadcrumb(at: DateTime.utc(2026, 11, 12, 10, 0), kind: 'api_error', label: 'POST /transactions', detail: 'status 500'),
      ],
      device: const DeviceSnapshot(platform: 'android', osVersion: 'Android 14', model: 'Google Pixel 7', appVersion: '1.0.0', buildNumber: '12', locale: 'en-IN'),
      projectId: 'p1',
      projectName: 'Tower A',
      occurredAt: DateTime.utc(2026, 11, 12, 10, 0, 5),
      screenshot: shot,
    );

void main() {
  test('clientReportId is a UUID v4 and unique', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 200; i++) newClientReportId()};
    expect(ids.length, 200);
    expect(ids.every(re.hasMatch), isTrue);
  });

  test('request body follows the API contract', () {
    final body = sample(shot: Uint8List.fromList([1, 2, 3])).toRequestBody();
    expect(body['source'], 'mobile');
    expect(body['description'], 'Save does nothing');
    expect(body['tryingTo'], 'save a material entry'); // trimmed
    expect(body['screen'], {'route': '/add-material', 'name': 'Add material'});
    expect(body['project'], {'id': 'p1', 'name': 'Tower A'});
    expect(body['occurredAt'], '2026-11-12T10:00:05.000Z');
    expect((body['breadcrumbs'] as List).length, 2);
    expect(body['screenshot'], {'mime': 'image/png', 'base64': base64Encode([1, 2, 3])});
    expect((body['device'] as Map)['platform'], 'android');
    expect((body['device'] as Map).containsKey('userAgent'), isFalse);
  });

  test('empty tryingTo omitted, no screenshot/project → null', () {
    final d = BugReportDraft(
      clientReportId: newClientReportId(),
      description: 'x',
      tryingTo: '  ',
      screenRoute: null,
      screenName: 'Unknown screen',
      breadcrumbs: const [],
      device: const DeviceSnapshot(platform: 'ios'),
      occurredAt: DateTime.utc(2026),
    );
    final body = d.toRequestBody();
    expect(body.containsKey('tryingTo'), isFalse);
    expect(body['screenshot'], isNull);
    expect(body['project'], isNull);
  });

  test('over-long text is clipped to the limits', () {
    final d = sample(description: 'a' * 3000).copyWith(tryingTo: 'b' * 900);
    final body = d.toRequestBody();
    expect((body['description'] as String).length, BugReportLimits.description);
    expect((body['tryingTo'] as String).length, BugReportLimits.tryingTo);
  });

  test('only the last 30 breadcrumbs are sent', () {
    final many = List.generate(50, (i) => Breadcrumb(at: DateTime.utc(2026), kind: 'tap', label: 'T$i'));
    final d = BugReportDraft(
      clientReportId: newClientReportId(),
      description: 'x',
      tryingTo: '',
      screenRoute: '/home',
      screenName: 'Home',
      breadcrumbs: many,
      device: const DeviceSnapshot(platform: 'ios'),
      occurredAt: DateTime.utc(2026),
    );
    final crumbs = d.toRequestBody()['breadcrumbs'] as List;
    expect(crumbs.length, 30);
    expect((crumbs.first as Map)['label'], 'T20');
  });

  test('queue record round-trips through JSON (screenshot kept out of the JSON)', () {
    final draft = sample(shot: Uint8List.fromList(List.filled(10, 9)));
    final q = QueuedReport(draft: draft, userId: 'u1', queuedAt: DateTime.utc(2026, 11, 12, 10), attempts: 2, hasScreenshot: true);
    final json = jsonDecode(jsonEncode(q.toJson())) as Map<String, dynamic>;
    expect(json.toString(), isNot(contains('base64')));
    final back = QueuedReport.fromJson(json, screenshot: Uint8List.fromList([9]));
    expect(back.id, draft.clientReportId);
    expect(back.userId, 'u1');
    expect(back.attempts, 2);
    expect(back.hasScreenshot, isTrue);
    expect(back.draft.description, draft.description);
    expect(back.draft.screenName, 'Add material');
    expect(back.draft.breadcrumbs.length, 2);
    expect(back.draft.breadcrumbs.last.detail, 'status 500');
    expect(back.draft.device.model, 'Google Pixel 7');
    expect(back.draft.projectName, 'Tower A');
    expect(back.draft.occurredAt, draft.occurredAt);
    // Same id and same body → the server can de-duplicate a retry.
    final a = draft.toRequestBody()..remove('screenshot');
    final b = back.draft.toRequestBody()..remove('screenshot');
    expect(b, a);
    expect(back.bumped().attempts, 3);
  });

  test('status labels for Your reports', () {
    expect(MyReport.statusLabel('received'), 'Received');
    expect(MyReport.statusLabel('in_progress'), 'Being fixed');
    expect(MyReport.statusLabel('resolved'), 'Fixed');
    expect(MyReport.statusLabel('closed'), 'Closed');
    final r = MyReport.fromJson({'code': 'BR-1042', 'description': 'd', 'status': 'resolved', 'createdAt': '2026-11-12T10:00:00Z', 'resolutionNote': ' '});
    expect(r.resolutionNote, isNull);
    expect(r.createdAt, isNotNull);
  });

  test('screenshot pixel ratios: min(dpr, 2) then smaller steps', () {
    expect(ScreenshotCapture.ratiosFor(3.0), [2.0, 1.0, 0.7, 0.5]);
    expect(ScreenshotCapture.ratiosFor(1.5), [1.5, 1.0, 0.7, 0.5]);
    expect(ScreenshotCapture.ratiosFor(1.0), [1.0, 0.7, 0.5]);
  });
}
