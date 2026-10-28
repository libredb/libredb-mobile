import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_sizes.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// Holds `docs/design-system.md` to the code it describes.
///
/// That page exists to be cited: M16's review layer judges this app's visual consistency against the design
/// system, and a finding that cites nothing is taste rather than a finding. A page of values that has quietly
/// drifted from the code is worse than no page at all — it makes a wrong citation look like a right one — so the
/// page is held here rather than trusted (#283).
///
/// Three things are checked, and they are the three a reader of that page relies on: that every `file:line` it
/// cites exists, that every colour it prints is the colour the app ships, and that every number it prints is the
/// number the token holds.
void main() {
  final page = File('docs/design-system.md').readAsStringSync();

  test('every file:line the page cites exists', () {
    // `path/to/file.dart:12` or `:12-34`, as the page writes them inside backticks.
    final citations = RegExp(r'`((?:[a-z_/]+/)?[a-z_]+\.dart):(\d+)(?:-(\d+))?`').allMatches(page);
    expect(citations, isNotEmpty, reason: 'the page is meant to be cited; a page with no citations is a defect');

    final broken = <String>[];
    for (final citation in citations) {
      final name = citation.group(1)!;
      // The page names files by their path under `lib/` or by their basename once the section has given the
      // directory. Resolve both.
      final candidates = [
        File(name),
        File('lib/$name'),
        File('lib/shared/design_system/theme/$name'),
        File('lib/shared/design_system/tokens/$name'),
      ];
      final file = candidates.where((candidate) => candidate.existsSync()).firstOrNull;
      if (file == null) {
        broken.add('${citation.group(0)} — no such file');
        continue;
      }
      final lines = file.readAsLinesSync().length;
      final last = int.parse(citation.group(3) ?? citation.group(2)!);
      if (last > lines) broken.add('${citation.group(0)} — ${file.path} has only $lines lines');
    }
    expect(broken, isEmpty, reason: 'citations that lead nowhere:\n${broken.join('\n')}');
  });

  test('every colour the page prints for classic is the colour classic ships', () {
    // The page's `classic` table is one row per role: | `role` | `#LIGHT` | `#DARK` | note |
    final rows = RegExp(r'^\| `([a-zA-Z]+)` \| `#([0-9A-F]{6})` \| `#([0-9A-F]{6})` \|', multiLine: true);
    final light = ThemeColors.getColorScheme(AppThemePalette.classic, Brightness.light);
    final dark = ThemeColors.getColorScheme(AppThemePalette.classic, Brightness.dark);
    Color? read(ColorScheme s, String role) => switch (role) {
      'primary' => s.primary,
      'onPrimary' => s.onPrimary,
      'primaryContainer' => s.primaryContainer,
      'onPrimaryContainer' => s.onPrimaryContainer,
      'secondary' => s.secondary,
      'onSecondary' => s.onSecondary,
      'secondaryContainer' => s.secondaryContainer,
      'onSecondaryContainer' => s.onSecondaryContainer,
      'tertiary' => s.tertiary,
      'onTertiary' => s.onTertiary,
      'tertiaryContainer' => s.tertiaryContainer,
      'onTertiaryContainer' => s.onTertiaryContainer,
      'error' => s.error,
      'onError' => s.onError,
      'errorContainer' => s.errorContainer,
      'onErrorContainer' => s.onErrorContainer,
      'surface' => s.surface,
      'onSurface' => s.onSurface,
      'surfaceContainerHighest' => s.surfaceContainerHighest,
      'onSurfaceVariant' => s.onSurfaceVariant,
      'outline' => s.outline,
      'outlineVariant' => s.outlineVariant,
      'inverseSurface' => s.inverseSurface,
      'onInverseSurface' => s.onInverseSurface,
      'inversePrimary' => s.inversePrimary,
      'surfaceTint' => s.surfaceTint,
      _ => null,
    };
    String hex(Color c) => (c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');

    final wrong = <String>[];
    var checked = 0;
    for (final row in rows.allMatches(page)) {
      final role = row.group(1)!;
      final onLight = read(light, role);
      final onDark = read(dark, role);
      if (onLight == null || onDark == null) continue; // a row of some other table
      checked++;
      if (hex(onLight) != row.group(2)) wrong.add('$role light: page #${row.group(2)}, code #${hex(onLight)}');
      if (hex(onDark) != row.group(3)) wrong.add('$role dark: page #${row.group(3)}, code #${hex(onDark)}');
    }

    expect(checked, 26, reason: 'the page prints all 26 roles of the classic scheme; it printed $checked');
    expect(wrong, isEmpty, reason: 'the page and the code disagree:\n${wrong.join('\n')}');
  });

  test('every number the page prints is the number the token holds', () {
    final wrong = <String>[];
    void check(String what, Object expected) {
      if (!page.contains(what)) wrong.add('the page does not print $what, which is $expected');
    }

    // Space, shape and size, as the page's tables write them.
    const spacing = <double>[
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
      AppSpacing.xxxl,
      AppSpacing.xxxxl,
      AppSpacing.xxxxxl,
    ];
    check('| spacing | ${spacing.map((step) => step.round()).join(', ')} |', 'the spacing scale');
    check(
      '| radius | ${AppRadius.sm.round()}, ${AppRadius.md.round()}, ${AppRadius.lg.round()}, '
          '${AppRadius.xl.round()}, pill ${AppRadius.pill.round()} |',
      'the radius scale',
    );
    check(
      '| breakpoints | ${AppBreakpoints.mobile.round()}, ${AppBreakpoints.tablet.round()}, '
          '${AppBreakpoints.desktop.round()} |',
      'the breakpoints',
    );
    check('`AppSizes.minTapTarget` is ${AppSizes.minTapTarget.round()}', 'the tap target');
    check('`minDenseTarget` of ${AppSizes.minDenseTarget.round()}', 'the dense target');

    // Motion.
    for (final (name, duration) in [
      ('instant', AppDurations.instant),
      ('fast', AppDurations.fast),
      ('normal', AppDurations.normal),
      ('slow', AppDurations.slow),
      ('media', AppDurations.media),
    ]) {
      check('| `$name` | ${duration.inMilliseconds}ms |', 'the $name duration');
    }
    for (final (name, curve) in [
      ('easeOut', AppDurations.easeOut),
      ('easeIn', AppDurations.easeIn),
      ('easeInOut', AppDurations.easeInOut),
    ]) {
      final cubic = curve as Cubic;
      // The page quotes the literal the source writes, where a whole number has no `.0`.
      String short(double value) => value == value.roundToDouble() ? '${value.round()}' : '$value';
      check(
        '| `$name` | `Cubic(${short(cubic.a)}, ${short(cubic.b)}, ${short(cubic.c)}, ${short(cubic.d)})` |',
        'the $name curve',
      );
    }

    // The two faces.
    check("`${AppTypography.sans}` (`:9`)", 'the sans family');
    check("`${AppTypography.mono}` (`:13`)", 'the mono family');

    expect(wrong, isEmpty, reason: 'the page and the code disagree:\n${wrong.join('\n')}');
  });
}
