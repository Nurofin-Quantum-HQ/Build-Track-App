import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buildtrack_mobile/controller/user_session.dart';

import 'bug_report_flow.dart';
import 'screen_tracker.dart';
import 'shake_controller.dart';
import 'shake_detector.dart';

/// "Shake to report a problem": setting + accelerometer listener.
///
/// Off (no sensor subscription at all) when: the setting is off, the app is in
/// the background, or on web. A shake is ignored when: nobody is signed in, a
/// signed-out screen is showing, or the report sheet is open / opening.
class ShakeService with WidgetsBindingObserver {
  ShakeService._() {
    controller = ShakeController(
      canTrigger: _canTrigger,
      onShake: () => BugReportFlow.open(trigger: 'shake'),
      nowMs: () => _clock.elapsedMilliseconds,
      detector: ShakeDetector(),
    );
  }
  static final ShakeService instance = ShakeService._();

  static const String prefsKey = 'shake_to_report_enabled';

  /// The Account screen's switch listens to this (default ON).
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  final Stopwatch _clock = Stopwatch()..start();
  late final ShakeController controller;
  StreamSubscription<AccelerometerEvent>? _sub;
  bool _foreground = true;
  bool _started = false;

  bool _canTrigger() {
    if (kIsWeb || !enabled.value || !_foreground) return false;
    if (BugReportFlow.isOpen) return false;
    if (UserSession.userId.isEmpty) return false; // not signed in
    if (ScreenTracker.instance.onSignedOutScreen) return false;
    return true;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(prefsKey) ?? true;
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    enabled.addListener(_sync);
    _sync();
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (_) {}
  }

  /// The sheet closed: 3 s with no new shake.
  void sheetClosed() => controller.sheetClosed();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final want = !kIsWeb && enabled.value && _foreground;
    if (want && _sub == null) {
      try {
        _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
          (e) => controller.onSample(e.x, e.y, e.z),
          onError: (Object _) {}, // no accelerometer: shake simply never fires
          cancelOnError: false,
        );
      } catch (_) {}
    } else if (!want && _sub != null) {
      _sub!.cancel();
      _sub = null;
      controller.detector.reset();
    }
  }
}
