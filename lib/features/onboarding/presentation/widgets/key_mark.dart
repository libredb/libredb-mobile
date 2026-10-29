import 'package:flutter/material.dart';

/// The key the introduction draws on Studio's box: the prototype's own `.key` svg, not Material's padlock.
///
/// ```svg
/// <svg viewBox="0 0 24 24" fill="none">
///   <circle cx="8.5" cy="15.5" r="4" stroke="currentColor" stroke-width="1.9"/>
///   <path d="m11.4 12.6 7.6-7.6M16.2 7.8l2.2 2.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
/// </svg>
/// ```
///
/// Drawn from its paths at [size] in [color], so the shape is the SVG's and not an impression of it.
class KeyMark extends StatelessWidget {
  const KeyMark({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _KeyPainter(color)),
  );
}

/// The side of the viewBox the paths are written in, and the stroke width in its units.
const _viewBox = 24.0;
const _strokeWidth = 1.9;

class _KeyPainter extends CustomPainter {
  const _KeyPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    // `m11.4 12.6 7.6-7.6` is the shaft to (19, 5); `M16.2 7.8l2.2 2.2` is the tooth from (16.2, 7.8) to (18.4, 10).
    final path = Path()
      ..moveTo(11.4, 12.6)
      ..lineTo(19, 5)
      ..moveTo(16.2, 7.8)
      ..lineTo(18.4, 10);
    canvas
      ..save()
      ..scale(size.width / _viewBox, size.height / _viewBox)
      ..drawCircle(const Offset(8.5, 15.5), 4, stroke)
      ..drawPath(path, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_KeyPainter oldDelegate) => oldDelegate.color != color;
}
