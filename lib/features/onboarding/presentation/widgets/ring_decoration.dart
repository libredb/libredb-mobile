import 'package:flutter/material.dart';

/// The ring that runs out of a box when it pops: the prototype's `.ring{position:absolute;inset:0;border:1.5px solid
/// var(--accent);opacity:0}` with `.ring.go{animation:ringOut .7s}`, `0% {opacity:.85; scale 1}` to `100% {opacity:0;
/// scale 1.13}`.
///
/// A [Decoration], used as a `foregroundDecoration`, so it is painted rather than laid out: it draws past the box it
/// belongs to without being a box that is wider than the hero.
class RingDecoration extends Decoration {
  const RingDecoration({required this.color, required this.progress, required this.radius});

  /// The ring's colour at full strength, the accent.
  final Color color;

  /// How far the ring has run, 0 to 1.
  final double progress;

  /// The corner radius of the ring, which is the box's own less its border.
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _RingPainter(color, progress, radius);
}

/// The ring's opacity at the start, its width and how much it grows over its run.
const _opacity = 0.85;
const _width = 1.5;
const _growth = 0.13;

class _RingPainter extends BoxPainter {
  _RingPainter(this.color, this.progress, this.radius);

  final Color color;
  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final rect = (offset & size).deflate(1);
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(1 + _growth * eased)
      ..translate(-rect.center.dx, -rect.center.dy)
      ..drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _width
          ..color = color.withValues(alpha: _opacity * (1 - progress)),
      )
      ..restore();
  }
}
