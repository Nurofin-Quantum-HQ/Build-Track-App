import 'package:flutter_test/flutter_test.dart';

import 'package:buildtrack_mobile/bug_report/shake_controller.dart';
import 'package:buildtrack_mobile/bug_report/shake_detector.dart';

/// m/s² for a given g-force along x.
double g(double v) => v * ShakeDetector.gravity;

void main() {
  group('ShakeDetector', () {
    test('resting phone (1 g) never triggers', () {
      final d = ShakeDetector();
      for (var t = 0; t < 5000; t += 20) {
        expect(d.addSample(0, 0, g(1), t), isFalse);
      }
    });

    test('one strong jolt is not enough', () {
      final d = ShakeDetector();
      expect(d.addSample(g(3.5), 0, 0, 100), isFalse);
      // The same jolt keeps producing strong samples for ~100 ms.
      for (var t = 120; t < 220; t += 20) {
        expect(d.addSample(g(3.2), 0, 0, t), isFalse);
      }
    });

    test('two strong shakes within 1 s trigger', () {
      final d = ShakeDetector();
      expect(d.addSample(g(3), 0, 0, 0), isFalse);
      expect(d.addSample(0, 0, g(1), 60), isFalse); // calm sample between
      expect(d.addSample(0, g(3), 0, 400), isTrue);
    });

    test('two shakes more than 1 s apart do not trigger', () {
      final d = ShakeDetector();
      expect(d.addSample(g(3), 0, 0, 0), isFalse);
      expect(d.addSample(g(3), 0, 0, 1200), isFalse);
      // ...but the second one starts a fresh window.
      expect(d.addSample(g(3), 0, 0, 1700), isTrue);
    });

    test('threshold is about 2.7 g', () {
      final d = ShakeDetector();
      expect(d.addSample(g(2.6), 0, 0, 0), isFalse);
      expect(d.addSample(g(2.6), 0, 0, 300), isFalse);
      expect(d.addSample(g(2.8), 0, 0, 600), isFalse); // first counted shake
      expect(d.addSample(g(2.8), 0, 0, 900), isTrue);
    });

    test('combines all three axes', () {
      expect(ShakeDetector.gForce(g(2), g(2), g(1)), closeTo(3, 1e-9));
    });

    test('resets after triggering', () {
      final d = ShakeDetector();
      d.addSample(g(3), 0, 0, 0);
      expect(d.addSample(g(3), 0, 0, 300), isTrue);
      expect(d.addSample(g(3), 0, 0, 600), isFalse); // needs two again
    });
  });

  group('ShakeController', () {
    late int now;
    late bool allowed;
    late int fired;
    late ShakeController c;

    void shakeTwice() {
      c.onSample(g(3), 0, 0);
      now += 300;
      c.onSample(g(3), 0, 0);
    }

    setUp(() {
      now = 10000;
      allowed = true;
      fired = 0;
      c = ShakeController(canTrigger: () => allowed, onShake: () => fired++, nowMs: () => now);
    });

    test('fires on a double shake', () {
      shakeTwice();
      expect(fired, 1);
    });

    test('does nothing when the setting is off / logged out / sheet open (canTrigger false)', () {
      allowed = false;
      shakeTwice();
      expect(fired, 0);
    });

    test('a half gesture made while blocked does not carry over', () {
      c.onSample(g(3), 0, 0);
      allowed = false;
      now += 100;
      c.onSample(0, 0, g(1)); // blocked sample clears the detector
      allowed = true;
      now += 100;
      c.onSample(g(3), 0, 0);
      expect(fired, 0);
    });

    test('3 s cooldown after the sheet closes', () {
      shakeTwice();
      expect(fired, 1);
      c.sheetClosed();
      now += 100;
      shakeTwice(); // inside the cooldown
      expect(fired, 1);
      now += 3000;
      shakeTwice();
      expect(fired, 2);
    });
  });
}
