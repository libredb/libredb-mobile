@Tags(['widget'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';

import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';

import '../../../../support/login_harness.dart';

/// What `AppErrorCode.ssoSignInFailed` resolves to in English.
const _failedMessage = 'Sign-in failed. Please try again.';

/// The repository's first accessibility assertions (issue #357).
///
/// Before this file, `grep -rn "meetsGuideline"` over `test/` and `lib/` returned nothing: there was no
/// machine-checkable floor anywhere, so no change could regress against one and M16's evaluating agents had nothing
/// to measure a finding from. "This is hard to tap" was an opinion.
///
/// The login page is where the floor starts because it is the one screen every user meets, signed in or not, and
/// because it already failed: the six community chips are 32 pt tall against a 48 pt minimum.
///
/// `textContrastGuideline` is deliberately **not** here. Under Ahem every glyph is a solid block, so the coverage it
/// samples is not what a device shows and it can both pass a real failure and fail a real pass. The page's contrast
/// was computed instead, per WCAG 2.1 relative luminance, and recorded on #357.
void main() {
  Future<void> pumpLoginPage(WidgetTester tester, {AppDependencies? dependencies}) async {
    setViewport(tester, kPhoneViewport);
    await tester.pumpWidget(App(language: 'en', dependencies: dependencies ?? OidcDependencies(ScriptedOidcClient())));
    await tester.pumpAndSettle();
  }

  testWidgets('every tappable meets the Android minimum of 48 pt', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLoginPage(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    semantics.dispose();
  });

  testWidgets('every tappable meets the iOS minimum of 44 pt', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLoginPage(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    semantics.dispose();
  });

  testWidgets('every tappable announces a label, so nothing is an unnamed target', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpLoginPage(tester);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    semantics.dispose();
  });

  testWidgets('a refused sign-in is announced once, not twice', (tester) async {
    // The page renders the error and a snack bar used to repeat the same string, so a screen reader read it twice and
    // the suite waited five seconds for the snack bar to go before it could assert `findsOneWidget`.
    final client = ScriptedOidcClient(outcomes: [const OidcSignInFailed(OidcFailure.failed)]);
    await pumpLoginPage(tester, dependencies: OidcDependencies(client));

    await tester.tap(find.byKey(loginButtonSsoKey));
    await tester.pumpAndSettle();

    expect(find.text(_failedMessage), findsOneWidget);
  });
}
