import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bt_theme.dart';

/// Painted scenes for the success overlay: labour (hard hat), equipment
/// (tower crane lowering a steel bundle) and progress (floors stacking up).
///
/// Each scene is a [CustomPainter] driven by one controller value `t` in 0..1
/// (the overlay runs it for ~1.8-2.2 s). They draw into a fixed 280 x 210
/// design box and scale to whatever size they are given. Palette: noir
/// background, bone / steel shapes, the theme accent for the hero element and
/// the existing green check badge to finish.
const Size kBtSceneSize = Size(280, 210);

/// Fall, small bounce, settle — shared by bags, helmet and floors.
class BtDropCurve extends Curve {
  const BtDropCurve();
  @override
  double transformInternal(double t) {
    if (t < .55) return Curves.easeIn.transform(t / .55) * 1.04;
    if (t < .75) return 1.04 - .06 * Curves.easeOut.transform((t - .55) / .2);
    return .98 + .02 * Curves.easeOut.transform((t - .75) / .25);
  }
}

double _iv(double t, double a, double b, [Curve c = Bt.ease]) =>
    c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// Green check badge (same look as the overlay's [_CheckBadge]) drawn on a canvas.
void _badge(Canvas canvas, Offset c, double radius, double pop, double tick) {
  if (pop <= 0) return;
  final r = radius * pop;
  canvas.drawCircle(
    c,
    r * 1.14,
    Paint()..color = Bt.greenBright.withValues(alpha: .25),
  );
  canvas.drawCircle(c, r, Paint()..color = Bt.greenBright);
  if (tick <= 0) return;
  final path = Path()
    ..moveTo(c.dx - r * .44, c.dy + r * .04)
    ..lineTo(c.dx - r * .12, c.dy + r * .36)
    ..lineTo(c.dx + r * .48, c.dy - r * .28);
  final m = path.computeMetrics().first;
  canvas.drawPath(
    m.extractPath(0, m.length * tick),
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

abstract class _Scene extends CustomPainter {
  const _Scene(this.t, this.accent);
  final double t;
  final Color accent;

  void draw(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / kBtSceneSize.width,
      size.height / kBtSceneSize.height,
    );
    draw(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Scene o) => o.t != t || o.accent != accent;
}

// ───────────────────────────────────────────────────────────── labour: hard hat

class BtHatPainter extends _Scene {
  const BtHatPainter(super.t, super.accent);

  @override
  void draw(Canvas canvas) {
    const cx = 140.0, cy = 126.0, r = 52.0;
    final pop = _iv(t, 0, .26, Bt.spring);
    final tick = _iv(t, .24, .50);
    final fall = _iv(t, .42, .80, const BtDropCurve());
    final settle = _iv(t, .80, 1.0);

    // ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(cx, 196),
        width: 120 * pop,
        height: 12,
      ),
      Paint()..color = Colors.black.withValues(alpha: .35 * pop),
    );
    // baseline
    canvas.drawLine(
      const Offset(-24, 202),
      const Offset(304, 202),
      Paint()..color = Colors.white.withValues(alpha: .25),
    );

    // worker (round head) with the tick
    _badge(canvas, const Offset(cx, cy + 6), r, pop, tick);

    // helmet drops onto the head
    final dy = -170 * (1 - fall);
    final tilt = -.2 * (1 - fall);
    canvas.save();
    canvas.translate(cx, cy - 30 + dy);
    canvas.rotate(tilt);
    _helmet(canvas, opacity: (fall * 4).clamp(0.0, 1.0));
    canvas.restore();

    // little impact ticks around the helmet once it lands
    if (settle > 0) {
      final p = Paint()
        ..color = accent.withValues(alpha: .9 * (1 - settle))
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final a in const [-2.5, -1.9, -1.2, -.64]) {
        final d1 = 76 + 10 * settle, d2 = 86 + 20 * settle;
        canvas.drawLine(
          Offset(cx + math.cos(a) * d1, cy - 28 + math.sin(a) * d1),
          Offset(cx + math.cos(a) * d2, cy - 28 + math.sin(a) * d2),
          p,
        );
      }
    }
  }

  void _helmet(Canvas canvas, {required double opacity}) {
    if (opacity <= 0) return;
    final shell = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(accent, Colors.white, .28)!, accent],
      ).createShader(const Rect.fromLTWH(-56, -48, 112, 52))
      ..color = Colors.white.withValues(alpha: opacity);
    // dome
    final dome = Path()
      ..moveTo(-52, 0)
      ..cubicTo(-52, -52, 52, -52, 52, 0)
      ..close();
    canvas.drawShadow(dome, Colors.black, 6, false);
    canvas.drawPath(dome, shell);
    // centre ridge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -46, 16, 40),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.black.withValues(alpha: .16 * opacity),
    );
    // brim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-64, -4, 128, 11),
        const Radius.circular(5.5),
      ),
      Paint()
        ..color = Color.lerp(accent, Bt.noir, .22)!.withValues(alpha: opacity),
    );
    // highlight
    canvas.drawArc(
      const Rect.fromLTWH(-40, -40, 44, 40),
      math.pi * 1.05,
      math.pi * .35,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .45 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }
}

// ───────────────────────────────────────────────────────────── equipment: crane

class BtCranePainter extends _Scene {
  const BtCranePainter(super.t, super.accent);

  static const _mastX = 62.0;
  static const _jibY = 30.0;
  static const _slabTop = 188.0;
  static const _steel = Color(0xFFDAD5C8);
  static const _steelDark = Color(0xFFA9A28F);

  @override
  void draw(Canvas canvas) {
    final appear = _iv(t, 0, .14);
    final trolleyP = _iv(t, .04, .34);
    final lower = _iv(t, .16, .66, Curves.easeInOutCubic);
    final land = _iv(t, .66, .76, Curves.easeOut);
    final lift = _iv(t, .74, .92, Bt.ease);
    final badgeP = _iv(t, .76, .92, Bt.spring);
    final tick = _iv(t, .84, 1.0);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .25 * appear)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(-24, 202), const Offset(304, 202), line);

    // concrete slab
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, _slabTop + 2, 232, 12),
        const Radius.circular(3),
      ),
      Paint()..color = Bt.noir3,
    );
    canvas.drawRect(
      const Rect.fromLTWH(24, _slabTop + 2, 232, 2),
      Paint()..color = Colors.white.withValues(alpha: .22),
    );

    canvas.save();
    // tower: two rails + zig-zag bracing
    final mast = Paint()
      ..color = Bt.bone.withValues(alpha: .75 * appear)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const top = _jibY + 6;
    canvas.drawLine(
      const Offset(_mastX - 7, 188),
      const Offset(_mastX - 7, top),
      mast,
    );
    canvas.drawLine(
      const Offset(_mastX + 7, 188),
      const Offset(_mastX + 7, top),
      mast,
    );
    final brace = Paint()
      ..color = Bt.bone.withValues(alpha: .38 * appear)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    var y = 188.0;
    var left = true;
    while (y - 22 >= top) {
      canvas.drawLine(
        Offset(_mastX + (left ? -7 : 7), y),
        Offset(_mastX + (left ? 7 : -7), y - 22),
        brace,
      );
      y -= 22;
      left = !left;
    }
    // base plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(_mastX - 16, 183, 32, 6),
        const Radius.circular(2),
      ),
      Paint()..color = Bt.bone.withValues(alpha: .6 * appear),
    );

    // jib (accent), counter-jib and counterweight, cab
    final jib = Paint()
      ..color = accent.withValues(alpha: appear)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(_mastX - 30, _jibY),
      const Offset(252, _jibY),
      jib,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(_mastX - 40, _jibY - 2, 16, 16),
        const Radius.circular(3),
      ),
      Paint()..color = Bt.bone.withValues(alpha: .55 * appear),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(_mastX - 9, _jibY - 22, 18, 14),
        const Radius.circular(3),
      ),
      Paint()..color = Bt.bone.withValues(alpha: .85 * appear),
    );
    // apex + tie lines
    final tie = Paint()
      ..color = Bt.bone.withValues(alpha: .35 * appear)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      const Offset(_mastX, _jibY - 22),
      const Offset(240, _jibY),
      tie,
    );
    canvas.drawLine(
      const Offset(_mastX, _jibY - 22),
      const Offset(_mastX - 30, _jibY),
      tie,
    );

    // trolley travels out along the jib
    final tx = _lerp(196, 170, trolleyP);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(tx, _jibY + 5), width: 16, height: 8),
        const Radius.circular(2.5),
      ),
      Paint()..color = Bt.bone.withValues(alpha: appear),
    );

    // hook + bundle on a swinging cable
    // cable length: from short (bundle high) to the landing height
    const bundleH = 24.0; // 3 stacked bars
    const hookToBundle = 26.0;
    final landLen = _slabTop - bundleH - hookToBundle - (_jibY + 9) + 2;
    final startLen = 34.0;
    final carry = _lerp(startLen, landLen, lower);
    final swing =
        .12 * math.sin(t * 17) * (1 - lower) * (1 - lift) +
        .02 * math.sin(t * 23) * (1 - land);
    final pivot = Offset(tx, _jibY + 9);
    final dir = Offset(math.sin(swing), math.cos(swing));
    final carryHook = pivot + dir * carry; // where the hook is while carrying
    final hook =
        pivot + dir * (carry - 30 * lift); // the hook rises after the drop
    final cable = Paint()
      ..color = Bt.bone.withValues(alpha: .8 * appear)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, hook, cable);

    final squash = 2.2 * math.sin(land * math.pi);
    final bundleCenter =
        carryHook +
        Offset(
          math.sin(swing) * hookToBundle * .35,
          hookToBundle + bundleH / 2 + squash * .4,
        );
    final ang = swing * .7;
    Offset toWorld(Offset local) =>
        bundleCenter +
        Offset(
          local.dx * math.cos(ang) - local.dy * math.sin(ang),
          local.dx * math.sin(ang) + local.dy * math.cos(ang),
        );
    // slings (drawn in world space so they follow the hook as it rises)
    final sling = Paint()
      ..color = accent.withValues(alpha: .9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hook, toWorld(const Offset(-34, -bundleH / 2)), sling);
    canvas.drawLine(hook, toWorld(const Offset(34, -bundleH / 2)), sling);

    canvas.save();
    canvas.translate(bundleCenter.dx, bundleCenter.dy);
    canvas.rotate(ang);
    // bars: three stacked steel rebar-style rods
    for (var row = 0; row < 3; row++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(-36, bundleH / 2 - (row + 1) * 8.0, 72, 7),
        const Radius.circular(3.5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_steel, _steelDark],
          ).createShader(rect.outerRect),
      );
      final rib = Paint()
        ..color = Colors.black.withValues(alpha: .18)
        ..strokeWidth = 1;
      for (var x = -28.0; x <= 28; x += 8) {
        canvas.drawLine(
          Offset(x, rect.top + 1.5),
          Offset(x, rect.bottom - 1.5),
          rib,
        );
      }
    }
    // accent tag on the bundle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-6, -bundleH / 2 - 1, 12, bundleH + 2),
        const Radius.circular(3),
      ),
      Paint()..color = accent.withValues(alpha: .9),
    );
    canvas.restore();

    // hook block
    canvas.drawCircle(
      hook,
      3.6,
      Paint()..color = accent.withValues(alpha: appear),
    );
    canvas.restore();

    // check badge beside the slab
    _badge(canvas, const Offset(228, 148), 24, badgeP, tick);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// ───────────────────────────────────────────────────────────── progress: floors

class BtFloorsPainter extends _Scene {
  const BtFloorsPainter(super.t, super.accent);

  static const _floors = 5;
  static const _h = 30.0;
  static const _gap = 3.0;
  static const _baseY = 200.0;

  @override
  void draw(Canvas canvas) {
    canvas.drawLine(
      const Offset(-24, 202),
      const Offset(304, 202),
      Paint()..color = Colors.white.withValues(alpha: .25),
    );

    const cx = 130.0;
    for (var i = 0; i < _floors; i++) {
      final start = .04 + i * .125;
      final p = _iv(t, start, start + .3, const BtDropCurve());
      if (p <= 0) continue;
      final w = 150.0 - i * 16;
      final top = _baseY - (i + 1) * _h - i * _gap + 1;
      final dy = -(200 + i * 20) * (1 - p);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, top + dy, w, _h),
        const Radius.circular(5),
      );
      final topFloor = i == _floors - 1;
      canvas.drawShadow(Path()..addRRect(rect), Colors.black, 8, false);
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: topFloor
                ? [Color.lerp(accent, Colors.white, .25)!, accent]
                : const [Color(0xFFEDE8DC), Color(0xFFCFC7B5)],
          ).createShader(rect.outerRect)
          ..color = Colors.white.withValues(alpha: (p * 3).clamp(0.0, 1.0)),
      );
      // windows: unlit bone-dark, then glow in accent once the tower is up
      final cols = 5 - (i ~/ 2);
      final ww = 11.0, wh = 12.0;
      final totalW = cols * ww + (cols - 1) * 9;
      final lit = _iv(t, .66 + i * .045, .76 + i * .045);
      for (var k = 0; k < cols; k++) {
        final wx = cx - totalW / 2 + k * (ww + 9);
        final wr = RRect.fromRectAndRadius(
          Rect.fromLTWH(wx, top + dy + (_h - wh) / 2, ww, wh),
          const Radius.circular(2.5),
        );
        final base = topFloor
            ? Bt.noir.withValues(alpha: .28)
            : const Color(0xFF5B5446).withValues(alpha: .55);
        canvas.drawRRect(
          wr,
          Paint()..color = Color.lerp(base, topFloor ? Bt.noir : accent, lit)!,
        );
      }
    }

    // mast + flag on the roof
    final roofY = _baseY - _floors * _h - (_floors - 1) * _gap + 1;
    final flagP = _iv(t, .74, .9);
    if (flagP > 0) {
      final mastTop = roofY - 34 * flagP;
      canvas.drawLine(
        Offset(cx, roofY),
        Offset(cx, mastTop),
        Paint()
          ..color = Bt.bone
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
      final flag = Path()
        ..moveTo(cx, mastTop)
        ..lineTo(cx + 24 * flagP, mastTop + 6 * flagP)
        ..lineTo(cx, mastTop + 12 * flagP)
        ..close();
      canvas.drawPath(flag, Paint()..color = accent);
    }

    _badge(
      canvas,
      const Offset(240, 52),
      24,
      _iv(t, .78, .94, Bt.spring),
      _iv(t, .86, 1.0),
    );
  }
}
