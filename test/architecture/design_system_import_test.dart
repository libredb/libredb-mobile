import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_sizes.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// Holds the app's tokens against the design system they were imported from.
///
/// `tool/design-system/tokens/` is a verbatim copy of `design-system/tokens/` in `libredb/libredb.github.io`, taken
/// at `857d454`; `tool/design-system/SOURCE.md` records the stamp and how to refresh it. A copy rather than a
/// reference because the site's repository is not checked out on CI, and the copy is what makes a later drift
/// *detectable* rather than merely possible to look up (#283).
///
/// What this file asserts is the relationship that was **measured** when the system was imported, not a wish. Two of
/// the three are containment — the app's scales turned out to sit inside the web's, so adopting the web scale adds
/// steps and breaks nothing — and the third is a deviation the owner ruled on, pinned here so it cannot be quietly
/// reversed in either direction.
void main() {
  /// The px values of every `--prefix…` custom property in [file], a vendored token file. A value in another unit —
  /// `50%` for `--radius-circle`, `1.02` for a line height — is not a px value and is left out.
  Set<int> pixelsOf(String file, String prefix) {
    final source = File('tool/design-system/tokens/$file').readAsStringSync();
    final declarations = RegExp('--$prefix[a-z0-9-]*\\s*:\\s*([0-9]+)px', caseSensitive: false);
    return {
      for (final match in declarations.allMatches(source)) int.parse(match.group(1)!),
      // `--space-0:0` and `--radius-none:0` carry no unit, because zero needs none.
      if (RegExp('--$prefix[a-z0-9-]*\\s*:\\s*0\\s*;').hasMatch(source)) 0,
    };
  }

  test('the vendored token files are all there', () {
    const expected = [
      'base',
      'colors',
      'elevation',
      'fonts',
      'layout',
      'motion',
      'shape',
      'spacing',
      'theme',
      'typography',
    ];
    final present =
        Directory('tool/design-system/tokens')
            .listSync()
            .map((entry) => entry.path.split('/').last)
            .where((name) => name.endsWith('.css'))
            .map((name) => name.substring(0, name.length - 4))
            .toList()
          ..sort();

    expect(present, expected, reason: 'a file that goes missing takes its half of every check below with it, silently');
  });

  test('every spacing step the app defines is one the design system defines', () {
    // `formMaxWidth*` is left out on purpose: 200/400/600/800 are content measures, the counterpart of the web's
    // `--container-*` and `--measure-*`, not steps on the spacing scale.
    const appSteps = <double>[
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
    final web = pixelsOf('spacing.css', 'space-');

    expect(
      appSteps.map((step) => step.round()).where((step) => !web.contains(step)),
      isEmpty,
      reason:
          'the app scale {4,8,12,16,24,32,40,48,64} sits inside the web scale, which also has 2, 20 and the '
          'steps above 64 — so moving to the web scale adds steps and invalidates no layout',
    );
  });

  test('every corner radius the app defines is one the design system defines', () {
    const appRadii = <double>[AppRadius.sm, AppRadius.md, AppRadius.lg, AppRadius.xl, AppRadius.pill];
    final web = pixelsOf('shape.css', 'radius-');

    expect(
      appRadii.map((radius) => radius.round()).where((radius) => !web.contains(radius)),
      isEmpty,
      reason: 'the app has {4,6,8,12,999} and the web adds 16 for a modal or sheet and 24 for section media',
    );
  });

  /// The millisecond value of `--duration-<name>` in the vendored motion tokens.
  int durationOf(String name) {
    final source = File('tool/design-system/tokens/motion.css').readAsStringSync();
    // The first match only: the file redeclares every duration as 0ms under `prefers-reduced-motion`.
    final declaration = RegExp('--duration-$name\\s*:\\s*([0-9]+)ms').firstMatch(source);
    return int.parse(declaration!.group(1)!);
  }

  test('the app animates for as long as the design system says', () {
    expect(AppDurations.fast.inMilliseconds, durationOf('fast'));
    expect(
      AppDurations.normal.inMilliseconds,
      durationOf('normal'),
      reason: 'a dropdown, an accordion and a card lift are the same gesture on both surfaces',
    );
    expect(AppDurations.slow.inMilliseconds, durationOf('slow'));
    expect(
      AppDurations.instant.inMilliseconds,
      durationOf('instant'),
      reason: 'a state colour change is its own duration; the app had no name for it and reached for fast',
    );
    expect(
      AppDurations.media.inMilliseconds,
      durationOf('media'),
      reason: 'the one duration that belongs to a picture rather than to a control',
    );
  });

  /// The four control points of `--ease-<name>` in the vendored motion tokens.
  List<double> easeOf(String name) {
    final source = File('tool/design-system/tokens/motion.css').readAsStringSync();
    final declaration = RegExp('--ease-$name\\s*:\\s*cubic-bezier\\(([^)]*)\\)').firstMatch(source);
    return declaration!.group(1)!.split(',').map((part) => double.parse(part.trim())).toList();
  }

  test('the app eases the way the design system eases', () {
    // `--ease-spring` is deliberately absent: it overshoots (1.56), which `Cubic` can express but nothing in this
    // app asks for, and an unused curve is a value nobody is holding to anything. It arrives with its first caller.
    for (final (name, curve) in [
      ('out', AppDurations.easeOut),
      ('in', AppDurations.easeIn),
      ('in-out', AppDurations.easeInOut),
    ]) {
      final web = easeOf(name);
      expect(
        curve,
        isA<Cubic>(),
        reason: "Flutter's own Curves are not the product's: --ease-$name is a cubic-bezier the system picked",
      );
      final cubic = curve as Cubic;
      expect([cubic.a, cubic.b, cubic.c, cubic.d], web, reason: 'the control points of --ease-$name');
    }
  });

  test('the app breaks its layout where the design system does', () {
    final breakpoints = pixelsOf('layout.css', 'bp-');

    expect(AppBreakpoints.mobile.round(), 768, reason: '--bp-md, the tablet edge');
    expect(AppBreakpoints.tablet.round(), 1024, reason: '--bp-lg, the laptop edge');
    expect(
      AppBreakpoints.desktop.round(),
      1280,
      reason: 'the app had 1280 as 1200, which is on no scale either side; --bp-xl is 1280',
    );
    expect(breakpoints, containsAll(<int>[768, 1024, 1280]));
  });

  test('the tap target deviates from the design system, deliberately', () {
    final web = pixelsOf('layout.css', 'touch-target-');

    expect(web, contains(44), reason: 'if the web floor moves, this ruling is worth revisiting');
    expect(
      AppSizes.minTapTarget,
      48.0,
      reason:
          'the owner ruled the app keeps 48: 44 is the floor Apple asks for, this app ships on Android, and '
          '#373 measured what 48 costs in a dense list and answered it with minDenseTarget instead of lowering it. '
          'Pinned in both directions — following the web here would be a regression, not an import',
    );
  });
}
