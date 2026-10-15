import 'package:buildtrack_mobile/design/bt_theme.dart';
import 'package:flutter/material.dart';

/// Redesign: the page background is a flat ground colour (no lavender, no glows).
class NurofinBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Bt.ground);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NurofinBackground extends StatelessWidget {
  const NurofinBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(color: Bt.ground, child: child);
}
