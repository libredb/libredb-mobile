import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Which way the skeleton's shimmer runs.
///
/// A shimmer is a light sweeping over something darker. The placeholder took `surfaceContainerHighest` as its base
/// and `surface` as its highlight, which is the right way round in a light scheme and backwards in a dark one, where
/// `surface` is the darkest colour there is: the sweep was a shadow (#373).
void main() {
  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.name} in ${brightness.name} sweeps a light over a darker base', () {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        expect(
          skeletonHighlight(scheme).computeLuminance(),
          greaterThan(skeletonBase(scheme).computeLuminance()),
          reason: 'the highlight is darker than what it sweeps over, so the placeholder pulses the wrong way',
        );
      });
    }
  }
}
