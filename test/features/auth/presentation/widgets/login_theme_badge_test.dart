@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_sizes.dart';

import '../../../../support/login_harness.dart';

/// The ink of the light/dark switch has to be the shape of the switch, not the shape of its hit area (#414).
///
/// The switch is drawn as a 36 pt box with an [AppRadius.lg] corner, and its hit area was grown to
/// [AppSizes.minTapTarget] so a corner control can be hit (#357). Ink follows whatever owns it, so growing the hit
/// area grew the splash with it: a 48 pt pill behind a 36 pt rounded square, bigger than the control and a different
/// shape from it. These two measure the ink against the control rather than against the target.
void main() {
  /// The ink of the switch, whether the switch is itself the inking widget or owns one.
  Finder switchInk() =>
      find.descendant(of: find.byKey(loginThemeToggleKey), matching: find.byType(InkWell), matchRoot: true);

  /// The corner radius the ink is clipped to, read from whichever of the two ways an [InkWell] can be given a shape.
  /// Anything that is not a rounded rectangle cannot be the switch's shape, so it reads as unbounded.
  double inkCornerRadius(InkWell ink) {
    final shape = ink.customBorder;
    if (shape is RoundedRectangleBorder) return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    if (shape != null) return double.infinity;
    return ink.borderRadius?.resolve(TextDirection.ltr).topLeft.x ?? 0;
  }

  Future<void> pumpLoginPage(WidgetTester tester) async {
    setViewport(tester, kPhoneViewport);
    await tester.pumpWidget(App(language: 'en', dependencies: OidcDependencies(ScriptedOidcClient())));
    await tester.pumpAndSettle();
  }

  testWidgets('the ink is the size of the switch, not the size of its hit area', (tester) async {
    await pumpLoginPage(tester);

    final target = tester.getSize(find.byKey(loginThemeToggleKey));
    expect(target.width, greaterThanOrEqualTo(AppSizes.minTapTarget), reason: 'the hit area must not shrink');
    expect(target.height, greaterThanOrEqualTo(AppSizes.minTapTarget), reason: 'the hit area must not shrink');

    expect(
      tester.getSize(switchInk()),
      const Size.square(36),
      reason:
          'the splash and the highlight are drawn over the ink box, so a box bigger than the 36 pt switch paints a '
          'halo around it',
    );
  });

  testWidgets('the ink is the shape of the switch, not a pill', (tester) async {
    await pumpLoginPage(tester);

    expect(
      inkCornerRadius(tester.widget<InkWell>(switchInk())),
      AppRadius.lg,
      reason: 'the switch is drawn with an AppRadius.lg corner, so a tap on it may not round off into a circle',
    );
  });
}
