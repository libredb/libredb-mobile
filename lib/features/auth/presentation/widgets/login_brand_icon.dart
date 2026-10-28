import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/brand/brand_mark.dart';

/// The product mark the login page shows above its heading.
///
/// Its own file so the identity work of M15 has one place to change the mark, rather than a method inside a 655-line
/// page (#379). This is that change: it was `Icons.bolt_rounded` in a bordered tile — a stock Material lightning
/// bolt, which says "some app" and names no product — and it is now the mark the design system draws, in the two
/// gradients it draws it with (#284).
///
/// The tile went with the glyph. The mark carries its own frame, so a square around it was a second border around a
/// shape that already has one; what the tile was really doing was giving a featureless glyph some presence.
class LoginBrandIcon extends StatelessWidget {
  const LoginBrandIcon({super.key, required this.isDark});

  /// Kept because the page passes it and the mark may yet need a different ink on one of the two grounds. It does
  /// not today: the gradients are the same on both, which is what makes them the brand's rather than the theme's.
  final bool isDark;

  /// The height the heading was laid out around, when the mark was a 44 pt tile. The mark is taller than it is
  /// wide, so the width follows from this rather than the other way round.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return BrandMark(size: height * BrandMark.viewBox.width / BrandMark.viewBox.height);
  }
}
