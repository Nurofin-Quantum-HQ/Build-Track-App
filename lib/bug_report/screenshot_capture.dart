import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'report_model.dart';

/// Takes a picture of the app's own widgets (no OS permission, no photo
/// library). The app root is wrapped in a [RepaintBoundary] keyed by [boundaryKey].
class ScreenshotCapture {
  ScreenshotCapture._();

  static final GlobalKey boundaryKey = GlobalKey(debugLabel: 'bug-report-boundary');

  /// Pixel ratios to try, best first: min(device ratio, 2.0), then smaller
  /// steps until the PNG fits. Pure, for tests.
  static List<double> ratiosFor(double devicePixelRatio) {
    final first = math.min(devicePixelRatio <= 0 ? 1.0 : devicePixelRatio, 2.0);
    final out = <double>[first];
    for (final r in const [1.0, 0.7, 0.5]) {
      if (r < out.last - 0.01) out.add(r);
    }
    return out;
  }

  /// PNG bytes of the current screen, or null if it can't be taken (never throws).
  static Future<Uint8List?> capture({int maxBytes = BugReportLimits.screenshotBytes}) async {
    try {
      final ro = boundaryKey.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return null;
      final dpr = ui.PlatformDispatcher.instance.views.isEmpty ? 1.0 : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      // In debug builds toImage asserts if the boundary still needs painting.
      if (kDebugMode && ro.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      for (final ratio in ratiosFor(dpr)) {
        final image = await ro.toImage(pixelRatio: ratio);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) continue;
          final bytes = data.buffer.asUint8List();
          if (bytes.lengthInBytes <= maxBytes) return bytes;
        } finally {
          image.dispose();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[bug-report] screenshot skipped: $e');
    }
    return null;
  }
}
