import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import 'package:buildtrack_mobile/config/navigator_key.dart';
import 'package:buildtrack_mobile/controller/project_provider.dart';
import 'package:buildtrack_mobile/design/design.dart';

import 'breadcrumbs.dart';
import 'bug_report_sheet.dart';
import 'device_snapshot.dart';
import 'report_model.dart';
import 'screen_tracker.dart';
import 'screenshot_capture.dart';
import 'shake_service.dart';

/// Opens the "Report a problem" sheet from anywhere (shake or the Account row).
class BugReportFlow {
  BugReportFlow._();

  static bool _open = false;

  /// True from the moment a report starts opening until its sheet has closed.
  static bool get isOpen => _open;

  /// [trigger]: `shake` | `account`.
  static Future<void> open({required String trigger}) async {
    if (_open) return;
    _open = true;
    try {
      // 1. Capture the screen BEFORE the sheet covers it.
      final occurredAt = DateTime.now();
      final screen = ScreenTracker.instance.current();
      final shot = await ScreenshotCapture.capture();
      final device = await DeviceSnapshotCollector.collect();
      final steps = Breadcrumbs.items;

      final ctx = globalNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      String? projectId;
      String? projectName;
      try {
        final p = Provider.of<ProjectProvider>(ctx, listen: false).selectedProject;
        projectId = p?.id;
        projectName = p?.name;
      } catch (_) {}

      final base = BugReportDraft(
        clientReportId: newClientReportId(),
        description: '',
        tryingTo: '',
        screenRoute: screen.route,
        screenName: screen.name,
        breadcrumbs: steps,
        device: device,
        occurredAt: occurredAt,
        projectId: projectId,
        projectName: projectName,
        screenshot: shot,
      );

      await showBtSheet<void>(
        ctx,
        title: 'Report a problem',
        subtitle: 'Something not working? Tell us.',
        builder: (_) => BugReportForm(base: base, offerTurnOff: !kIsWeb),
      );
    } finally {
      _open = false;
      ShakeService.instance.sheetClosed();
    }
  }
}
