import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Guards the quiet text this app fades with an alpha.
///
/// `container_contrast_test.dart` measures the roles themselves. It cannot see this: an alpha is applied where the
/// text is written, not in the scheme, so `onSurfaceVariant` can clear its floor everywhere and a hint drawn with
/// 60% of it still be unreadable. Four places faded one and all four failed — the hint of every text field at
/// 2.82:1 on a card, the build number with it, the community subtitle at 3.49:1 and the result header's type at
/// 4.38:1 (#386).
///
/// No alpha fixes them. In `nature` light and `sunset` light **no** value in 0-255 clears 4.5:1 on a container,
/// because the role itself is only 4.5 there to begin with, so the fade was removed rather than tuned. Material 3's
/// own `InputDecoration` hint is `onSurfaceVariant` at full opacity, which is where the hint landed.
///
/// The guard reads the alpha out of the source rather than holding a list of known values, so it measures what the
/// code does today and a fade added tomorrow is measured the moment it is written. [_decorative] is the only way
/// out, and each entry carries its reason, because an exemption nobody wrote down is indistinguishable from an
/// oversight.
void main() {
  const decorative = <String, String>{
    'lib/app/dev_console/dev_console_overlay.dart': 'a debug overlay, which no release build carries',
    'lib/shared/widgets/theme_selection_dialog.dart': 'bars that stand for text inside a miniature of a theme',
  };

  /// `onSurfaceVariant.withAlpha(153)` and `onSurface.withValues(alpha: 0.7)`, as the fraction they paint with.
  final fade = RegExp(
    r'(?:onSurfaceVariant|onSurface)\s*\.\s*with(?:Alpha\(\s*(\d+)\s*\)|Values\(\s*alpha:\s*([\d.]+)\s*\))',
  );

  List<(String, double)> faded() {
    final found = <(String, double)>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (decorative.containsKey(file.path)) continue;
      for (final match in fade.allMatches(file.readAsStringSync())) {
        final alpha = match.group(1) != null ? int.parse(match.group(1)!) / 255 : double.parse(match.group(2)!);
        found.add((file.path, alpha));
      }
    }
    return found;
  }

  test('the files that fade a quiet role decoratively are the ones written down here', () {
    // The exemptions are checked in the other direction too: a file that stops fading has no reason to stay on a
    // list of exemptions, and a list nobody prunes stops meaning anything.
    for (final MapEntry(key: path, value: reason) in decorative.entries) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is exempt but does not exist');
      expect(
        fade.hasMatch(file.readAsStringSync()),
        isTrue,
        reason: '$path no longer fades a quiet role, so it does not need the exemption "$reason"',
      );
    }
  });

  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      test('${palette.name} in ${brightness.name}: every faded quiet role can still be read', () {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final under = <String>[];

        // A text field sits on the page and inside a card, and the result header fills with a container, so each
        // fade is measured against the worst ground the app offers it rather than the kindest.
        final grounds = <String, Color>{
          'the page': scheme.surface,
          'a high container': scheme.surfaceContainerHigh,
          'the highest container': scheme.surfaceContainerHighest,
        };

        for (final (path, alpha) in faded()) {
          for (final MapEntry(key: where, value: ground) in grounds.entries) {
            final painted = Color.alphaBlend(scheme.onSurfaceVariant.withValues(alpha: alpha), ground);
            final ratio = contrastRatio(painted, ground);
            if (ratio < 4.5) {
              under.add('$path fades to $alpha: ${ratio.toStringAsFixed(2)}:1 on $where, floor 4.5:1');
            }
          }
        }

        expect(under, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${under.join('\n')}');
      });
    }
  }
}
