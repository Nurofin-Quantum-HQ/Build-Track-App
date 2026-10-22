import 'package:buildtrack_mobile/controller/role_manager.dart';
import 'package:buildtrack_mobile/design/design.dart';
import 'package:flutter/material.dart';

/// "Log an entry" sheet opened by the centre + (Design V2 · Log-Sheet board).
/// Same choices as the Add Entry page: Material / Labour / Equipment go to the
/// existing flow (where → voice or manual); bulk CSV import lives on /add-entry.
/// Types are gated by the same RoleManager checks as the Add Entry page.
Future<void> showLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Bt.card,
    barrierColor: Bt.scrim,
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 520), curve: Bt.ease, reverseDuration: Duration(milliseconds: 260)),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Bt.rSheet))),
    builder: (ctx) => SafeArea(top: false, child: _LogSheet(parentContext: context)),
  );
}

/// One entry-type choice: (type id, title, short description).
const logEntryKinds = <(String, String, String)>[
  ('material', 'Material', 'Cement, steel, bricks & site items'),
  ('labour', 'Labour', 'Crew, hours, wages'),
  ('equipment', 'Equipment', 'Machines, fuel, hire'),
];

/// Same permission gates as the Add Entry page's type list.
bool logKindAllowed(String type) {
  switch (type) {
    case 'material':
      return RoleManager.canManageExpenses;
    case 'labour':
      return RoleManager.canAddEntries;
    case 'equipment':
      return RoleManager.canManageEquipmentMaster;
  }
  return false;
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.parentContext});
  final BuildContext parentContext;
  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  String? _picked;

  void _pick(String type) {
    if (_picked != null) return;
    setState(() => _picked = type);
    final nav = Navigator.of(context);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      nav.pop();
      nav.pushNamed('/execution-context', arguments: {'type': type});
    });
  }

  @override
  Widget build(BuildContext context) {
    final kinds = logEntryKinds.where((k) => logKindAllowed(k.$1)).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Bt.inputBorder, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NEW ENTRY', style: BtText.mono(context, color: context.bt.accentInk)),
              const SizedBox(height: 4),
              Text('What are you logging?', style: BtText.d2(context)),
            ]),
          ),
          BtIconButton(icon: Icons.close_rounded, size: 18, semantic: 'Close', background: Bt.fill, onTap: () => Navigator.of(context).maybePop()),
        ]),
        const SizedBox(height: 20),
        if (kinds.isNotEmpty)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < kinds.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: BtReveal(
                  index: i,
                  child: LogKindTile(
                    type: kinds[i].$1,
                    title: kinds[i].$2,
                    subtitle: kinds[i].$3,
                    selected: _picked == kinds[i].$1,
                    onTap: () => _pick(kinds[i].$1),
                  ),
                ),
              ),
            ],
          ]),
        const SizedBox(height: 14),
        BtReveal(
          index: 4,
          child: _ImportRow(
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(widget.parentContext).pushNamed('/add-entry');
            },
          ),
        ),
        if (kinds.isNotEmpty) ...[
          const SizedBox(height: 14),
          BtReveal(index: 5, child: Text('Tap a type to continue', textAlign: TextAlign.center, style: BtText.caption(context))),
        ],
      ]),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return BtPressable(
      onTap: onTap,
      scale: .98,
      semanticLabel: 'Import many from a spreadsheet',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Bt.inputBorder)),
        child: Row(children: [
          const BtTile(icon: Icons.upload_file_outlined, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Import many at once', style: BtText.body(context, weight: FontWeight.w600)),
              Text('From a CSV spreadsheet', style: BtText.caption(context, color: Bt.ink2)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Bt.ink3),
        ]),
      ),
    );
  }
}

/// Tall entry-type tile with a small line illustration (bags / hard hat /
/// excavator). Shared by the log sheet and the Add Entry page.
class LogKindTile extends StatelessWidget {
  const LogKindTile({super.key, required this.type, required this.title, required this.subtitle, required this.onTap, this.selected = false, this.height = 178});
  final String type;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bt = context.bt;
    final reduce = Bt.reduceMotion(context);
    return BtPressable(
      onTap: onTap,
      scale: .96,
      semanticLabel: title,
      child: AnimatedContainer(
        duration: Bt.fast,
        curve: Bt.ease,
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Bt.ink : Bt.ground,
          borderRadius: BorderRadius.circular(Bt.rCard),
          border: selected ? null : Border.all(color: Bt.line),
          boxShadow: selected ? const [BoxShadow(color: Color(0x990C0E12), blurRadius: 30, spreadRadius: -16, offset: Offset(0, 18))] : null,
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            SizedBox(
              height: 62,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduce ? 1 : 0, end: 1),
                    duration: reduce ? Duration.zero : const Duration(milliseconds: 1100),
                    builder: (_, t, _) => CustomPaint(
                      size: const Size(72, 56),
                      painter: _KindArt(
                        kind: type,
                        t: t,
                        stroke: selected ? Bt.bone : Bt.ink,
                        accStroke: selected ? bt.accent : bt.accentInk,
                        accFill: selected ? bt.accent.withValues(alpha: .22) : bt.accentSoft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, maxLines: 1, style: BtText.headline(context).copyWith(color: selected ? Bt.bone : Bt.ink))),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: BtText.caption(context, color: selected ? Bt.onNoir2 : Bt.ink2).copyWith(fontSize: 12)),
            ]),
          ]),
          Positioned(
            top: 0,
            right: 0,
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: Bt.fast,
              curve: Bt.spring,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: bt.accent, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 15, color: bt.onAccent),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Line art drawn in a 72×56 box (matches the board SVGs).
class _KindArt extends CustomPainter {
  _KindArt({required this.kind, required this.t, required this.stroke, required this.accStroke, required this.accFill});
  final String kind;
  final double t;
  final Color stroke;
  final Color accStroke;
  final Color accFill;

  /// Bag drop: falls from above with a small bounce, staggered by [delay].
  double _drop(double delay) {
    final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    return -36 * (1 - Bt.spring.transform(local));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final acc = Paint()
      ..color = accStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = accFill;

    canvas.drawLine(const Offset(2, 54), const Offset(70, 54), line);

    void accPath(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, acc);
    }

    switch (kind) {
      case 'labour':
        final rise = 6 * (1 - Bt.ease.transform(t));
        canvas.save();
        canvas.translate(0, rise);
        canvas.drawRect(const Rect.fromLTWH(14, 44, 44, 5), line);
        accPath(Path()
          ..moveTo(18, 44)
          ..arcToPoint(const Offset(54, 44), radius: const Radius.circular(18))
          ..close());
        canvas.drawPath(Path()
          ..moveTo(31, 27)
          ..lineTo(31, 21)
          ..lineTo(41, 21)
          ..lineTo(41, 27), line);
        canvas.drawLine(const Offset(36, 21), const Offset(36, 44), line);
        canvas.restore();
        break;
      case 'equipment':
        final dx = -8 * (1 - Bt.ease.transform(t));
        canvas.save();
        canvas.translate(dx, 0);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 44, 36, 9), const Radius.circular(4.5)), line);
        accPath(Path()..addRect(const Rect.fromLTRB(8, 30, 30, 44)));
        canvas.drawPath(Path()
          ..moveTo(30, 34)
          ..lineTo(46, 16)
          ..lineTo(60, 26)
          ..lineTo(56, 36), line);
        canvas.drawPath(Path()
          ..moveTo(56, 36)
          ..lineTo(48, 36)
          ..lineTo(52, 44), line);
        canvas.restore();
        break;
      default:
        final bags = [
          (const Rect.fromLTWH(6, 38, 28, 15), false, 0.0),
          (const Rect.fromLTWH(38, 38, 28, 15), false, .12),
          (const Rect.fromLTWH(22, 21, 28, 15), true, .24),
        ];
        for (final b in bags) {
          final dy = _drop(b.$3);
          final r = RRect.fromRectAndRadius(b.$1.shift(Offset(0, dy)), const Radius.circular(5));
          final visible = t > b.$3;
          if (!visible) continue;
          if (b.$2) {
            canvas.drawRRect(r, fill);
            canvas.drawRRect(r, acc);
          } else {
            canvas.drawRRect(r, line);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_KindArt o) => o.t != t || o.stroke != stroke || o.accStroke != accStroke || o.accFill != accFill || o.kind != kind;
}
