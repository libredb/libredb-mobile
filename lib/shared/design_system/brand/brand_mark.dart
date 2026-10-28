import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/brand/svg_path.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_gradients.dart';

/// The product's brand mark: a hexagon frame around three data rows, between two chevrons.
///
/// The geometry is the design system's own, copied from `tool/design-system/assets/lb-icon.svg` — itself a
/// verbatim copy of `design-system/assets/lb-icon.svg` in `libredb/libredb.github.io`. The copy is here rather
/// than loaded as an asset because the mark is drawn synchronously, in a frame, by widgets that have nothing to
/// wait on; `brand_mark_test.dart` reads the SVG and fails when these stop being what it declares.
///
/// It is painted rather than rendered. The app carries no SVG renderer, and the one shape it needs is this one,
/// so `parseSvgPath` understands the nine commands this file is written in and nothing else (#390).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.color});

  /// The width the mark is drawn at. Its height follows the design system's own ratio.
  final double size;

  /// A single ink for the whole mark, for the grounds the gradients cannot be read on. Null paints it in the two
  /// gradients the system draws it with.
  final Color? color;

  /// The viewBox of `lb-icon.svg`. Every coordinate below is in it.
  static const Size viewBox = Size(549.37, 600);

  /// The hexagon frame, filled with `--gradient-brand`.
  static const String frame =
      'M274.68,600c-19.18,0-38.36-4.92-55.46-14.76l-163.74-94.6C21.26,470.95,0,434.1,0,394.49v-18'
      '8.97c0-39.62,21.26-76.46,55.5-96.16L219.2,14.77c34.23-19.69,76.74-19.69,110.96,0h.02s163.7'
      '2,94.6,163.72,94.6c34.21,19.69,55.48,56.53,55.48,96.15v188.97c0,39.62-21.27,76.46-55.5,96.'
      '16l-163.7,94.58c-17.12,9.85-36.31,14.77-55.49,14.77ZM274.69,19.89c-15.75,0-31.5,4.04-45.54'
      ',12.12L65.44,126.6c-28.09,16.16-45.54,46.4-45.54,78.91v188.97c0,32.52,17.44,62.75,45.52,78'
      '.91l163.74,94.6c28.08,16.15,62.98,16.16,91.07,0l163.7-94.58c28.09-16.16,45.54-46.4,45.54-7'
      '8.91v-188.97c0-32.52-17.44-62.75-45.52-78.91l-163.72-94.6c-14.04-8.08-29.79-12.12-45.54-12'
      '.12Z';

  /// The three data rows inside it, filled with `--gradient-brand`.
  static const List<Rect> rows = [
    Rect.fromLTWH(159.97, 229.91, 229.21, 31.03),
    Rect.fromLTWH(159.97, 284.48, 229.21, 31.03),
    Rect.fromLTWH(159.97, 339.06, 229.21, 31.03),
  ];

  /// The corner of a data row.
  static const double rowRadius = 6.85;

  /// The two chevrons, filled with `--gradient-data`.
  static const List<String> chevrons = [
    'M136.02,426.06c-3.7,0-7.33-1.79-9.54-5.1l-76.4-114.71c-2.56-3.84-2.56-8.85,0-12.69l76.4-11'
        '4.71c3.5-5.26,10.61-6.69,15.88-3.18,5.26,3.51,6.69,10.61,3.18,15.88l-72.17,108.36,72.17,10'
        '8.36c3.51,5.26,2.08,12.37-3.18,15.88-1.95,1.3-4.16,1.92-6.34,1.92Z',
    'M413.14,426.06c-2.18,0-4.39-.62-6.34-1.92-5.26-3.51-6.69-10.61-3.18-15.88l72.17-108.36-72.'
        '17-108.36c-3.51-5.26-2.08-12.37,3.18-15.88,5.27-3.5,12.37-2.08,15.88,3.18l76.4,114.71c2.56'
        ',3.84,2.56,8.85,0,12.69l-76.4,114.71c-2.21,3.31-5.84,5.1-9.54,5.1Z',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * viewBox.height / viewBox.width,
      child: CustomPaint(painter: _BrandMarkPainter(color)),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / BrandMark.viewBox.width);

    final box = Offset.zero & BrandMark.viewBox;
    final brand = Paint()
      ..shader = color == null ? AppGradients.brand.createShader(box) : null
      ..color = color ?? const Color(0xFF000000);
    final data = Paint()
      ..shader = color == null ? AppGradients.data.createShader(box) : null
      ..color = color ?? const Color(0xFF000000);

    canvas.drawPath(parseSvgPath(BrandMark.frame), brand);
    for (final row in BrandMark.rows) {
      canvas.drawRRect(RRect.fromRectXY(row, BrandMark.rowRadius, BrandMark.rowRadius), brand);
    }
    for (final chevron in BrandMark.chevrons) {
      canvas.drawPath(parseSvgPath(chevron), data);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => oldDelegate.color != color;
}
