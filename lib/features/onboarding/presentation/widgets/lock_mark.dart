import 'package:flutter/material.dart';

/// The padlock the introduction draws, which is the prototype's own `LOCK` svg and not Material's `lock_outline`.
///
/// ```svg
/// <svg viewBox="0 0 24 24" fill="none">
///   <rect x="5" y="11" width="14" height="9" rx="2" stroke="currentColor" stroke-width="2"/>
///   <path d="M8.5 11V8.5a3.5 3.5 0 1 1 7 0V11" stroke="currentColor" stroke-width="2"/>
/// </svg>
/// ```
///
/// Drawn from its paths, so the shape is the SVG's and not an impression of it, at [size] in [color].
class LockMark extends StatelessWidget {
  const LockMark({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LockPainter(color)),
  );
}

/// The side of the viewBox the paths are written in, and the stroke width in its units.
const _viewBox = 24.0;
const _strokeWidth = 2.0;

class _LockPainter extends CustomPainter {
  const _LockPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..color = color;
    final shackle = Path()
      ..moveTo(8.5, 11)
      ..lineTo(8.5, 8.5)
      // `a3.5 3.5 0 1 1 7 0`: the large arc, clockwise, over the top to x 15.5.
      ..arcToPoint(const Offset(15.5, 8.5), radius: const Radius.circular(3.5), largeArc: true)
      ..lineTo(15.5, 11);
    canvas
      ..save()
      ..scale(size.width / _viewBox, size.height / _viewBox)
      ..drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5, 11, 14, 9), const Radius.circular(2)), stroke)
      ..drawPath(shackle, stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_LockPainter oldDelegate) => oldDelegate.color != color;
}
