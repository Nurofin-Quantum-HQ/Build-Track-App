import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bt_components.dart';
import 'bt_motion.dart';
import 'bt_success_scenes.dart';
import 'bt_text.dart';
import 'bt_theme.dart';

// Design V2 "Blueprint Noir" signature pieces.
//
// Performance rules followed here (keep them when adding more):
//  • every looping animation sits in a RepaintBoundary and stops when reduce-motion is on;
//  • entrance animations run once per mount and then hold — no idle frames;
//  • nothing uses BackdropFilter (blur over large areas is the #1 jank source on mid phones);
//  • painters are static (shouldRepaint false) unless they animate.

// ─────────────────────────────────────────────────────────────── hero

/// The noir header: blueprint grid fading downwards + an accent glow
/// top-right. Text inside should use bone colours (Bt.bone / Bt.onNoir2).
class BtHero extends StatelessWidget {
  const BtHero({super.key, required this.child, this.padding, this.minHeight = 0, this.overlap = 26});
  final Widget child;

  /// Defaults to safe-area top + 12, sides 16, bottom 22 + [overlap].
  final EdgeInsets? padding;
  final double minHeight;

  /// Space reserved at the bottom for the bone sheet that slides over the hero.
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        color: Bt.noir,
        child: Stack(children: [
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _BlueprintGrid()))),
          const Positioned(right: -110, top: -130, child: _HeroGlow()),
          Padding(
            padding: padding ?? EdgeInsets.fromLTRB(Bt.gutter, top + 12, Bt.gutter, 22 + overlap),
            child: DefaultTextStyle.merge(style: const TextStyle(color: Bt.bone), child: IconTheme.merge(data: const IconThemeData(color: Bt.bone), child: child)),
          ),
        ]),
      ),
    );
  }
}

class _BlueprintGrid extends CustomPainter {
  const _BlueprintGrid();
  @override
  void paint(Canvas canvas, Size size) {
    const step = 22.0;
    final p = Paint()
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x0FFFFFFF), Color(0x0AFFFFFF), Color(0x00FFFFFF)],
        stops: [0, .55, .95],
      ).createShader(Offset.zero & size);
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glow that eases in once (no idle animation → no idle frames).
class _HeroGlow extends StatelessWidget {
  const _HeroGlow();
  @override
  Widget build(BuildContext context) {
    final a = context.bt.accent;
    final level = BtMotion.of(context);
    final full = level == BtMotionLevel.full;
    return IgnorePointer(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: level == BtMotionLevel.off ? 1 : 0, end: 1),
          duration: full ? const Duration(milliseconds: 1600) : (level == BtMotionLevel.off ? Duration.zero : const Duration(milliseconds: 400)),
          curve: Bt.ease,
          builder: (_, t, child) => Opacity(opacity: t, child: full ? Transform.scale(scale: .85 + .15 * t, child: child) : child),
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [a.withValues(alpha: .40), a.withValues(alpha: 0)], stops: const [0, .68]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bone sheet that slides up over the hero (radius 28). Put it right
/// after a [BtHero] in a Column; it pulls itself up by [overlap].
class BtSheet extends StatelessWidget {
  const BtSheet({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(Bt.gutter, 20, Bt.gutter, 32), this.overlap = 26, this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double overlap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -overlap),
      child: BtReveal(
        distance: 48,
        duration: const Duration(milliseconds: 800),
        child: Container(
          decoration: BoxDecoration(color: color ?? Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Scrollable page = noir hero + bone sheet, with pull-to-refresh.
/// Use for tab roots (Home, Projects, Reports, Insights) and detail heroes.
class BtHeroScroll extends StatelessWidget {
  const BtHeroScroll({super.key, required this.hero, required this.children, this.onRefresh, this.controller, this.sheetPadding});
  final Widget hero;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final EdgeInsetsGeometry? sheetPadding;

  @override
  Widget build(BuildContext context) {
    Widget scroll = SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        hero,
        BtSheet(
          padding: sheetPadding ?? const EdgeInsets.fromLTRB(Bt.gutter, 20, Bt.gutter, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ]),
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, color: Bt.noir, backgroundColor: context.bt.accent, edgeOffset: MediaQuery.paddingOf(context).top, child: scroll);
    }
    return scroll;
  }
}

/// Glass stat tile for use on the hero ("Budget left ₹91.3 L").
class BtGlassTile extends StatelessWidget {
  const BtGlassTile({super.key, required this.label, required this.value, this.valueColor, this.onTap, this.selected = false});
  final String label;
  final Widget value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: Bt.fast,
      curve: Bt.ease,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: selected ? Bt.bone : Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: selected ? null : Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: selected ? Bt.ink2 : Bt.onNoir2).copyWith(fontSize: 12)),
        const SizedBox(height: 3),
        DefaultTextStyle.merge(
          style: BtText.num(BtText.headline(context).copyWith(color: valueColor ?? (selected ? Bt.ink : Bt.bone))),
          child: value,
        ),
      ]),
    );
    return onTap == null ? tile : BtPressable(onTap: onTap, scale: .96, child: tile);
  }
}

// ─────────────────────────────────────────────────────────────── motion

/// Fade + rise once on first build. [index] staggers siblings by 60 ms (capped).
class BtReveal extends StatefulWidget {
  const BtReveal({super.key, required this.child, this.index = 0, this.distance = 16, this.duration = const Duration(milliseconds: 700)});
  final Widget child;
  final int index;
  final double distance;
  final Duration duration;
  @override
  State<BtReveal> createState() => _BtRevealState();
}

class _BtRevealState extends State<BtReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Bt.ease);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final level = BtMotion.of(context);
    if (level == BtMotionLevel.off) {
      _c.value = 1;
      return;
    }
    if (level == BtMotionLevel.reduced) {
      // fade only: no stagger, no rise
      _c.duration = BtMotion.fadeReduced;
      _c.forward();
      return;
    }
    final delay = Duration(milliseconds: 60 * widget.index.clamp(0, 10));
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = BtMotion.isFull(context) ? widget.distance : 0.0;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) {
        // Keep the same widget structure for the whole animation (and after),
        // so stateful children (text fields, controllers) are never remounted.
        final v = _t.value.clamp(0.0, 1.0);
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, rise * (1 - v)), child: child));
      },
    );
  }
}

/// Wraps each child in a staggered [BtReveal].
List<Widget> btStagger(List<Widget> children, {int start = 0}) => [
      for (var i = 0; i < children.length; i++) BtReveal(index: start + i, child: children[i]),
    ];

/// Number that rolls up to [value] (re-animates from the old value when it changes).
class BtCountUp extends StatelessWidget {
  const BtCountUp({super.key, required this.value, required this.format, this.style, this.duration = const Duration(milliseconds: 1100)});
  final double value;
  final String Function(double v) format;
  final TextStyle? style;
  final Duration duration;
  @override
  Widget build(BuildContext context) {
    final reduce = Bt.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? value : 0, end: value),
      duration: reduce ? Duration.zero : duration,
      curve: Bt.ease,
      builder: (_, v, _) => Text(format(v), maxLines: 1, style: style != null ? BtText.num(style!) : null),
    );
  }
}

/// 20-segment "bricks" progress — bricks drop in one by one.
class BtBricks extends StatefulWidget {
  const BtBricks({super.key, required this.value, this.count = 20, this.onDark = false, this.color, this.height = 11});
  final double value; // 0..1
  final int count;
  final bool onDark;
  final Color? color;
  final double height;
  @override
  State<BtBricks> createState() => _BtBricksState();
}

class _BtBricksState extends State<BtBricks> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Bt.reduceMotion(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(covariant BtBricks old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !Bt.reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = (widget.value.isNaN ? 0 : widget.value.clamp(0.0, 1.0) * widget.count).round();
    final fill = widget.color ?? context.bt.accent;
    final off = widget.onDark ? Colors.white.withValues(alpha: .10) : Bt.ink.withValues(alpha: .09);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(children: [
          for (var i = 0; i < widget.count; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(child: _brick(i < on, i, fill, off)),
          ],
        ]),
      ),
    );
  }

  Widget _brick(bool lit, int i, Color fill, Color off) {
    final base = Container(height: widget.height, decoration: BoxDecoration(color: off, borderRadius: BorderRadius.circular(3)));
    if (!lit) return base;
    final start = (i * .035).clamp(0.0, .6);
    final t = Bt.spring.transform(((_c.value - start) / .4).clamp(0.0, 1.0));
    return Stack(clipBehavior: Clip.none, children: [
      base,
      Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -14 * (1 - t)),
          child: Container(height: widget.height, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(3))),
        ),
      ),
    ]);
  }
}

/// Circular progress ring that draws itself in.
class BtRing extends StatelessWidget {
  const BtRing({super.key, required this.value, this.size = 64, this.stroke = 7, this.color, this.onDark = false, this.child});
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color? color;
  final bool onDark;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final reduce = Bt.reduceMotion(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? v : 0, end: v),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 1400),
        curve: Bt.ease,
        builder: (_, t, c) => CustomPaint(
          painter: _RingPainter(t, color ?? context.bt.accent, onDark ? Colors.white.withValues(alpha: .1) : Bt.ink.withValues(alpha: .09), stroke),
          child: Center(child: c),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.color, this.track, this.stroke);
  final double t;
  final Color color, track;
  final double stroke;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (t > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * t, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.color != color;
}

/// Ripple rings behind a round child (voice mic). Loops while [active].
class BtPulse extends StatefulWidget {
  const BtPulse({super.key, required this.child, this.color, this.active = true, this.size = 56});
  final Widget child;
  final Color? color;
  final bool active;
  final double size;
  @override
  State<BtPulse> createState() => _BtPulseState();
}

class _BtPulseState extends State<BtPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  void _sync() {
    final run = widget.active && !Bt.reduceMotion(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BtPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.bt.accent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (widget.active)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                for (final off in const [0.0, .5])
                  Builder(builder: (_) {
                    final t = (_c.value + off) % 1;
                    return Transform.scale(
                      scale: 1 + .9 * Curves.easeOut.transform(t),
                      child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .5 * (1 - t)))),
                    );
                  }),
              ]),
            ),
          ),
        widget.child,
      ]),
    );
  }
}

/// Voice waveform bars. Loops while [active]; flat bars otherwise.
class BtWave extends StatefulWidget {
  const BtWave({super.key, this.active = true, this.bars = 5, this.height = 24, this.color, this.barWidth = 4});
  final bool active;
  final int bars;
  final double height;
  final Color? color;
  final double barWidth;
  @override
  State<BtWave> createState() => _BtWaveState();
}

class _BtWaveState extends State<BtWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  void _sync() {
    final run = widget.active && !Bt.reduceMotion(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BtWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.bt.accent;
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < widget.bars; i++) ...[
              if (i > 0) SizedBox(width: widget.barWidth * .75),
              Container(
                width: widget.barWidth,
                height: widget.height * (widget.active ? (.25 + .75 * (.5 + .5 * math.sin((_c.value * 2 * math.pi) + i * 1.3)).abs()) : .25),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(widget.barWidth)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Brick-wall loader: six bricks lay in, hold, fade, repeat.
class BtBrickLoader extends StatefulWidget {
  const BtBrickLoader({super.key, this.label, this.onDark = false, this.scale = 1});
  final String? label;
  final bool onDark;
  final double scale;
  @override
  State<BtBrickLoader> createState() => _BtBrickLoaderState();
}

class _BtBrickLoaderState extends State<BtBrickLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Full: bricks lay in and out. Reduced: the finished wall breathes (a
    // fade, so a loading screen still reads as busy). Off: a still wall.
    if (BtMotion.isOff(context)) {
      _c.stop();
      _c.value = .5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // left, bottom, width
  static const _bricks = [
    [0.0, 0.0, 19.0], [21.0, 0.0, 19.0], [10.5, 10.0, 19.0],
    [0.0, 20.0, 9.0], [11.0, 20.0, 19.0], [32.0, 20.0, 8.0],
  ];

  @override
  Widget build(BuildContext context) {
    final color = context.bt.accent;
    final fullMotion = BtMotion.isFull(context);
    final off = BtMotion.isOff(context);
    final loader = RepaintBoundary(
      child: SizedBox(
        width: 40 * widget.scale,
        height: 30 * widget.scale,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(children: [
            for (var i = 0; i < _bricks.length; i++)
              Builder(builder: (_) {
                final local = (_c.value - i * .055).clamp(0.0, 1.0);
                double o, dy;
                if (!fullMotion) {
                  o = off ? 1 : .45 + .55 * (.5 - .5 * math.cos(_c.value * 2 * math.pi));
                  dy = 0;
                } else if (local < .18) {
                  final t = Bt.ease.transform(local / .18);
                  o = t;
                  dy = -22 * (1 - t);
                } else if (local < .8) {
                  o = 1;
                  dy = 0;
                } else {
                  o = 1 - (local - .8) / .2;
                  dy = 0;
                }
                final b = _bricks[i];
                return Positioned(
                  left: b[0] * widget.scale,
                  bottom: b[1] * widget.scale + dy * widget.scale,
                  child: Opacity(
                    opacity: o.clamp(0.0, 1.0),
                    child: Container(width: b[2] * widget.scale, height: 8 * widget.scale, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.5 * widget.scale))),
                  ),
                );
              }),
          ]),
        ),
      ),
    );
    if (widget.label == null) return loader;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      loader,
      const SizedBox(height: 14),
      Text(widget.label!, textAlign: TextAlign.center, style: BtText.subhead(context, color: widget.onDark ? Bt.onNoir2 : Bt.ink2)),
    ]);
  }
}

/// Centered full-area loading state.
class BtPageLoader extends StatelessWidget {
  const BtPageLoader({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: BtBrickLoader(label: label)));
}

// ─────────────────────────────────────────────────────────────── success moments

enum BtSuccessKind {
  /// Cement bags drop and stack (new material entry saved).
  bags,

  /// Notes slide into a wallet (payment recorded, money in).
  money,

  /// Hard hat drops onto a tick (new labour entry saved).
  labour,

  /// Tower crane lowers a steel bundle onto a slab, then a tick (new equipment entry saved).
  equipment,

  /// Floors stack up into a building, then a tick (daily progress / task done).
  progress,

  /// Check draws in a ring (anything else: approved, sent, signed).
  check,
}

/// Full-screen noir celebration. Auto-closes after [autoClose] (or when the
/// user taps anywhere / the button) and then returns — so callers can `await`
/// it and continue their existing flow (pop, refresh) unchanged.
///
/// Honours the Motion setting: Full plays the scene for [kind]; Reduced and
/// Off show a static tick with a quick fade and close sooner.
Future<void> showBtSuccess(
  BuildContext context, {
  required BtSuccessKind kind,
  required String title,
  String? message,
  String? label,
  String doneLabel = 'Done',
  Duration? autoClose,
}) {
  final level = BtMotion.peek(context);
  final full = level == BtMotionLevel.full;
  final close = autoClose ?? (full ? Duration(milliseconds: math.max(2600, _sceneMs(kind) + 800)) : const Duration(milliseconds: 1400));
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: Duration(milliseconds: full ? 380 : (level == BtMotionLevel.reduced ? 160 : 100)),
    reverseTransitionDuration: Duration(milliseconds: full ? 260 : (level == BtMotionLevel.reduced ? 140 : 100)),
    pageBuilder: (ctx, _, _) => _BtSuccessPage(kind: kind, title: title, message: message, label: label, doneLabel: doneLabel, autoClose: close),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
  ));
}

/// Length of each scene's animation.
int _sceneMs(BtSuccessKind k) => switch (k) {
      BtSuccessKind.labour => 1800,
      BtSuccessKind.equipment => 2200,
      BtSuccessKind.progress => 2000,
      _ => 1900,
    };

class _BtSuccessPage extends StatefulWidget {
  const _BtSuccessPage({required this.kind, required this.title, this.message, this.label, required this.doneLabel, required this.autoClose});
  final BtSuccessKind kind;
  final String title;
  final String? message;
  final String? label;
  final String doneLabel;
  final Duration autoClose;
  @override
  State<_BtSuccessPage> createState() => _BtSuccessPageState();
}

class _BtSuccessPageState extends State<_BtSuccessPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: _sceneMs(widget.kind)));
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future.delayed(widget.autoClose, _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Bt.reduceMotion(context)) {
      _c.value = 1; // static tick, no scene
    } else if (_c.value == 0) {
      _c.forward();
    }
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _iv(double a, double b, [Curve c = Bt.ease]) => c.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final full = BtMotion.isFull(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // Tap anywhere to skip (the Done button still works on its own).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Material(
        color: Bt.noir,
        child: Stack(children: [
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _BlueprintGrid()))),
          const Positioned(right: -110, top: -130, child: _HeroGlow()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(children: [
                const Spacer(),
                RepaintBoundary(
                  child: SizedBox(
                    height: 210,
                    width: 280,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, _) => !full
                          ? _staticCheck()
                          : switch (widget.kind) {
                              BtSuccessKind.bags => _bags(bt),
                              BtSuccessKind.money => _money(bt),
                              BtSuccessKind.labour => _scene(BtHatPainter(_c.value, bt.accent)),
                              BtSuccessKind.equipment => _scene(BtCranePainter(_c.value, bt.accent)),
                              BtSuccessKind.progress => _scene(BtFloorsPainter(_c.value, bt.accent)),
                              BtSuccessKind.check => _check(bt),
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) {
                    final t = _iv(.45, .85);
                    return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (full ? 16 : 0) * (1 - t)), child: child));
                  },
                  child: Column(children: [
                    if (widget.label != null) Text(widget.label!.toUpperCase(), style: BtText.mono(context, color: bt.accent)),
                    if (widget.label != null) const SizedBox(height: 10),
                    Text(widget.title, textAlign: TextAlign.center, style: BtText.d1(context, color: Bt.bone)),
                    if (widget.message != null) ...[
                      const SizedBox(height: 10),
                      Text(widget.message!, textAlign: TextAlign.center, style: BtText.body(context, color: Bt.onNoir2)),
                    ],
                  ]),
                ),
                const Spacer(),
                BtButton(label: widget.doneLabel, variant: BtButtonVariant.onDark, onPressed: _close),
              ]),
            ),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _scene(CustomPainter painter) => CustomPaint(size: kBtSceneSize, painter: painter);

  // Reduced / Off: the tick, already drawn (the route fade is its only motion).
  Widget _staticCheck() => const Center(child: SizedBox(width: 120, height: 120, child: _CheckBadge(progress: 1, size: 120)));

  // Six bags drop and stack; a check pops on top.
  Widget _bags(BtTheme bt) {
    const slots = [
      [8.0, 0.0], [96.0, 0.0], [184.0, 0.0],
      [52.0, 42.0], [140.0, 42.0],
      [96.0, 84.0],
    ];
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(left: -24, right: -24, bottom: 0, child: Container(height: 1, color: Colors.white.withValues(alpha: .25))),
      for (var i = 0; i < slots.length; i++)
        Builder(builder: (_) {
          final start = .05 + i * .085;
          final t = _iv(start, start + .32, const BtDropCurve());
          return Positioned(
            left: slots[i][0],
            bottom: 1 + slots[i][1] + 240 * (1 - t),
            child: Opacity(
              opacity: (t * 3).clamp(0.0, 1.0),
              child: Transform.rotate(angle: -.16 * (1 - t), child: _Bag(top: i == 5, accent: bt.accent)),
            ),
          );
        }),
      Positioned(
        right: 0,
        top: 6,
        child: Transform.scale(scale: _iv(.7, .9, Bt.spring), child: _CheckBadge(progress: _iv(.78, .95))),
      ),
    ]);
  }

  // Three notes slide into a wallet; coins drop.
  Widget _money(BtTheme bt) {
    final fill = _iv(.55, .9);
    return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
      for (var i = 0; i < 3; i++)
        Builder(builder: (_) {
          final t = _iv(.05 + i * .12, .45 + i * .12);
          return Positioned(
            top: 34 + i * 12.0 - 140 * (1 - t),
            left: 65 - 110 * (1 - t),
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.rotate(angle: -.42 * (1 - t), child: const _Note())),
          );
        }),
      Positioned(
        bottom: 0,
        child: Container(
          width: 236,
          height: 112,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(color: Bt.noir3, borderRadius: BorderRadius.circular(22), boxShadow: Bt.shadowLg),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 6,
                color: Colors.white.withValues(alpha: .1),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: fill, heightFactor: 1, child: Container(color: Bt.greenBright)),
              ),
            ),
          ]),
        ),
      ),
      for (var i = 0; i < 2; i++)
        Builder(builder: (_) {
          final t = _iv(.55 + i * .08, .8 + i * .08, Bt.spring);
          return Positioned(
            bottom: 100 + 120 * (1 - t),
            left: i == 0 ? 52 : 196,
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: Container(width: 22, height: 22, decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, -2), blurRadius: 0, spreadRadius: -4)]))),
          );
        }),
    ]);
  }

  Widget _check(BtTheme bt) {
    return Center(
      child: Transform.scale(
        scale: _iv(0, .45, Bt.spring),
        child: SizedBox(width: 120, height: 120, child: _CheckBadge(progress: _iv(.3, .6), size: 120)),
      ),
    );
  }
}

class _Bag extends StatelessWidget {
  const _Bag({required this.top, required this.accent});
  final bool top;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13), bottom: Radius.circular(10)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: top ? [Color.lerp(accent, Colors.white, .25)!, accent] : const [Color(0xFFEDE8DC), Color(0xFFCFC7B5)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 10))],
      ),
      alignment: Alignment.center,
      child: Text(top ? 'SAVED' : 'OPC 53', style: BtText.mono(context, size: 9, color: top ? Bt.noir : const Color(0xFF5B5446))),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(colors: [Color(0xFFCFE8D6), Color(0xFF9DCBAE)]),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 26, spreadRadius: -14, offset: Offset(0, 14))],
      ),
      child: Row(children: [
        Text('₹', style: BtText.d2(context, color: const Color(0xFF245C3D))),
        const Spacer(),
        Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x66245C3D), width: 1.5))),
      ]),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.progress, this.size = 56});
  final double progress;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Bt.greenBright, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Bt.greenBright.withValues(alpha: .25), spreadRadius: size * .14)]),
      child: CustomPaint(painter: _CheckPainter(progress)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    if (t <= 0) return;
    final path = Path()
      ..moveTo(s.width * .28, s.height * .52)
      ..lineTo(s.width * .44, s.height * .68)
      ..lineTo(s.width * .74, s.height * .36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * .075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.t != t;
}
