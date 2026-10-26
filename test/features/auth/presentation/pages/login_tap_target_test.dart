@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_sizes.dart';

import '../../../../support/login_harness.dart';

/// Measures every tappable on the login page against [AppSizes.minTapTarget] (issue #357).
///
/// This backs `login_screen_a11y_test.dart` rather than repeating it. The guideline matchers walk the semantics tree
/// and measure the nodes that carry a tap action, so what they cover depends on how that tree happens to be shaped:
/// a widget whose tap action ends up on an ancestor, or whose node is merged away, is measured somewhere other than
/// where it is drawn — or not measured at all. These assertions name a key and measure the box it renders, which
/// does not depend on that question and says which control is wrong when one is.
void main() {
  Future<void> pumpLoginPage(WidgetTester tester) async {
    setViewport(tester, kPhoneViewport);
    await tester.pumpWidget(App(language: 'en', dependencies: OidcDependencies(ScriptedOidcClient())));
    await tester.pumpAndSettle();
  }

  // The sign-in button is a FilledButton, whose MaterialTapTargetSize.padded already pads it to the minimum. It is
  // here so the floor covers the page's primary control rather than only the controls that failed.
  testWidgets('the sign-in button is at least ${AppSizes.minTapTarget} pt tall', (tester) async {
    await pumpLoginPage(tester);

    expect(tester.getSize(find.byKey(loginButtonSsoKey)).height, greaterThanOrEqualTo(AppSizes.minTapTarget));
  });

  // Six chips, each ~180 x 32 before #357: wide enough to hit by accident, short enough to miss on purpose.
  for (final (name, key) in <(String, Key)>[
    ('Star & Fork', communityStarKey),
    ('Report an issue', communityIssueKey),
    ('Contribute', communityContributeKey),
    ('Translate', communityTranslateKey),
    ('Sponsor', communitySponsorKey),
    ('Docs', communityDocsKey),
  ]) {
    testWidgets('the $name chip is at least ${AppSizes.minTapTarget} pt tall', (tester) async {
      await pumpLoginPage(tester);

      final chip = find.byKey(key);
      expect(chip, findsOneWidget, reason: 'the community row no longer shows $name');
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(AppSizes.minTapTarget));
    });
  }

  // The theme toggle is an InkWell, which does not pad its hit area the way a ButtonStyleButton does, so its 36 pt
  // visual box was its whole tap area.
  testWidgets('the theme toggle is at least ${AppSizes.minTapTarget} pt in both directions', (tester) async {
    await pumpLoginPage(tester);

    final toggle = find.byKey(loginThemeToggleKey);
    expect(toggle, findsOneWidget);
    final size = tester.getSize(toggle);
    expect(size.height, greaterThanOrEqualTo(AppSizes.minTapTarget));
    expect(size.width, greaterThanOrEqualTo(AppSizes.minTapTarget));
  });
}
