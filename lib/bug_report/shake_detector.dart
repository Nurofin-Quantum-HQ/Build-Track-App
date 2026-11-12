import 'dart:math' as math;

/// Pure shake logic, fed with accelerometer samples (m/s², gravity included).
///
/// A "strong shake" is one sample whose total acceleration is at least
/// [thresholdG] times gravity (≈ 2.7 g). One physical jolt produces many
/// samples, so strong samples closer than [minGapMs] count as one shake. A
/// report is triggered by [requiredShakes] strong shakes within [windowMs].
/// A brisk walk or a phone dropped on a table rarely hits two 2.7 g peaks in
/// a second; a deliberate shake does.
class ShakeDetector {
  ShakeDetector({
    this.thresholdG = 2.7,
    this.requiredShakes = 2,
    this.windowMs = 1000,
    this.minGapMs = 120,
  });

  static const double gravity = 9.80665;

  final double thresholdG;
  final int requiredShakes;
  final int windowMs;
  final int minGapMs;

  final List<int> _shakeTimes = [];
  int? _lastStrongMs;

  /// Total acceleration in g for a raw sample in m/s².
  static double gForce(double x, double y, double z) => math.sqrt(x * x + y * y + z * z) / gravity;

  /// Feed one sample; [tMs] is a monotonic millisecond timestamp.
  /// Returns true when this sample completes a shake gesture.
  bool addSample(double x, double y, double z, int tMs) {
    if (gForce(x, y, z) < thresholdG) return false;
    final last = _lastStrongMs;
    _lastStrongMs = tMs;
    // Same jolt (continuous strong samples): not a new shake.
    if (last != null && tMs - last < minGapMs) return false;
    _shakeTimes.add(tMs);
    _shakeTimes.removeWhere((t) => tMs - t > windowMs);
    if (_shakeTimes.length >= requiredShakes) {
      reset();
      return true;
    }
    return false;
  }

  void reset() {
    _shakeTimes.clear();
    _lastStrongMs = null;
  }
}
