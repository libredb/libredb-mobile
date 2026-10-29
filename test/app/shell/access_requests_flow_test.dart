@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';

import '../../support/test_env.dart';
import '../../support/user_menu.dart';

/// The signed-in app on the mock API: `assets/mock/GET_v1_requester_*.json` and the governed policy.
void main() {
  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  Future<void> pumpSignedIn(WidgetTester tester, {String language = 'en'}) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();
    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: language));
    await tester.pumpAndSettle();
  }

  Finder topBarText(String text) => find.descendant(of: find.byType(TopBarWidget), matching: find.text(text));

  /// The mock API answers after its simulated latency, which only a clock that moves waits for.
  Future<void> awaitMock(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> openRequests(WidgetTester tester) => selectFromUserMenu(tester, Icons.lock_open_outlined);

  testWidgets('Access requests in the profile sheet opens My requests with the four mocked statuses', (tester) async {
    await pumpSignedIn(tester);

    await openRequests(tester);

    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.accessRequests);
    expect(topBarText('My requests'), findsOneWidget);
    for (final status in ['Pending', 'Approved', 'Refused', 'Withdrawn']) {
      expect(find.text(status), findsOneWidget);
    }
    expect(
      find.text("Administrator's reason: Loads go through the data team; ask your team lead to schedule one."),
      findsOneWidget,
    );
  });

  testWidgets('the back arrow of My requests returns to the connection list', (tester) async {
    await pumpSignedIn(tester);
    await openRequests(tester);

    await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)));
    await tester.pumpAndSettle();

    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
  });

  testWidgets('My requests opened by a link, with nothing under it, goes back to the connection list', (tester) async {
    await pumpSignedIn(tester);
    routerOf(tester).go(ApplicationRoutesConstants.accessRequests);
    await tester.pumpAndSettle();
    expect(routerOf(tester).canPop(), isFalse);

    await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)));
    await tester.pumpAndSettle();

    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
  });

  testWidgets('the pending request is withdrawn after a confirmation and its row turns to Withdrawn', (tester) async {
    await pumpSignedIn(tester);
    await openRequests(tester);

    await tester.tap(find.byKey(const ValueKey('access-request-withdraw-cm0req00000000000000000001')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Withdraw')));
    await awaitMock(tester);

    expect(find.text('Pending'), findsNothing);
    expect(find.text('Withdrawn'), findsNWidgets(2));
    expect(find.text('Request withdrawn.'), findsOneWidget);
  });

  testWidgets('the form shows the mocked connections, disables the held and the pending one, and sends a request', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await openRequests(tester);

    await tester.tap(find.byKey(const ValueKey('access-requests-new')));
    await awaitMock(tester);
    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.accessRequestNew);
    expect(topBarText('Request access'), findsOneWidget);

    Finder tile(int n) => find.byKey(ValueKey('access-request-connection-cm0conn${'$n'.padLeft(19, '0')}'));
    expect(tester.widget<ListTile>(tile(1)).enabled, isTrue);
    expect(tester.widget<ListTile>(tile(2)).enabled, isFalse);
    expect(tester.widget<ListTile>(tile(3)).enabled, isFalse);

    // The fourth mocked connection has no write credential.
    await tester.tap(tile(4));
    await tester.pumpAndSettle();
    final level = tester.widget<SegmentedButton<String>>(find.byKey(const ValueKey('access-request-level')));
    expect(level.segments.firstWhere((s) => s.value == 'write').enabled, isFalse);

    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('access-request-level')), matching: find.text('Read')),
    );
    await tester.enterText(find.byKey(const ValueKey('access-request-reason')), 'I need the order totals.');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('access-request-send')));
    await tester.tap(find.byKey(const ValueKey('access-request-send')));
    await awaitMock(tester);

    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.accessRequests);
    expect(find.text('Request sent.'), findsOneWidget);
  });

  testWidgets('a typed location opens the form in a governed build with a Platform target', (tester) async {
    await pumpSignedIn(tester);
    routerOf(tester).go(ApplicationRoutesConstants.accessRequestNew);
    await tester.pumpAndSettle();

    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.accessRequestNew);
  });

  testWidgets('speaks Turkish in the profile sheet, the list and the form', (tester) async {
    await pumpSignedIn(tester, language: 'tr');

    await openRequests(tester);

    expect(topBarText('Taleplerim'), findsOneWidget);
    expect(find.text('Beklemede'), findsOneWidget);
  });
}
