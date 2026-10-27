import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';

/// The typefaces the product is set in.
///
/// libredb.org is set in Plus Jakarta Sans, with JetBrains Mono for every code surface. The app shipped neither: it
/// named no `fontFamily` at all, so it rendered in Roboto on Android and the system face on iOS, and its 29 code
/// surfaces asked for the string `'monospace'` — whatever the platform happened to supply. Two products that set
/// their text in different faces do not read as one product, whatever their colours agree on.
void main() {
  group('the product typeface', () {
    test('every text style carries it, so no screen falls back to the platform face', () {
      final textTheme = AppTypography.textTheme(ThemeData.light().textTheme);

      final styles = <String, TextStyle?>{
        'displayLarge': textTheme.displayLarge,
        'headlineMedium': textTheme.headlineMedium,
        'titleLarge': textTheme.titleLarge,
        'titleMedium': textTheme.titleMedium,
        'bodyLarge': textTheme.bodyLarge,
        'bodyMedium': textTheme.bodyMedium,
        'bodySmall': textTheme.bodySmall,
        'labelLarge': textTheme.labelLarge,
        'labelMedium': textTheme.labelMedium,
        'labelSmall': textTheme.labelSmall,
      };
      styles.forEach((name, style) {
        expect(style?.fontFamily, AppTypography.sans, reason: name);
      });
    });

    test('reaches the theme, in both brightnesses and every palette', () {
      for (final palette in AppThemePalette.values) {
        for (final theme in [AppTheme.light(palette), AppTheme.dark(palette)]) {
          expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.sans, reason: '$palette');
        }
      }
    });
  });

  group('the code typeface', () {
    test('is named as a token rather than as the string "monospace"', () {
      // 'monospace' is a request to the platform, so the same code renders in a different face on each one — and on
      // the screens where it matters most, a column of values a user is comparing character by character.
      expect(AppTypography.mono, isNot('monospace'));
      expect(AppTypography.mono, isNotEmpty);
    });

    test('no widget asks the platform for a monospace face', () {
      // The dev console is excluded: it opens in debug builds only and no user meets it.
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final path = file.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart') || path.startsWith('lib/app/dev_console/')) continue;
        final n = "'monospace'".allMatches(file.readAsStringSync()).length;
        if (n > 0) offenders.add('$path: $n');
      }
      expect(offenders, isEmpty, reason: 'use AppTypography.mono\n${offenders.join('\n')}');
    });
  });

  group('the font files', () {
    test('every weight the type scale asks for is declared and present', () {
      // A weight pubspec does not declare is synthesised by the engine, which looks like the real face until you
      // compare them side by side — and a path that does not exist fails silently at runtime, not at build time.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final weight in const ['400', '500', '600', '700']) {
        expect(pubspec, contains('weight: $weight'), reason: 'Plus Jakarta Sans $weight');
      }
      for (final path in RegExp(r'asset: (assets/fonts/[^\s]+)').allMatches(pubspec).map((m) => m.group(1)!)) {
        expect(File(path).existsSync(), isTrue, reason: '$path is declared but not in the repository');
      }
    });

    test('ships its licence, because both families are OFL-1.1', () {
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });
  });

  group('the type scale', () {
    final css = File('tool/design-system/tokens/typography.css').readAsStringSync();

    double? valueOf(String property) {
      final match = RegExp('--$property\\s*:\\s*(-?[0-9.]+)').firstMatch(css);
      return match == null ? null : double.parse(match.group(1)!);
    }

    /// The size the phone gets: the mobile column where the scale has one, the single value where it does not.
    double sizeOf(String name) => valueOf('$name-size-mobile') ?? valueOf('$name-size')!;

    /// The design system writes tracking in `em`, which is relative to the size; Flutter wants logical pixels.
    double? trackingOf(String name, double size) {
      final em = valueOf('$name-tracking');
      return em == null ? null : em * size;
    }

    // The system has ten heading levels — four displays and h1 to h6 — against Material's nine. `display-xxl` is the
    // one dropped: it is 72px of marketing headline, and no phone screen in this app has a use for it. The rest map
    // in order, so the relationship stays readable rather than becoming a lookup table nobody can check.
    const mapping = <String, String>{
      'displayLarge': 'display-xl',
      'displayMedium': 'display-l',
      'displaySmall': 'display-m',
      'headlineLarge': 'h1',
      'headlineMedium': 'h2',
      'headlineSmall': 'h3',
      'titleLarge': 'h4',
      'titleMedium': 'h5',
      'titleSmall': 'h6',
      'bodyLarge': 'body-m',
      'bodyMedium': 'body-s',
      'bodySmall': 'body-xs',
      'labelLarge': 'label',
      'labelMedium': 'caption',
      'labelSmall': 'overline',
    };

    TextStyle? styleOf(TextTheme theme, String slot) => <String, TextStyle?>{
      'displayLarge': theme.displayLarge,
      'displayMedium': theme.displayMedium,
      'displaySmall': theme.displaySmall,
      'headlineLarge': theme.headlineLarge,
      'headlineMedium': theme.headlineMedium,
      'headlineSmall': theme.headlineSmall,
      'titleLarge': theme.titleLarge,
      'titleMedium': theme.titleMedium,
      'titleSmall': theme.titleSmall,
      'bodyLarge': theme.bodyLarge,
      'bodyMedium': theme.bodyMedium,
      'bodySmall': theme.bodySmall,
      'labelLarge': theme.labelLarge,
      'labelMedium': theme.labelMedium,
      'labelSmall': theme.labelSmall,
    }[slot];

    testWidgets('every slot is the size the design system gives its level', (tester) async {
      late TextTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemePalette.classic),
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context).textTheme;
              return const SizedBox();
            },
          ),
        ),
      );

      mapping.forEach((slot, level) {
        expect(styleOf(resolved, slot)?.fontSize, sizeOf(level), reason: '$slot is $level');
      });
    });

    testWidgets('every slot takes its line height from the same level', (tester) async {
      late TextTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemePalette.classic),
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context).textTheme;
              return const SizedBox();
            },
          ),
        ),
      );

      mapping.forEach((slot, level) {
        final line = valueOf('$level-line');
        if (line == null) return;
        expect(styleOf(resolved, slot)?.height, line, reason: '$slot is $level');
      });
    });

    testWidgets('a level that is tracked is tracked by the same fraction of its own size', (tester) async {
      late TextTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemePalette.classic),
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context).textTheme;
              return const SizedBox();
            },
          ),
        ),
      );

      mapping.forEach((slot, level) {
        // `overline` is the one level whose tracking does not come with its size: the system ties that 0.1em to the
        // ALL-CAPS eyebrow treatment, and `labelSmall` here is an ordinary small label.
        if (level == 'overline') return;
        final tracking = trackingOf(level, sizeOf(level));
        if (tracking == null) return;
        expect(
          styleOf(resolved, slot)?.letterSpacing,
          closeTo(tracking, 0.001),
          reason: '$slot is $level, tracked in em against its own size',
        );
      });
    });
  });
}
