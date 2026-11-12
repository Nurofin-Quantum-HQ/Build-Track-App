import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'report_model.dart';

/// Device + app facts for a report. Collected once, then reused.
class DeviceSnapshotCollector {
  DeviceSnapshotCollector._();

  static DeviceSnapshot? _cached;

  static Future<DeviceSnapshot> collect() async {
    final cached = _cached;
    if (cached != null) return cached;
    var platform = 'web';
    var os = '';
    var model = '';
    String? ua;
    String? viewport;
    var appVersion = '';
    var build = '';
    final locale = ui.PlatformDispatcher.instance.locale.toLanguageTag();
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
      build = info.buildNumber;
    } catch (_) {}
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await plugin.webBrowserInfo;
        ua = w.userAgent;
        model = w.browserName.name;
        os = w.platform ?? '';
        final views = ui.PlatformDispatcher.instance.views;
        if (views.isNotEmpty) {
          final v = views.first;
          final s = v.physicalSize / v.devicePixelRatio;
          viewport = '${s.width.round()}x${s.height.round()}';
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        platform = 'android';
        final a = await plugin.androidInfo;
        model = '${a.manufacturer} ${a.model}'.trim();
        os = 'Android ${a.version.release} (API ${a.version.sdkInt})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
        final i = await plugin.iosInfo;
        model = i.utsname.machine;
        os = '${i.systemName} ${i.systemVersion}';
      }
    } catch (_) {}
    return _cached = DeviceSnapshot(
      platform: platform,
      osVersion: os,
      model: model,
      appVersion: appVersion,
      buildNumber: build,
      locale: locale,
      userAgent: ua,
      viewport: viewport,
    );
  }
}
