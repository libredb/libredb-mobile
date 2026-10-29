@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_sizes.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';
import 'package:libredb_mobile/shared/widgets/community/community_chip_row.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';

import '../../../support/pressed_frame.dart';
import '../../../support/url_launcher_stub.dart';

/// The ink of a community chip has to be the shape and size of the chip, not of its hit area (#414).
///
/// A chip draws a pill 31 pt tall, and #357 grew its hit area to [AppSizes.minTapTarget] so a 31 pt target could be
/// hit. Ink is painted over the box that owns it, so growing that box grew the splash with it: measured on the version
/// before this fix, every one of the six inked a 48 pt box behind a 31 pt pill — a 17 pt band, 8.5 above and 8.5
/// below, and rounded to a 24 pt corner where the pill's is 15.5. The same defect as the login theme switch's, which
/// PR #416 fixed by moving the control onto a `ButtonStyleButton`.
///
/// These measure the ink against the pill the chip draws rather than against the target around it, and they measure
/// it per chip, because the thing that goes wrong goes wrong per control.
void main() {
  const urls = CommunityUrls(
    repo: 'https://github.com/acme/dashboard',
    sponsor: 'https://github.com/sponsors/acme',
    docs: 'https://docs.acme.example',
  );

  const chips = <(String, Key)>[
    ('Star & Fork', communityStarKey),
    ('Open an Issue', communityIssueKey),
    ('Contribute', communityContributeKey),
    ('Translate', communityTranslateKey),
    ('Sponsor', communitySponsorKey),
    ('Documentation', communityDocsKey),
  ];

  /// The ink of one chip, whether the keyed widget is itself the inking widget or owns one.
  Finder chipInk(Key key) => find.descendant(of: find.byKey(key), matching: find.byType(InkWell), matchRoot: true);

  /// The pill the chip paints: the one box under it that carries a decoration, which is the border a person sees.
  Finder chipPill(Key key) => find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox));

  /// The corner radius the ink is clipped to, read from whichever of the two ways an [InkWell] can be given a shape.
  /// Anything that is not a rounded rectangle cannot be the chip's shape, so it reads as unbounded.
  double inkCornerRadius(InkWell ink) {
    final shape = ink.customBorder;
    if (shape is RoundedRectangleBorder) return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    if (shape != null) return double.infinity;
    return ink.borderRadius?.resolve(TextDirection.ltr).topLeft.x ?? 0;
  }

  Widget row() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: CommunityChipRow(actions: communityActions(urls))),
    ),
  );

  Future<void> pumpRow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(row());
    await tester.pumpAndSettle();
  }

  for (final (name, key) in chips) {
    testWidgets('the $name chip inks its own pill, not the hit area around it', (tester) async {
      await pumpRow(tester);

      final target = tester.getSize(find.byKey(key));
      expect(target.width, greaterThanOrEqualTo(AppSizes.minTapTarget), reason: 'the hit area must not shrink');
      expect(target.height, greaterThanOrEqualTo(AppSizes.minTapTarget), reason: 'the hit area must not shrink');

      expect(
        tester.getSize(chipInk(key)),
        tester.getSize(chipPill(key)),
        reason:
            'the splash and the highlight are drawn over the ink box, so an ink box taller than the pill paints a '
            'band above and below the chip on every tap',
      );
    });

    testWidgets('the $name chip inks a pill, the shape it is drawn as', (tester) async {
      await pumpRow(tester);

      expect(
        inkCornerRadius(tester.widget<InkWell>(chipInk(key))),
        AppRadius.pill,
        reason: 'the chip is drawn as a pill, so a tap on it may not come out a rounded rectangle',
      );
    });

    // PR #416 moved the theme switch onto a `ButtonStyleButton` and left the node that carries the tap unnamed,
    // because the `Tooltip` around it had put the label on the ancestor. A chip carries its own label, and it also
    // carries `link`, which a button has no property for — so both have to be asserted on the node that taps.
    testWidgets('a screen reader hears the $name chip as one named link it can open', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester);

      // `getSemanticsData`, not the node's own `label`: what a screen reader reads is the node with everything
      // merged into it, and a label that sits on a node of its own — beside the one that taps rather than in it —
      // is the defect this guards.
      final data = tester.getSemantics(find.byKey(key)).getSemanticsData();
      expect(data.label, name, reason: 'the chip that taps says nothing about where it goes');
      expect(data.flagsCollection.isButton, isTrue, reason: 'the chip is not announced as a button');
      expect(data.flagsCollection.isLink, isTrue, reason: 'the chip is not announced as a link');
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: 'the named node is not the one that taps');

      handle.dispose();
    });

    // The ink is the chip's whole answer to a finger — it has no tint of its own — so shrinking the ink is exactly
    // the change that could leave it answering with nothing visible. Measured over the pill, not over the hit area:
    // the band this fix removes would otherwise count as the chip lighting up.
    testWidgets('the $name chip still lights up under a finger', (tester) async {
      stubOpeningUrlLauncher(canLaunch: true);

      final fraction = await pressedFractionOfControl(
        tester,
        SingleChildScrollView(child: CommunityChipRow(actions: communityActions(urls))),
        pressAt: chipPill(key),
        surface: const Size(390, 500),
      );

      expect(
        fraction,
        greaterThanOrEqualTo(visiblePressFraction),
        reason: 'only ${(fraction * 100).toStringAsFixed(1)}% of the $name chip changes while it is held',
      );
    });
  }
}
