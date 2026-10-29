import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The engine marks the introduction's first screen draws, one per engine rather than one per family.
///
/// The app's shared `engineIcon` maps a *family*: `postgres` and `mysql` are both relational and get one table glyph,
/// which the connection list, the object browser and the switcher all rely on and `engine_icons_test.dart` pins. The
/// prototype's first screen does not group: its three rows are `[[PG,…],[MY,…],[PG,…]]` and `PG` and `MY` are two
/// different drawings. So the introduction carries its own marks and leaves the shared token alone.
///
/// Both are the prototype's own paths, in its own 24-unit viewBox, so the drawing is the SVG and not an impression
/// of it. `ob.html` draws them at `.crow .eng{width:17px;height:17px;color:var(--accent)}`; here the size is the
/// row's icon size and the colour the scheme's primary, both passed in by the row.
enum EngineMark {
  /// `PG`: a database cylinder — a top disc over a body with one band.
  ///
  /// ```svg
  /// <ellipse cx="12" cy="6" rx="7.5" ry="3" stroke-width="1.7"/>
  /// <path d="M4.5 6v12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3V6" stroke-width="1.7"/>
  /// <path d="M4.5 12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3" stroke-width="1.7"/>
  /// ```
  cylinder,

  /// `MY`: an arc rising to a filled dot.
  ///
  /// ```svg
  /// <path d="M3 18c3-6 6-9 9-9s6 3 9 9" stroke-width="1.7" stroke-linecap="round"/>
  /// <circle cx="12" cy="9" r="1.6" fill="currentColor"/>
  /// ```
  dolphin;

  /// The marked engines, by Studio's engine id. An id with no mark of its own is not drawn by this widget at all —
  /// see [EngineMarkIcon].
  static const _byType = {'postgres': EngineMark.cylinder, 'mysql': EngineMark.dolphin};

  /// The mark for Studio's engine [type], or null when the introduction has no drawing of its own for it. The type is
  /// an opaque string compared exactly, as everywhere else in the app.
  static EngineMark? of(String type) => _byType[type];

  /// The part of the mark that is drawn as a line, in the prototype's 24-unit viewBox.
  Path strokePath() => switch (this) {
    // `<ellipse cx="12" cy="6" rx="7.5" ry="3"/>`, then `M4.5 6v12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3V6`, then the band
    // `M4.5 12c0 1.7 3.4 3 7.5 3s7.5-1.3 7.5-3`. Each `s` is written out: its first control point is the reflection
    // of the previous curve's second, which is why the two cubics of a curve are not mirror images on paper.
    EngineMark.cylinder =>
      Path()
        ..addOval(Rect.fromCenter(center: const Offset(12, 6), width: 15, height: 6))
        ..moveTo(4.5, 6)
        ..lineTo(4.5, 18)
        ..cubicTo(4.5, 19.7, 7.9, 21, 12, 21)
        ..cubicTo(16.1, 21, 19.5, 19.7, 19.5, 18)
        ..lineTo(19.5, 6)
        ..moveTo(4.5, 12)
        ..cubicTo(4.5, 13.7, 7.9, 15, 12, 15)
        ..cubicTo(16.1, 15, 19.5, 13.7, 19.5, 12),
    // `M3 18c3-6 6-9 9-9s6 3 9 9`.
    EngineMark.dolphin =>
      Path()
        ..moveTo(3, 18)
        ..cubicTo(6, 12, 9, 9, 12, 9)
        ..cubicTo(15, 9, 18, 12, 21, 18),
  };

  /// The part of the mark that is filled, in the same viewBox; empty for a mark that has none.
  Path fillPath() => switch (this) {
    EngineMark.cylinder => Path(),
    // `<circle cx="12" cy="9" r="1.6" fill="currentColor"/>`.
    EngineMark.dolphin => Path()..addOval(Rect.fromCircle(center: const Offset(12, 9), radius: 1.6)),
  };
}

/// The side of the viewBox every path above is written in.
const _viewBox = 24.0;

/// `stroke-width="1.7"`, in viewBox units: the canvas is scaled, so the width scales with the drawing.
const _strokeWidth = 1.7;

/// An [EngineMark] drawn at [size] in [color], or, for an engine the introduction has no mark for, the app's shared
/// family icon — so a fourth demo row added later draws something rather than nothing.
class EngineMarkIcon extends StatelessWidget {
  const EngineMarkIcon({required this.type, required this.color, this.size = AppSizes.iconMd, super.key});

  /// Studio's engine id, an opaque string.
  final String type;

  final Color color;
  final double size;

  /// Reports the *mark*, not the engine, so that what a test reads off this widget is what it draws: two engines of
  /// one mark describe themselves identically, and a test cannot pass on the engine's name alone.
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<EngineMark>('mark', EngineMark.of(type)))
      ..add(ColorProperty('color', color))
      ..add(DoubleProperty('size', size));
  }

  @override
  Widget build(BuildContext context) {
    final mark = EngineMark.of(type);
    if (mark == null) return Icon(engineIcon(type), size: size, color: color);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _EngineMarkPainter(mark: mark, color: color),
      ),
    );
  }
}

class _EngineMarkPainter extends CustomPainter {
  const _EngineMarkPainter({required this.mark, required this.color});

  final EngineMark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _viewBox, size.height / _viewBox)
      ..drawPath(
        mark.strokePath(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          // `stroke-linecap="round"` on MY's arc; the cylinder's ends meet a line, so the cap is not visible there.
          ..strokeCap = StrokeCap.round
          ..color = color,
      )
      ..drawPath(mark.fillPath(), Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_EngineMarkPainter oldDelegate) => oldDelegate.mark != mark || oldDelegate.color != color;

  /// So a test can ask whether two rows draw the same mark, which is the whole claim of this file.
  @override
  bool operator ==(Object other) => other is _EngineMarkPainter && other.mark == mark && other.color == color;

  @override
  int get hashCode => Object.hash(mark, color);

  @override
  String toString() => 'EngineMark.${mark.name}($color)';
}
