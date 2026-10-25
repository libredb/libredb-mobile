import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The tokens the login and onboarding surface needs, and the barrel that makes them findable.
///
/// Every import here is from `tokens/tokens.dart`, the barrel, rather than from a file by name. That is the point of
/// the barrel: `components/components.dart` has 26 consumers and `tokens/` had none, so a developer imported
/// `app_spacing.dart` because they knew spacing existed and never learned `app_sizes.dart` did — which is why
/// `login_page.dart` and `community_section_widget.dart` carry every raw `fontSize`, every `Color(0x…)` and every
/// `circular(999)` in the app.
void main() {
  group('AppSizes.minTapTarget', () {
    test('is 48, which satisfies both platforms at once', () {
      // iOS asks for 44 and Android for 48, so the larger number satisfies both and there is only one to remember.
      expect(AppSizes.minTapTarget, 48.0);
      expect(AppSizes.minTapTarget, greaterThanOrEqualTo(44.0), reason: 'the iOS minimum');
    });

    test('is larger than every button token, because those are visual heights and this is a touch floor', () {
      // AppSizes.buttonLg is 40 and the theme's minimumSize is Size(0, 36): a button is allowed to look smaller than
      // it is tappable. Anything that adopts a button token still has to clear this.
      for (final size in [AppSizes.buttonSm, AppSizes.buttonMd, AppSizes.buttonLg]) {
        expect(AppSizes.minTapTarget, greaterThan(size));
      }
    });
  });

  group('AppRadius.pill', () {
    test('is large enough that any component clamps it to half its height', () {
      expect(AppRadius.pill, 999.0);
      expect(AppRadius.pill, greaterThan(AppRadius.xl));
    });
  });

  group('the barrel', () {
    test('exports every token a screen needs, so none is missed for not being known about', () {
      // Reading a value from each proves the export, and fails to compile if one is dropped from the barrel.
      expect(AppSpacing.lg, 16.0);
      expect(AppRadius.xl, 12.0);
      expect(AppSizes.iconMd, 18.0);
      expect(AppBreakpoints.tablet, 1024.0);
      expect(AppDurations.normal, isA<Duration>());
    });
  });

  group('the spacing scale', () {
    test('is 4/8-based with no odd values, so a guard can round an off-scale number to it', () {
      const scale = [
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
      expect(scale, [4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 40.0, 48.0, 64.0]);
      for (final step in scale) {
        expect(step % 4, 0, reason: '$step is off the 4/8 scale');
      }
    });
  });
}
