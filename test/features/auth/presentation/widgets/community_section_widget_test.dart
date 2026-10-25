@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/community_section_widget.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/url_launcher_stub.dart';

const _repo = 'https://github.com/acme/dashboard';
const _docs = 'https://docs.acme.example';
const _sponsor = 'https://github.com/sponsors/acme';

/// Links other than the app's own, so a test sees that the page reads them from `AppDependencies`.
const _acmeLinks = ProjectLinks(repository: _repo, docs: _docs, sponsor: _sponsor);

const _allUrls = CommunityUrls(repo: _repo, sponsor: _sponsor, docs: _docs);

const _communityKeys = [
  communityStarKey,
  communityIssueKey,
  communityContributeKey,
  communityTranslateKey,
  communitySponsorKey,
  communityDocsKey,
];

const _phone = Size(390, 844);
const _desktop = Size(1600, 1000);

void main() {
  Widget buildWidget({required bool isDesktop, CommunityUrls urls = _allUrls, Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CommunitySectionWidget(isDesktop: isDesktop, urls: urls),
        ),
      ),
    );
  }

  // The real app on the login page, with the links the build gives.
  Future<void> pumpAppOnLogin(WidgetTester tester, {required ProjectLinks links, Size size = _phone}) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      App(
        language: 'en',
        dependencies: MockSignInDependencies(projectLinks: links),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
  }

  group('CommunitySectionWidget - Desktop', () {
    testWidgets('renders section title', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: true));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsOneWidget);
    });

    testWidgets('renders Source Available pill badge', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: true));
      await tester.pumpAndSettle();

      expect(find.text('Source Available'), findsOneWidget);
    });

    testWidgets('renders subtitle text', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: true));
      await tester.pumpAndSettle();

      expect(find.text("LibreDB's source code is public. Your contributions make it better!"), findsOneWidget);
    });

    testWidgets('renders a card for every community link', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: true));
      await tester.pumpAndSettle();

      for (final key in _communityKeys) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('displays correct label texts', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: true));
      await tester.pumpAndSettle();

      expect(find.text('Star & Fork'), findsOneWidget);
      expect(find.text('Open an Issue'), findsOneWidget);
      expect(find.text('Discussions'), findsNothing);
      expect(find.text('Contribute'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Sponsor'), findsOneWidget);
      expect(find.text('Documentation'), findsOneWidget);
    });
  });

  group('CommunitySectionWidget - Mobile', () {
    testWidgets('renders section title', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: false));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsOneWidget);
    });

    testWidgets('renders subtitle text', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: false));
      await tester.pumpAndSettle();

      expect(find.text("LibreDB's source code is public. Your contributions make it better!"), findsOneWidget);
    });

    testWidgets('renders a chip for every community link', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: false));
      await tester.pumpAndSettle();

      for (final key in _communityKeys) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('renders divider', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: false));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('displays correct label texts', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: false));
      await tester.pumpAndSettle();

      expect(find.text('Star & Fork'), findsOneWidget);
      expect(find.text('Open an Issue'), findsOneWidget);
      expect(find.text('Discussions'), findsNothing);
      expect(find.text('Contribute'), findsOneWidget);
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Sponsor'), findsOneWidget);
      expect(find.text('Documentation'), findsOneWidget);
    });
  });

  group('CommunityUrls', () {
    test('builds the repository pages from the repository URL', () {
      const urls = _allUrls;

      expect(urls.repo, 'https://github.com/acme/dashboard');
      expect(urls.issues, 'https://github.com/acme/dashboard/issues');
      expect(urls.contributing, 'https://github.com/acme/dashboard/blob/main/CONTRIBUTING.md');
      expect(urls.translate, 'https://github.com/acme/dashboard/issues/new/choose');
    });

    test('takes the repository, sponsor and documentation URLs from the project links', () {
      final urls = CommunityUrls.of(_acmeLinks);

      expect(urls.repo, _repo);
      expect(urls.sponsor, _sponsor);
      expect(urls.docs, _docs);
    });
  });

  group('Login page - community section', () {
    for (final (name, size) in [('phone', _phone), ('desktop', _desktop)]) {
      testWidgets('links the community section to the LibreDB Mobile repository by default ($name)', (tester) async {
        final calls = stubOpeningUrlLauncher(canLaunch: true);
        await pumpAppOnLogin(tester, links: const ProjectLinks(), size: size);

        expect(find.text('Join the Community'), findsOneWidget);
        await scrollTo(tester, communityStarKey);
        await expectTapShowsNoMessage(tester, find.byKey(communityStarKey));
        expect(calls.launchedUrls, ['https://github.com/libredb/libredb-mobile']);
      });

      testWidgets('links the community section to the repository it is given ($name)', (tester) async {
        final calls = stubOpeningUrlLauncher(canLaunch: true);
        await pumpAppOnLogin(tester, links: _acmeLinks, size: size);

        expect(find.text('Join the Community'), findsOneWidget);
        await scrollTo(tester, communityStarKey);
        await expectTapShowsNoMessage(tester, find.byKey(communityStarKey));
        await expectTapShowsNoMessage(tester, find.byKey(communitySponsorKey));
        expect(calls.launchedUrls, [_repo, _sponsor]);
      });
    }
  });

  group('CommunitySectionWidget - link that does not open', () {
    for (final failure in UrlLauncherFailure.values) {
      testWidgets('tapping Documentation on the login page shows a message when ${failure.description}', (
        tester,
      ) async {
        final calls = stubFailingUrlLauncher(failure);
        await pumpAppOnLogin(tester, links: _acmeLinks);
        await scrollTo(tester, communityDocsKey);

        await expectTapShowsMessage(tester, find.byKey(communityDocsKey));
        expect(calls.requestedUrls, contains(_docs));
      });
    }
  });

  group('CommunitySectionWidget - link that opens', () {
    for (final canLaunch in [true, false]) {
      testWidgets('tapping Documentation on the login page opens it and shows no message when canLaunchUrl answers '
          '$canLaunch', (tester) async {
        final calls = stubOpeningUrlLauncher(canLaunch: canLaunch);
        await pumpAppOnLogin(tester, links: _acmeLinks);
        await scrollTo(tester, communityDocsKey);

        await expectTapShowsNoMessage(tester, find.byKey(communityDocsKey));
        expect(calls.launchedUrls, [_docs]);
      });
    }
  });
  group('CommunitySectionWidget - Turkish', () {
    testWidgets('renders the Source Available pill badge in Turkish', (tester) async {
      await tester.pumpWidget(buildWidget(isDesktop: true, locale: const Locale('tr')));
      await tester.pumpAndSettle();

      expect(find.text('Kaynak Kodu Erişilebilir'), findsOneWidget);
    });
  });
}
