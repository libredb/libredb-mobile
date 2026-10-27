@Tags(['widget'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

/// Whether a pushed page answers the gesture iOS navigates with.
///
/// `CustomTransitionPage` does not carry the Cupertino back gesture, and `appTransitionPage` builds every sub-page
/// outside the two shells — settings, the audit log, and the object browser seven times over. On iOS those pages had
/// the app bar's back button and nothing else (#371).
void main() {
  Future<bool> swipeBody(WidgetTester tester, Page<void> Function(GoRouterState) page) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('root')),
        ),
        GoRoute(path: '/second', pageBuilder: (context, state) => page(state)),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push('/second');
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget, reason: 'the page has to be open before it can be swiped away');

    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    return find.text('second').evaluate().isEmpty;
  }

  /// The override is cleared before this returns rather than in a tearDown: the binding checks that no foundation
  /// debug variable outlived the test body, and that check runs first.
  Future<bool> popsOnEdgeSwipe(WidgetTester tester, Page<void> Function(GoRouterState) page) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      return await swipeBody(tester, page);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  const second = Scaffold(body: Text('second'));

  testWidgets('a platform page answers the edge swipe', (tester) async {
    expect(await popsOnEdgeSwipe(tester, (state) => appPlatformPage(state: state, child: second)), isTrue);
  });

  for (final type in AppPageTransitionType.values) {
    testWidgets('a ${type.name} transition page answers the edge swipe', (tester) async {
      final popped = await popsOnEdgeSwipe(
        tester,
        (state) => appTransitionPage(state: state, type: type, child: second),
      );
      expect(popped, isTrue, reason: 'on iOS this page can only be left through the app bar');
    });
  }
}
