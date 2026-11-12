import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'report_model.dart';

/// Reports that could not be sent yet (offline / server trouble). One JSON file
/// plus one optional screenshot file per report in the app documents folder
/// (`bug_report_queue/<clientReportId>.json|.png`). On web there is no file
/// system, so a small JSON list in SharedPreferences is used instead.
class BugReportQueue {
  BugReportQueue({Future<Directory> Function()? directory}) : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  static const String _webKey = 'bug_report_queue_web_v1';
  static const int _webScreenshotLimit = 600 * 1024;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/bug_report_queue');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9\-]{8,64}$');

  Future<void> add(QueuedReport report, Uint8List? screenshot) async {
    if (!_safeId.hasMatch(report.id)) return;
    final withShot = QueuedReport(
      draft: report.draft,
      userId: report.userId,
      queuedAt: report.queuedAt,
      attempts: report.attempts,
      hasScreenshot: screenshot != null && (!kIsWeb || screenshot.length <= _webScreenshotLimit),
    );
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_webKey) ?? <String>[];
      list.removeWhere((s) => _idOf(s) == report.id);
      final json = withShot.toJson();
      if (withShot.hasScreenshot) json['screenshotB64'] = base64Encode(screenshot!);
      list.add(jsonEncode(json));
      await prefs.setStringList(_webKey, list);
      return;
    }
    final dir = await _directory();
    // Screenshot first, JSON last: a JSON file always has its picture.
    final png = File('${dir.path}/${report.id}.png');
    if (screenshot != null) {
      await png.writeAsBytes(screenshot, flush: true);
    } else if (await png.exists()) {
      await png.delete();
    }
    await File('${dir.path}/${report.id}.json').writeAsString(jsonEncode(withShot.toJson()), flush: true);
  }

  /// Records only (oldest first), without screenshots. Unreadable files are skipped.
  Future<List<QueuedReport>> all() async {
    final out = <QueuedReport>[];
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      for (final s in prefs.getStringList(_webKey) ?? const <String>[]) {
        try {
          out.add(QueuedReport.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)));
        } catch (_) {}
      }
    } else {
      final dir = await _directory();
      if (!await dir.exists()) return out;
      await for (final f in dir.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          out.add(QueuedReport.fromJson(Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map)));
        } catch (_) {}
      }
    }
    out.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return out;
  }

  Future<Uint8List?> screenshotOf(QueuedReport r) async {
    if (!r.hasScreenshot) return null;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        for (final s in prefs.getStringList(_webKey) ?? const <String>[]) {
          if (_idOf(s) == r.id) {
            final b64 = (jsonDecode(s) as Map)['screenshotB64']?.toString();
            return b64 == null ? null : base64Decode(b64);
          }
        }
        return null;
      }
      final dir = await _directory();
      final f = File('${dir.path}/${r.id}.png');
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> update(QueuedReport r) async {
    if (!_safeId.hasMatch(r.id)) return;
    if (kIsWeb) {
      final shot = await screenshotOf(r);
      await add(r, shot);
      return;
    }
    final dir = await _directory();
    await File('${dir.path}/${r.id}.json').writeAsString(jsonEncode(r.toJson()), flush: true);
  }

  Future<void> remove(String id) async {
    if (!_safeId.hasMatch(id)) return;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_webKey) ?? <String>[];
      list.removeWhere((s) => _idOf(s) == id);
      await prefs.setStringList(_webKey, list);
      return;
    }
    final dir = await _directory();
    for (final ext in ['json', 'png']) {
      final f = File('${dir.path}/$id.$ext');
      if (await f.exists()) await f.delete();
    }
  }

  static String? _idOf(String json) {
    try {
      return ((jsonDecode(json) as Map)['draft'] as Map)['clientReportId']?.toString();
    } catch (_) {
      return null;
    }
  }
}
