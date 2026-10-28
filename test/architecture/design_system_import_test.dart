import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_gradients.dart';
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

  /// The colour `--<token>` carries in [brightness]'s scope of the vendored `theme.css`.
  ///
  /// The file is two blocks: `:root` is light and `[data-theme="dark"]` flips the scope, so a token is read out of
  /// the half that applies rather than by first match — six of them are declared in both halves with different
  /// values, and reading the wrong half is the one mistake this helper exists to make impossible.
  Color colourOf(String token, Brightness brightness) {
    final source = File('tool/design-system/tokens/theme.css').readAsStringSync();
    // The selector where it starts a line, not the first mention: the file's own header comment says
    // '[data-theme="dark"] on any ancestor flips the scope', and splitting there leaves the light half empty.
    final darkAt = RegExp(r'^\[data-theme="dark"\]', multiLine: true).firstMatch(source)!.start;
    final scope = brightness == Brightness.light ? source.substring(0, darkAt) : source.substring(darkAt);
    final declaration = RegExp('--$token\\s*:\\s*#([0-9a-fA-F]{6})\\s*;').firstMatch(scope);
    expect(declaration, isNotNull, reason: '--$token is not declared in the ${brightness.name} scope of theme.css');
    return Color(0xFF000000 | int.parse(declaration!.group(1)!, radix: 16));
  }

  test('every palette takes its brand colour from the design system', () {
    // The owner's ruling, 2026-10-27: the product's indigo, and the three palettes stay. An action is the same
    // colour in all three, because an action belongs to the product; the room it sits in is what the palette picks.
    for (final palette in AppThemePalette.values) {
      for (final brightness in Brightness.values) {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final where = '${palette.name}/${brightness.name}';

        expect(scheme.primary, colourOf('action-primary', brightness), reason: '$where primary ← --action-primary');
        expect(scheme.surfaceTint, colourOf('action-primary', brightness), reason: '$where surfaceTint ← primary');
        expect(
          scheme.primaryContainer,
          colourOf('surface-brand', brightness),
          reason: '$where primaryContainer ← --surface-brand, the quiet brand surface',
        );
        expect(
          scheme.onPrimaryContainer,
          colourOf('text-brand', brightness),
          reason: '$where onPrimaryContainer ← --text-brand',
        );
      }
    }
  });

  test('a button label is white, which is what the design system itself paints', () {
    // Not a deviation, although it reads like one. `--text-inverse` is `#0B0D18` in the dark scope and 3.08:1 on
    // the action colour, so it cannot be a button label — but the system never asks it to be one. The website
    // sets `color: #fff` as a literal at all ten of its filled brand buttons, with no dark override, and paints
    // `--text-inverse` in exactly one place: as the ink of `--surface-inverse`, which is where this app puts it
    // too (`onInverseSurface`). White here follows the system's own practice; the floor only confirms it.
    final darkInverse = colourOf('text-inverse', Brightness.dark);
    final indigo = colourOf('action-primary', Brightness.dark);
    expect(
      contrastRatio(darkInverse, indigo),
      lessThan(4.5),
      reason: 'if the system ever lifts its dark --text-inverse off #0B0D18, this deviation is worth revisiting',
    );

    for (final palette in AppThemePalette.values) {
      for (final brightness in Brightness.values) {
        expect(
          ThemeColors.getColorScheme(palette, brightness).onPrimary,
          const Color(0xFFFFFFFF),
          reason: '${palette.name}/${brightness.name}: white reads on the action colour at 6.29:1 in both scopes',
        );
      }
    }
  });

  test('classic is the design system, token for token', () {
    // `classic` is the palette the owner ruled would be the site's exact counterpart. Every role below is the web
    // token named beside it; the three that are not are the deviation test under this one.
    final roles = <(String, Color Function(ColorScheme), String)>[
      ('surface', (s) => s.surface, 'background'),
      ('onSurface', (s) => s.onSurface, 'text-primary'),
      ('onSurfaceVariant', (s) => s.onSurfaceVariant, 'text-secondary'),
      ('secondary', (s) => s.secondary, 'text-secondary'),
      ('secondaryContainer', (s) => s.secondaryContainer, 'action-tertiary'),
      ('onSecondaryContainer', (s) => s.onSecondaryContainer, 'text-primary'),
      ('tertiaryContainer', (s) => s.tertiaryContainer, 'action-tertiary'),
      ('onTertiaryContainer', (s) => s.onTertiaryContainer, 'text-primary'),
      ('surfaceContainerHighest', (s) => s.surfaceContainerHighest, 'surface-hover'),
      ('inverseSurface', (s) => s.inverseSurface, 'surface-inverse'),
    ];

    for (final brightness in Brightness.values) {
      final scheme = ThemeColors.getColorScheme(AppThemePalette.classic, brightness);
      for (final (role, read, token) in roles) {
        expect(read(scheme), colourOf(token, brightness), reason: 'classic/${brightness.name}: $role ← --$token');
      }
      // `surface` is the page, which is what Material 3 means by the role; the web's `--surface` is a card, and
      // it lands on `surfaceContainer*`. Reading it the other way puts the action colour at 2.80:1 on the page.
      // Only the dark scope can say so: in light the system gives `--background` and `--surface` the same white.
      if (brightness == Brightness.dark) {
        expect(
          scheme.surface,
          isNot(colourOf('surface', brightness)),
          reason: 'surface is --background; --surface is a card, and the action colour is 2.80:1 on it',
        );
      }
    }
  });

  test('the status colours are the design system in every palette', () {
    // One rule covers all four: the colour is `--<kind>-text`, what sits on it is the scope's `--text-inverse`, and
    // the container pair is `--<kind>-bg` with `--<kind>-text` on it. It holds because this app paints *text* with
    // these roles as often as it fills with them — `ColorScheme.error` alone is a text colour at 20 call sites —
    // and `--<kind>-text` is the only member of each web triplet that can carry both uses.
    //
    // `--action-destructive` is deliberately not mapped here. It is the web's destructive *button*, and in the dark
    // scope it is 4.01:1 against the page, which fails the text this app paints with the role.
    for (final brightness in Brightness.values) {
      final inverse = colourOf('text-inverse', brightness);

      for (final palette in AppThemePalette.values) {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final where = '${palette.name}/${brightness.name}';
        expect(scheme.error, colourOf('error-text', brightness), reason: '$where error ← --error-text');
        expect(scheme.onError, inverse, reason: '$where onError ← --text-inverse');
        expect(scheme.errorContainer, colourOf('error-bg', brightness), reason: '$where errorContainer ← --error-bg');
        expect(scheme.onErrorContainer, colourOf('error-text', brightness), reason: '$where onErrorContainer');
      }

      final semantic = brightness == Brightness.light ? SemanticColors.light : SemanticColors.dark;
      for (final (kind, colour, on, container, onContainer) in [
        ('success', semantic.success, semantic.onSuccess, semantic.successContainer, semantic.onSuccessContainer),
        ('warning', semantic.warning, semantic.onWarning, semantic.warningContainer, semantic.onWarningContainer),
        ('info', semantic.info, semantic.onInfo, semantic.infoContainer, semantic.onInfoContainer),
      ]) {
        final text = colourOf('$kind-text', brightness);
        expect(colour, text, reason: '${brightness.name} $kind ← --$kind-text');
        expect(on, inverse, reason: '${brightness.name} on$kind ← --text-inverse');
        expect(container, colourOf('$kind-bg', brightness), reason: '${brightness.name} ${kind}Container');
        expect(onContainer, text, reason: '${brightness.name} on${kind}Container ← --$kind-text');
      }
    }
  });

  test('three values deviate, each because the design system fails a floor it has to clear', () {
    // The rule, applied: start at the web value, walk the web's own `--neutral-*` ramp away from the surface, and
    // stop at the first point that clears the floor. The taken value is therefore inside the system's own ramp and
    // as close to the web's as the floor allows — which is also the convention #369 set, where every shipping
    // `outlineVariant` sits at 1.90-1.93.
    //
    // `outline` is lifted one notch further than that convention, and the floor below is the one it clears on the
    // page rather than the one it was lifted for. It draws the edge of a box filled with `surfaceContainerHighest`
    // — the theme badge — and a border that clears 3:1 against the page can sit at 2.25:1 against the container in
    // front of it, which is the ground the eye actually sees it on (#386). `container_contrast_test.dart` holds
    // that floor; this row holds the one the website's own value fails, which is why the deviation exists at all.
    //
    // Each row asserts both halves: that the web value really does fail, and that the value taken instead clears.
    // If the system ever lifts one of these, the first half fails and the deviation is reconsidered, not kept.
    final deviations = <(String, Brightness, String, Color Function(ColorScheme), double, Color)>[
      ('outline', Brightness.light, 'border-strong', (s) => s.outline, 3.0, Color(0xFF868CA4)),
      ('outlineVariant', Brightness.light, 'border', (s) => s.outlineVariant, 1.9, Color(0xFFB5BBCF)),
      ('outline', Brightness.dark, 'border-strong', (s) => s.outline, 3.0, Color(0xFF6C7289)),
      ('outlineVariant', Brightness.dark, 'border', (s) => s.outlineVariant, 1.9, Color(0xFF3C4057)),
    ];
    // `tertiary` is not in that list because its lift is not this app's. It is in the test below.

    for (final (role, brightness, token, read, floor, taken) in deviations) {
      final scheme = ThemeColors.getColorScheme(AppThemePalette.classic, brightness);
      final web = colourOf(token, brightness);
      expect(
        contrastRatio(web, scheme.surface),
        lessThan(floor),
        reason: '--$token is why $role/${brightness.name} deviates; if it now clears $floor:1, take it',
      );
      expect(read(scheme), taken, reason: '$role/${brightness.name}: --$token lifted along the ramp to $floor:1');
      expect(
        contrastRatio(read(scheme), scheme.surface),
        greaterThanOrEqualTo(floor),
        reason: 'the lifted value has to clear the floor it was lifted for',
      );
    }
  });

  /// The lift `--<token>` is given in [brightness]'s scope of the other consumer's accessibility layer.
  ///
  /// `tool/design-system/other-consumer/a11y.css` is a verbatim copy of `src/styles/a11y.css` in
  /// `libredb/libredb.github.io`, taken at `2e8c39b`. It is *not* part of the design system — it is the website's
  /// record of where the system and WCAG 1.4.3 collide, and its own header says each value is "the MINIMUM lift
  /// that clears 4.5:1 on the darkest/lightest surface the token is actually painted on".
  Color liftOf(String token, Brightness brightness) {
    final source = File('tool/design-system/other-consumer/a11y.css').readAsStringSync();
    final darkAt = RegExp(r"^\[data-theme='dark'\]", multiLine: true).firstMatch(source)!.start;
    final scope = brightness == Brightness.light ? source.substring(0, darkAt) : source.substring(darkAt);
    final declaration = RegExp('--$token\\s*:\\s*#([0-9a-fA-F]{6})\\s*;').firstMatch(scope);
    expect(declaration, isNotNull, reason: '--$token carries no lift in the ${brightness.name} scope of a11y.css');
    return Color(0xFF000000 | int.parse(declaration!.group(1)!, radix: 16));
  }

  test("tertiary takes the website's lift, not one of this app's own", () {
    // The system sets `--text-tertiary` too light to read in both scopes — 3.86:1 on white, and 4.40:1 on the
    // card the website paints it on. The website measured that and lifted it; this app takes the same value,
    // because two consumers of one design system showing two different greys is what a shared system prevents.
    //
    // Reading it from the vendored file rather than restating it is what makes a later divergence fail here: if
    // the website re-lifts the token, this app follows instead of drifting.
    for (final brightness in Brightness.values) {
      final scheme = ThemeColors.getColorScheme(AppThemePalette.classic, brightness);
      expect(
        colourOf('text-tertiary', brightness),
        isNot(liftOf('text-tertiary', brightness)),
        reason: 'if the system itself adopts the lift, this whole deviation goes away',
      );
      expect(
        scheme.tertiary,
        liftOf('text-tertiary', brightness),
        reason: "classic/${brightness.name}: tertiary is the website's --text-tertiary lift",
      );
      expect(
        contrastRatio(scheme.tertiary, scheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'and it has to clear 4.5:1 on this app\'s page, which is not one of the grounds it was cut for',
      );
    }
  });

  test('nature and sunset keep their own neutrals, deliberately', () {
    // The owner kept three palettes. Three palettes that differ only in the name of the action colour are one
    // palette with three names, so the room each one paints — its page, its edges, its quiet text — stays its own.
    // Pinned in both directions: following the web here would collapse the choice the owner made.
    for (final palette in [AppThemePalette.nature, AppThemePalette.sunset]) {
      for (final brightness in Brightness.values) {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        final where = '${palette.name}/${brightness.name}';
        expect(scheme.surface, isNot(colourOf('background', brightness)), reason: '$where keeps its own page');
        expect(
          scheme.onSurfaceVariant,
          isNot(colourOf('text-secondary', brightness)),
          reason: '$where keeps its own secondary text',
        );
        expect(
          scheme.secondary,
          isNot(ThemeColors.getColorScheme(AppThemePalette.classic, brightness).secondary),
          reason: '$where keeps its own accent — sage and orange are what these two palettes are',
        );
      }
    }
  });

  test("the two brand gradients are the system's own stops", () {
    // `colors.css` ends with them, and they are the one part of the system this app had no counterpart for: the
    // login panel reached for six hues of its own instead. Read from the primitive file rather than `theme.css`,
    // because that is where the system declares them — they are a graphic device, not a semantic token, and its
    // own comment says so: "mark, one accent surface, graphic device. Never a page bg."
    final source = File('tool/design-system/tokens/colors.css').readAsStringSync();

    List<Color> stopsOf(String name) {
      final declaration = RegExp('--gradient-$name\\s*:\\s*linear-gradient\\(([^)]*)\\)').firstMatch(source);
      expect(declaration, isNotNull, reason: '--gradient-$name is not declared in colors.css');
      return [
        for (final match in RegExp('#([0-9a-fA-F]{6})').allMatches(declaration!.group(1)!))
          Color(0xFF000000 | int.parse(match.group(1)!, radix: 16)),
      ];
    }

    expect(stopsOf('brand'), [AppGradients.brandStart, AppGradients.brandEnd], reason: '--gradient-brand');
    expect(stopsOf('data'), [AppGradients.dataStart, AppGradients.dataEnd], reason: '--gradient-data');
    expect(AppGradients.brand.colors, [AppGradients.brandStart, AppGradients.brandEnd]);
    expect(AppGradients.data.colors, [AppGradients.dataStart, AppGradients.dataEnd]);

    // The field the brand panel stands on is the dark scope's own ground, not a colour of the panel's choosing.
    expect(AppGradients.brandField.colors.first, colourOf('background', Brightness.dark));
    expect(AppGradients.brandField.colors[1], colourOf('surface', Brightness.dark));
    expect(AppGradients.brandFieldOnLight.colors.first, colourOf('surface', Brightness.dark));
    expect(AppGradients.brandFieldOnLight.colors[1], colourOf('surface-elevated', Brightness.dark));
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
