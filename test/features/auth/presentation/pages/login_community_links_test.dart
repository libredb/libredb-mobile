@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';

import '../../../../support/url_launcher_stub.dart';

const _repo = 'https://github.com/acme/dashboard';
const _docs = 'https://docs.acme.example';
const _sponsor = 'https://github.com/sponsors/acme';

/// Links other than the app's own, so a test sees that the page reads them from `AppDependencies`.
const _acmeLinks = ProjectLinks(repository: _repo, docs: _docs, sponsor: _sponsor);

const _phone = Size(390, 844);
const _desktop = Size(1600, 1000);

/// The community links as the login page resolves and opens them, in both layouts.
///
/// This is where the `ProjectLinks` → `CommunityUrls` mapping is covered, because that is where it lives: the class
/// is under `shared/`, which imports `core/` only, so the page does the mapping (`import_guard_test.dart`).
///
/// The two layouts' own rendering is covered next to each of them —
/// `test/shared/widgets/community/community_chip_row_test.dart` and
/// `test/features/auth/presentation/widgets/community_card_grid_test.dart`.
void main() {
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

  group('a community link that does not open', () {
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

  group('a community link that opens', () {
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
}
