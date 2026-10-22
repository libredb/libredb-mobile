import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';

void main() {
  final light = AppTheme.light().colorScheme;
  final dark = AppTheme.dark().colorScheme;

  group('parseOperatorColor', () {
    test('reads #rrggbb in either case', () {
      expect(parseOperatorColor('#dc2626'), const Color(0xFFDC2626));
      expect(parseOperatorColor('#DC2626'), const Color(0xFFDC2626));
    });

    test('is null for no color or a value it cannot read', () {
      for (final value in [null, '', 'red', '#dc26', 'dc2626', '#dc2626ff', '#gggggg']) {
        expect(parseOperatorColor(value), isNull, reason: '$value');
      }
    });
  });

  test('contrastRatio follows WCAG', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.01));
    expect(contrastRatio(const Color(0xFF777777), Colors.white), closeTo(4.48, 0.02));
  });

  group('EnvironmentAccent.resolve', () {
    const environments = [null, 'production', 'staging', 'development', 'local', 'other', 'qa'];
    const colors = [null, '#dc2626', '#fde047', '#1e3a8a', '#ffffff', '#000000', '#6b7280'];

    test('keeps the badge text readable and the badge visible on the surface, in both themes', () {
      for (final scheme in [light, dark]) {
        for (final environment in environments) {
          for (final color in colors) {
            final accent = EnvironmentAccent.resolve(environment: environment, color: color, scheme: scheme);
            final reason = '${scheme.brightness} $environment $color';
            expect(
              contrastRatio(accent.badgeForeground, accent.badgeBackground),
              greaterThanOrEqualTo(4.5),
              reason: reason,
            );
            final themed =
                accent.badgeBackground == scheme.error || accent.badgeBackground == scheme.secondaryContainer;
            if (!themed) {
              expect(contrastRatio(accent.badgeBackground, scheme.surface), greaterThanOrEqualTo(3), reason: reason);
            }
          }
        }
      }
    });

    test("uses Studio's environment color when there is no operator color and it passes", () {
      final accent = EnvironmentAccent.resolve(environment: 'production', color: null, scheme: dark);

      expect(accent.badgeBackground, EnvironmentColors.production);
      expect(accent.strip, EnvironmentColors.production);
    });

    test('uses the operator color for the badge when it passes', () {
      final accent = EnvironmentAccent.resolve(environment: 'production', color: '#dc2626', scheme: light);

      expect(accent.badgeBackground, const Color(0xFFDC2626));
      expect(accent.strip, const Color(0xFFDC2626));
    });

    test('moves an operator color that fails on the surface to the strip and keeps the badge in a theme color', () {
      final navy = EnvironmentAccent.resolve(environment: 'staging', color: '#1e3a8a', scheme: dark);
      expect(navy.strip, const Color(0xFF1E3A8A));
      expect(navy.badgeBackground, dark.secondaryContainer);

      final white = EnvironmentAccent.resolve(environment: 'production', color: '#ffffff', scheme: light);
      expect(white.strip, const Color(0xFFFFFFFF));
      expect(white.badgeBackground, light.error);
    });

    test("falls back to a theme color for Studio's own color when it fails, as yellow does on a light surface", () {
      final accent = EnvironmentAccent.resolve(environment: 'staging', color: null, scheme: light);

      expect(accent.badgeBackground, light.secondaryContainer);
      expect(accent.strip, isNull);
    });

    test('gives every production row a strip, and other rows one only for an operator color', () {
      expect(EnvironmentAccent.resolve(environment: 'production', color: null, scheme: light).strip, isNotNull);
      expect(EnvironmentAccent.resolve(environment: 'development', color: null, scheme: light).strip, isNull);
      expect(EnvironmentAccent.resolve(environment: null, color: '#6b7280', scheme: light).strip, isNotNull);
    });
  });
}
