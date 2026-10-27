@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';
import 'package:libredb_mobile/shared/widgets/community/community_chip_row.dart';

/// The community section as a phone shows it.
///
/// It was the mobile half of `community_section_widget_test.dart`, which tested two layouts through one widget and
/// an `isDesktop` flag. The wide half is `test/features/auth/presentation/widgets/community_card_grid_test.dart`.
/// Its tap targets and contrast are covered by the login page's accessibility tests, which measure it in place.
void main() {
  const urls = CommunityUrls(
    repo: 'https://github.com/acme/dashboard',
    sponsor: 'https://github.com/sponsors/acme',
    docs: 'https://docs.acme.example',
  );

  Widget buildRow({Locale locale = const Locale('en'), double textScale = 1.0}) => MaterialApp(
    locale: locale,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
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

  testWidgets('names the section and says why it is there', (tester) async {
    await tester.pumpWidget(buildRow());
    await tester.pumpAndSettle();

    expect(find.text('Join the Community'), findsOneWidget);
    expect(find.text("LibreDB's source code is public. Your contributions make it better!"), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('shows a chip for every destination', (tester) async {
    await tester.pumpWidget(buildRow());
    await tester.pumpAndSettle();

    for (final key in const [
      communityStarKey,
      communityIssueKey,
      communityContributeKey,
      communityTranslateKey,
      communitySponsorKey,
      communityDocsKey,
    ]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
  });

  testWidgets('labels each chip, and shows no destination the list does not name', (tester) async {
    await tester.pumpWidget(buildRow());
    await tester.pumpAndSettle();

    expect(find.text('Star & Fork'), findsOneWidget);
    expect(find.text('Open an Issue'), findsOneWidget);
    expect(find.text('Contribute'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Sponsor'), findsOneWidget);
    expect(find.text('Documentation'), findsOneWidget);
    expect(find.text('Discussions'), findsNothing);
  });

  // A chip's label is the only thing in it that grows, and nothing let it wrap, so the row inside the pill ran past
  // the line the Wrap gave it. Turkish is where it shows first — its labels are longer than the English ones — and
  // 1.3 is a text size Android's accessibility settings reach with one step, not a synthetic case. Measured on the
  // version before this fix: Turkish overflowed by 11 px at 1.3 on a 320 pt phone and by 93 px at 2.0 on a 390 pt
  // one, and English overflowed at 2.0 as well (#375).
  group('the chips fit the phone they are given', () {
    for (final locale in ['en', 'tr']) {
      for (final scale in [1.0, 1.3, 2.0, 3.0]) {
        for (final width in [320.0, 390.0]) {
          testWidgets('$locale at text scale $scale on a $width pt phone', (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(buildRow(locale: Locale(locale), textScale: scale));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
