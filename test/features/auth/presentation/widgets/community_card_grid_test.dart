@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/community_card_grid.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';

import '../../../../support/pressed_frame.dart';
import '../../../../support/url_launcher_stub.dart';

/// The community section as the wide login panel shows it.
///
/// It was the desktop half of `community_section_widget_test.dart`. No golden covers it — `kGoldenScreenSize` is a
/// phone — so these assertions are the only thing that sees the grid.
void main() {
  const urls = CommunityUrls(
    repo: 'https://github.com/acme/dashboard',
    sponsor: 'https://github.com/sponsors/acme',
    docs: 'https://docs.acme.example',
  );

  Widget buildGrid({Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: CommunityCardGrid(actions: communityActions(urls))),
    ),
  );

  testWidgets('names the section, says why it is there, and claims the licence', (tester) async {
    await tester.pumpWidget(buildGrid());
    await tester.pumpAndSettle();

    expect(find.text('Join the Community'), findsOneWidget);
    expect(find.text('Source Available'), findsOneWidget);
    expect(find.text("LibreDB's source code is public. Your contributions make it better!"), findsOneWidget);
  });

  testWidgets('shows a card for every destination', (tester) async {
    await tester.pumpWidget(buildGrid());
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

  testWidgets('labels each card, and shows no destination the list does not name', (tester) async {
    await tester.pumpWidget(buildGrid());
    await tester.pumpAndSettle();

    expect(find.text('Star & Fork'), findsOneWidget);
    expect(find.text('Open an Issue'), findsOneWidget);
    expect(find.text('Contribute'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Sponsor'), findsOneWidget);
    expect(find.text('Documentation'), findsOneWidget);
    expect(find.text('Discussions'), findsNothing);
  });

  // The grid is the only layout that carries the brand tints, which it looks up by key. A destination added to
  // communityActions without one throws here rather than rendering untinted.
  testWidgets('tints every destination it is given', (tester) async {
    await tester.pumpWidget(buildGrid());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('claims the licence in Turkish too', (tester) async {
    await tester.pumpWidget(buildGrid(locale: const Locale('tr')));
    await tester.pumpAndSettle();

    expect(find.text('Kaynak Kodu Erişilebilir'), findsOneWidget);
  });

  // The grid drove its whole appearance from a MouseRegion, so on the tablets this wide layout also reaches it
  // answered a finger with nothing (#367).
  testWidgets('a card draws a different frame while held', (tester) async {
    // The measurement lets the finger go, so the card's own link opens; the stub keeps that off the platform channel.
    stubOpeningUrlLauncher(canLaunch: true);
    final pressed = await rendersPressedState(
      tester,
      SingleChildScrollView(child: CommunityCardGrid(actions: communityActions(urls))),
      pressAt: find.byKey(communityStarKey),
      surface: const Size(600, 400),
    );
    expect(pressed, isTrue, reason: 'a community card answers a finger with nothing');
  });

  // As in AppCard, the ink alone would satisfy the pixels; this pins the card's own tint and border, which is the
  // state that used to need a mouse.
  testWidgets('a card carries its own tint into the press', (tester) async {
    stubOpeningUrlLauncher(canLaunch: true);
    await tester.pumpWidget(buildGrid());
    await tester.pumpAndSettle();

    final container = find.ancestor(of: find.byKey(communityStarKey), matching: find.byType(AnimatedContainer));
    Decoration? decoration() => tester.widget<AnimatedContainer>(container).decoration;
    final resting = decoration();

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(communityStarKey)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final pressed = decoration();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(pressed, isNot(resting), reason: 'a held community card still looks exactly like a resting one');
  });
}
