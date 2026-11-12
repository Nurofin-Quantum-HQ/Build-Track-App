import 'shake_detector.dart';

/// Decides whether a shake should open the report sheet. Pure: the sensor
/// stream, clock and app state are injected, so it can be tested with
/// synthetic samples.
class ShakeController {
  ShakeController({
    required this.canTrigger,
    required this.onShake,
    required this.nowMs,
    ShakeDetector? detector,
    this.cooldownMs = 3000,
  }) : detector = detector ?? ShakeDetector();

  /// Everything that must be true for a shake to count: setting on, signed in,
  /// not on a signed-out screen, app in the foreground, sheet not open, not web.
  final bool Function() canTrigger;
  final void Function() onShake;
  final int Function() nowMs;
  final ShakeDetector detector;
  final int cooldownMs;

  int _cooldownUntil = 0;

  bool get inCooldown => nowMs() < _cooldownUntil;

  /// One accelerometer sample (m/s²).
  void onSample(double x, double y, double z) {
    if (!canTrigger() || inCooldown) {
      detector.reset();
      return;
    }
    if (detector.addSample(x, y, z, nowMs())) onShake();
  }

  /// Call when the report sheet has closed: no new shake for [cooldownMs].
  void sheetClosed() {
    _cooldownUntil = nowMs() + cooldownMs;
    detector.reset();
  }
}
