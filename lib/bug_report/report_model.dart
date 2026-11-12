import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'breadcrumbs.dart';

/// Max lengths agreed with the backend.
class BugReportLimits {
  BugReportLimits._();
  static const int description = 2000;
  static const int tryingTo = 500;
  static const int screenshotBytes = 1500 * 1024; // keep well under the 2 MB server limit
}

/// UUID v4 from a secure random source. Bytes come from `nextInt(256)` —
/// `Random().nextInt(1 << 32)` breaks on web (JS 32-bit shifts).
String newClientReportId([Random? rng]) {
  final r = rng ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.platform,
    this.osVersion = '',
    this.model = '',
    this.appVersion = '',
    this.buildNumber = '',
    this.locale = '',
    this.userAgent,
    this.viewport,
  });

  /// android | ios | web
  final String platform;
  final String osVersion;
  final String model;
  final String appVersion;
  final String buildNumber;
  final String locale;
  final String? userAgent; // web only
  final String? viewport; // web only, "1440x900"

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'osVersion': osVersion,
        'model': model,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'locale': locale,
        if (userAgent != null) 'userAgent': userAgent,
        if (viewport != null) 'viewport': viewport,
      };

  factory DeviceSnapshot.fromJson(Map<String, dynamic> j) => DeviceSnapshot(
        platform: j['platform']?.toString() ?? 'android',
        osVersion: j['osVersion']?.toString() ?? '',
        model: j['model']?.toString() ?? '',
        appVersion: j['appVersion']?.toString() ?? '',
        buildNumber: j['buildNumber']?.toString() ?? '',
        locale: j['locale']?.toString() ?? '',
        userAgent: j['userAgent']?.toString(),
        viewport: j['viewport']?.toString(),
      );

  /// One line for the "What we'll send" panel.
  String get summary {
    final parts = <String>[
      if (model.isNotEmpty) model,
      if (osVersion.isNotEmpty) osVersion,
    ];
    final app = appVersion.isEmpty ? '' : 'app $appVersion${buildNumber.isEmpty ? '' : ' ($buildNumber)'}';
    return [parts.join(' · '), app].where((s) => s.isNotEmpty).join(' · ');
  }
}

/// A problem report, ready to send or to be saved in the offline queue.
class BugReportDraft {
  BugReportDraft({
    required this.clientReportId,
    required this.description,
    required this.tryingTo,
    required this.screenRoute,
    required this.screenName,
    required this.breadcrumbs,
    required this.device,
    required this.occurredAt,
    this.projectId,
    this.projectName,
    this.screenshot,
    this.source = 'mobile',
  });

  final String clientReportId;
  final String source;
  final String description;
  final String tryingTo;
  final String? screenRoute;
  final String screenName;
  final List<Breadcrumb> breadcrumbs;
  final DeviceSnapshot device;
  final String? projectId;
  final String? projectName;
  final DateTime occurredAt;

  /// PNG bytes (or null). Not part of [toJson]; the queue keeps it in its own file.
  final Uint8List? screenshot;

  BugReportDraft copyWith({String? description, String? tryingTo, Uint8List? screenshot, bool clearScreenshot = false}) => BugReportDraft(
        clientReportId: clientReportId,
        source: source,
        description: description ?? this.description,
        tryingTo: tryingTo ?? this.tryingTo,
        screenRoute: screenRoute,
        screenName: screenName,
        breadcrumbs: breadcrumbs,
        device: device,
        occurredAt: occurredAt,
        projectId: projectId,
        projectName: projectName,
        screenshot: clearScreenshot ? null : (screenshot ?? this.screenshot),
      );

  /// Request body for POST /api/bug-reports.
  Map<String, dynamic> toRequestBody() {
    final desc = description.trim();
    final trying = tryingTo.trim();
    final crumbs = breadcrumbs.length > Breadcrumbs.capacity ? breadcrumbs.sublist(breadcrumbs.length - Breadcrumbs.capacity) : breadcrumbs;
    return {
      'clientReportId': clientReportId,
      'source': source,
      'description': desc.length > BugReportLimits.description ? desc.substring(0, BugReportLimits.description) : desc,
      if (trying.isNotEmpty) 'tryingTo': trying.length > BugReportLimits.tryingTo ? trying.substring(0, BugReportLimits.tryingTo) : trying,
      'screen': {'route': screenRoute ?? '', 'name': screenName},
      'breadcrumbs': crumbs.map((b) => b.toJson()).toList(),
      'screenshot': screenshot == null ? null : {'mime': 'image/png', 'base64': base64Encode(screenshot!)},
      'device': device.toJson(),
      'project': projectId == null ? null : {'id': projectId, 'name': projectName ?? ''},
      'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
  }

  /// JSON for the offline queue (no screenshot bytes).
  Map<String, dynamic> toJson() {
    final body = toRequestBody();
    body.remove('screenshot');
    return body;
  }

  factory BugReportDraft.fromJson(Map<String, dynamic> j, {Uint8List? screenshot}) {
    final screen = j['screen'] is Map ? Map<String, dynamic>.from(j['screen'] as Map) : <String, dynamic>{};
    final project = j['project'] is Map ? Map<String, dynamic>.from(j['project'] as Map) : null;
    final crumbs = j['breadcrumbs'] is List
        ? (j['breadcrumbs'] as List).whereType<Map>().map((m) => Breadcrumb.fromJson(Map<String, dynamic>.from(m))).toList()
        : <Breadcrumb>[];
    return BugReportDraft(
      clientReportId: j['clientReportId'].toString(),
      source: j['source']?.toString() ?? 'mobile',
      description: j['description']?.toString() ?? '',
      tryingTo: j['tryingTo']?.toString() ?? '',
      screenRoute: (screen['route']?.toString().isEmpty ?? true) ? null : screen['route'].toString(),
      screenName: screen['name']?.toString() ?? 'Unknown screen',
      breadcrumbs: crumbs,
      device: DeviceSnapshot.fromJson(j['device'] is Map ? Map<String, dynamic>.from(j['device'] as Map) : <String, dynamic>{}),
      projectId: project?['id']?.toString(),
      projectName: project?['name']?.toString(),
      occurredAt: DateTime.tryParse(j['occurredAt']?.toString() ?? '') ?? DateTime.now(),
      screenshot: screenshot,
    );
  }
}

/// A queue record: the draft plus bookkeeping. Serialises to / from one JSON map.
class QueuedReport {
  QueuedReport({required this.draft, required this.userId, required this.queuedAt, this.attempts = 0, this.hasScreenshot = false});

  final BugReportDraft draft;
  final String userId;
  final DateTime queuedAt;
  final int attempts;
  final bool hasScreenshot;

  String get id => draft.clientReportId;

  QueuedReport bumped() => QueuedReport(draft: draft, userId: userId, queuedAt: queuedAt, attempts: attempts + 1, hasScreenshot: hasScreenshot);

  Map<String, dynamic> toJson() => {
        'v': 1,
        'userId': userId,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'hasScreenshot': hasScreenshot,
        'draft': draft.toJson(),
      };

  factory QueuedReport.fromJson(Map<String, dynamic> j, {Uint8List? screenshot}) => QueuedReport(
        draft: BugReportDraft.fromJson(Map<String, dynamic>.from(j['draft'] as Map), screenshot: screenshot),
        userId: j['userId']?.toString() ?? '',
        queuedAt: DateTime.tryParse(j['queuedAt']?.toString() ?? '') ?? DateTime.now(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        hasScreenshot: j['hasScreenshot'] == true,
      );
}

/// An item of "Your reports".
class MyReport {
  const MyReport({required this.code, required this.description, required this.status, this.screenName, this.createdAt, this.resolvedAt, this.resolutionNote});

  final String code;
  final String description;

  /// received | in_progress | resolved | closed
  final String status;
  final String? screenName;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;

  factory MyReport.fromJson(Map<String, dynamic> j) => MyReport(
        code: j['code']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        status: j['status']?.toString() ?? 'received',
        screenName: j['screenName']?.toString(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
        resolvedAt: DateTime.tryParse(j['resolvedAt']?.toString() ?? '')?.toLocal(),
        resolutionNote: (j['resolutionNote']?.toString().trim().isEmpty ?? true) ? null : j['resolutionNote'].toString(),
      );

  /// Plain-language status label.
  static String statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'Being fixed';
      case 'resolved':
        return 'Fixed';
      case 'closed':
        return 'Closed';
      default:
        return 'Received';
    }
  }
}
