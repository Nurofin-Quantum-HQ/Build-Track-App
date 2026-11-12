import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buildtrack_mobile/bug_report/bug_report_service.dart';
import 'package:buildtrack_mobile/bug_report/report_model.dart';
import 'package:buildtrack_mobile/bug_report/report_queue.dart';
import 'package:buildtrack_mobile/controller/user_session.dart';

BugReportDraft draft(String text, {Uint8List? shot}) => BugReportDraft(
      clientReportId: newClientReportId(),
      description: text,
      tryingTo: '',
      screenRoute: '/home',
      screenName: 'Home',
      breadcrumbs: const [],
      device: const DeviceSnapshot(platform: 'android'),
      occurredAt: DateTime.utc(2026, 11, 12),
      screenshot: shot,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late BugReportService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserSession.fromLoginResponse({'id': 'user-1', 'role': 'Admin'});
    dir = await Directory.systemTemp.createTemp('bugq');
    svc = BugReportService.instance..queue = BugReportQueue(directory: () async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('outcomeFromResponse', () {
    test('2xx is sent, with the reference code', () {
      final o = outcomeFromResponse(201, '{"success":true,"data":{"code":"BR-1042","status":"received"}}');
      expect(o.kind, AttemptKind.sent);
      expect(o.code, 'BR-1042');
      expect(outcomeFromResponse(200, '{"success":true,"data":{"code":"BR-1042"}}').kind, AttemptKind.sent);
    });
    test('5xx, 429, 401 and 408 are kept for later', () {
      for (final s in [500, 502, 503, 429, 401, 408]) {
        expect(outcomeFromResponse(s, '{}').kind, AttemptKind.retryLater, reason: '$s');
      }
    });
    test('other 4xx show the server message and are never retried', () {
      final o = outcomeFromResponse(400, '{"success":false,"message":"description is required"}');
      expect(o.kind, AttemptKind.rejected);
      expect(o.message, 'description is required');
      expect(outcomeFromResponse(413, 'not json').kind, AttemptKind.rejected);
    });
  });

  group('queue (files)', () {
    test('add / read / screenshot / remove', () async {
      final d = draft('first', shot: Uint8List.fromList([1, 2, 3]));
      final q = QueuedReport(draft: d, userId: 'user-1', queuedAt: DateTime.now(), hasScreenshot: true);
      await svc.queue.add(q, d.screenshot);
      expect(File('${dir.path}/${d.clientReportId}.json').existsSync(), isTrue);
      expect(File('${dir.path}/${d.clientReportId}.png').existsSync(), isTrue);
      final all = await svc.queue.all();
      expect(all.single.draft.description, 'first');
      expect(await svc.queue.screenshotOf(all.single), [1, 2, 3]);
      await svc.queue.remove(d.clientReportId);
      expect(await svc.queue.all(), isEmpty);
      expect(dir.listSync(), isEmpty);
    });

    test('ignores unsafe ids and corrupt files', () async {
      await svc.queue.remove('../../etc/passwd');
      File('${dir.path}/broken.json').writeAsStringSync('{nope');
      expect(await svc.queue.all(), isEmpty);
    });
  });

  group('submit + retry', () {
    test('network failure saves it and says so; same id is re-sent on retry, then removed', () async {
      final sentIds = <String>[];
      var online = false;
      svc.sender = (d) async {
        sentIds.add(d.clientReportId);
        return online ? const AttemptOutcome(AttemptKind.sent, code: 'BR-1') : const AttemptOutcome(AttemptKind.retryLater);
      };
      final d = draft('offline one', shot: Uint8List.fromList([7, 7]));
      final r = await svc.submit(d);
      expect(r.status, SubmitStatus.queued);
      expect(r.message, "Saved — we'll send it when you're back online.");
      expect((await svc.waiting()).single.draft.clientReportId, d.clientReportId);

      await svc.flushQueue(); // still offline
      expect((await svc.waiting()).single.attempts, 1);

      online = true;
      await svc.flushQueue();
      expect(await svc.waiting(), isEmpty);
      expect(sentIds.toSet(), {d.clientReportId}); // always the same id
      expect(sentIds.length, 3);
    });

    test('sent and rejected are not queued', () async {
      svc.sender = (d) async => const AttemptOutcome(AttemptKind.sent, code: 'BR-9');
      final ok = await svc.submit(draft('ok'));
      expect(ok.status, SubmitStatus.sent);
      expect(ok.code, 'BR-9');
      svc.sender = (d) async => const AttemptOutcome(AttemptKind.rejected, message: 'too long');
      final bad = await svc.submit(draft('bad'));
      expect(bad.status, SubmitStatus.rejected);
      expect(bad.message, 'too long');
      expect(await svc.waiting(), isEmpty);
    });

    test('only the signed-in user\'s reports are retried', () async {
      svc.sender = (d) async => const AttemptOutcome(AttemptKind.retryLater);
      await svc.submit(draft('mine'));
      await UserSession.fromLoginResponse({'id': 'user-2', 'role': 'Admin'});
      final sent = <String>[];
      svc.sender = (d) async {
        sent.add(d.description);
        return const AttemptOutcome(AttemptKind.sent);
      };
      await svc.flushQueue();
      expect(sent, isEmpty);
      await UserSession.fromLoginResponse({'id': 'user-1', 'role': 'Admin'});
      await svc.flushQueue();
      expect(sent, ['mine']);
    });

    test('a report the server refuses on retry is dropped', () async {
      svc.sender = (d) async => const AttemptOutcome(AttemptKind.retryLater);
      await svc.submit(draft('will be refused'));
      svc.sender = (d) async => const AttemptOutcome(AttemptKind.rejected, message: 'no');
      await svc.flushQueue();
      expect(await svc.waiting(), isEmpty);
    });
  });
}
