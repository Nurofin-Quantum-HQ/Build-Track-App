import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:buildtrack_mobile/controller/user_session.dart';
import 'package:buildtrack_mobile/services/api_service.dart';

import 'report_model.dart';
import 'report_queue.dart';

enum SubmitStatus { sent, queued, rejected }

class SubmitResult {
  const SubmitResult(this.status, {this.code, this.message});
  final SubmitStatus status;

  /// e.g. "BR-1042" (when sent)
  final String? code;
  final String? message;
}

/// How one attempt to send ended.
enum AttemptKind { sent, retryLater, rejected }

class AttemptOutcome {
  const AttemptOutcome(this.kind, {this.code, this.message});
  final AttemptKind kind;
  final String? code;
  final String? message;
}

/// Turns an HTTP answer into an outcome. Pure, for tests.
///  • 2xx → sent (reference code from `data.code`)
///  • network error / 5xx / 408 / 429 / 401 → keep and retry later
///  • any other 4xx → the server refused it: show its message, never retry
AttemptOutcome outcomeFromResponse(int status, String body) {
  Map<String, dynamic>? json;
  try {
    final d = jsonDecode(body);
    if (d is Map) json = Map<String, dynamic>.from(d);
  } catch (_) {}
  if (status >= 200 && status < 300) {
    final data = json?['data'];
    final code = data is Map ? data['code']?.toString() : null;
    return AttemptOutcome(AttemptKind.sent, code: code);
  }
  if (status >= 500 || status == 408 || status == 429 || status == 401) {
    return AttemptOutcome(AttemptKind.retryLater, message: json?['message']?.toString());
  }
  return AttemptOutcome(AttemptKind.rejected, message: json?['message']?.toString() ?? 'We couldn\'t accept that report ($status).');
}

class BugReportService {
  BugReportService._();
  static final BugReportService instance = BugReportService._();

  static const String savedOfflineMessage = "Saved — we'll send it when you're back online.";
  static const Duration _maxAge = Duration(days: 30);

  BugReportQueue queue = BugReportQueue();

  /// Overridable for tests.
  Future<AttemptOutcome> Function(BugReportDraft draft) sender = _send;

  static Future<AttemptOutcome> _send(BugReportDraft draft) async {
    try {
      final res = await ApiService.post('/bug-reports', draft.toRequestBody());
      return outcomeFromResponse(res.statusCode, res.body);
    } catch (e) {
      // ApiService throws 'Unauthorized' on 401 (and signs the user out) and a
      // raw exception on timeout / no network: both mean "try again later".
      return const AttemptOutcome(AttemptKind.retryLater);
    }
  }

  /// Sends now; if that isn't possible right now, keeps it for later.
  Future<SubmitResult> submit(BugReportDraft draft) async {
    final outcome = await sender(draft);
    switch (outcome.kind) {
      case AttemptKind.sent:
        return SubmitResult(SubmitStatus.sent, code: outcome.code);
      case AttemptKind.rejected:
        return SubmitResult(SubmitStatus.rejected, message: outcome.message);
      case AttemptKind.retryLater:
        await _enqueue(draft);
        return const SubmitResult(SubmitStatus.queued, message: savedOfflineMessage);
    }
  }

  Future<void> _enqueue(BugReportDraft draft) async {
    try {
      await queue.add(
        QueuedReport(draft: draft, userId: UserSession.userId, queuedAt: DateTime.now(), hasScreenshot: draft.screenshot != null),
        draft.screenshot,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[bug-report] could not save to queue: $e');
    }
  }

  Future<void>? _flushing;

  /// Retries everything saved for the signed-in user. Safe to call often
  /// (app start, resume): one run at a time. The same clientReportId is sent
  /// each time, so the server never creates a duplicate.
  Future<void> flushQueue() => _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    try {
      final me = UserSession.userId;
      if (me.isEmpty) return;
      final items = (await queue.all()).where((q) => q.userId == me).toList();
      for (final q in items) {
        if (DateTime.now().difference(q.queuedAt) > _maxAge) {
          await queue.remove(q.id);
          continue;
        }
        final shot = await queue.screenshotOf(q);
        final draft = q.draft.copyWith(screenshot: shot);
        final outcome = await sender(draft);
        switch (outcome.kind) {
          case AttemptKind.sent:
          case AttemptKind.rejected:
            await queue.remove(q.id);
            break;
          case AttemptKind.retryLater:
            await queue.update(q.bumped());
            return; // still offline / server busy: keep order, try next time
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[bug-report] queue retry failed: $e');
    }
  }

  /// Reports saved on this phone that haven't reached us yet (signed-in user).
  Future<List<QueuedReport>> waiting() async {
    try {
      final me = UserSession.userId;
      return (await queue.all()).where((q) => q.userId == me).toList();
    } catch (_) {
      return const [];
    }
  }

  /// "Your reports": newest first.
  Future<List<MyReport>> fetchMine() async {
    final http.Response res = await ApiService.get('/bug-reports/mine');
    if (res.statusCode != 200) {
      throw Exception('Status ${res.statusCode}');
    }
    final d = jsonDecode(res.body);
    final list = d is Map ? d['data'] : d;
    if (list is! List) return const [];
    return list.whereType<Map>().map((m) => MyReport.fromJson(Map<String, dynamic>.from(m))).toList();
  }
}
