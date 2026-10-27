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

  Widget buildRow({Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
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
}
