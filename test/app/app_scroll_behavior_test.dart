@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app_scroll_behavior.dart';

/// The app's one scroll behaviour: a pull past an end neither stretches the screen nor glows, on every platform, and
/// a pull a [RefreshIndicator] is listening for still refreshes.
///
/// Both halves are platform-sensitive in opposite directions, which is why each runs over every [TargetPlatform]:
/// Material's own behaviour already answers [ClampingScrollPhysics] on Android, where the stretch is a separate
/// widget, and already builds no indicator on iOS, where the bounce is in the physics. A test run on one platform
/// only would therefore pass against the behaviour this issue removes.
void main() {
  /// The physics the list on screen was given, after [ScrollableState] resolved it, flattened: a resolved physics is
  /// a chain, since a [ScrollView] on the primary controller puts [AlwaysScrollableScrollPhysics] in front of what
  /// the behaviour answered, and that one in front decides nothing about the overscroll.
  List<ScrollPhysics> physicsOf(WidgetTester tester) {
    final chain = <ScrollPhysics>[];
    for (
      ScrollPhysics? physics = tester.state<ScrollableState>(find.byType(Scrollable)).position.physics;
      physics != null;
      physics = physics.parent
    ) {
      chain.add(physics);
    }
    return chain;
  }

  Widget listUnderBehaviour(TargetPlatform platform, {Widget Function(Widget list)? wrap}) {
    final list = ListView.builder(
      itemCount: 40,
      itemBuilder: (context, index) => SizedBox(height: 100, child: Text('row $index')),
    );
    return MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(platform: platform),
      home: wrap == null ? list : wrap(list),
    );
  }

  group('AppScrollBehavior', () {
    for (final platform in TargetPlatform.values) {
      testWidgets('gives a scrollable clamping, never bouncing, physics on $platform', (tester) async {
        await tester.pumpWidget(listUnderBehaviour(platform));

        expect(physicsOf(tester), contains(isA<ClampingScrollPhysics>()));
        expect(
          physicsOf(tester),
          isNot(contains(isA<BouncingScrollPhysics>())),
          reason: 'bouncing physics is the elastic overscroll itself, whichever platform asks for it',
        );
      });

      testWidgets('builds no overscroll indicator over a drag past the end on $platform', (tester) async {
        await tester.pumpWidget(listUnderBehaviour(platform));

        // Past the top, where Material 3 stretches the screen and older Android draws its glow.
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pump();

        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      });

      // The eight RefreshIndicator pulls in the app read their drag off the scrollable's overscroll, so taking the
      // overscroll away is the one change here that could silently take a refresh with it.
      testWidgets('a pull still reaches a RefreshIndicator on $platform', (tester) async {
        var refreshes = 0;
        await tester.pumpWidget(
          listUnderBehaviour(
            platform,
            wrap: (list) => RefreshIndicator(onRefresh: () async => refreshes++, child: list),
          ),
        );

        await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();

        expect(refreshes, 1);
      });
    }

    testWidgets('hands an overscroll indicator its child back untouched', (tester) async {
      const child = SizedBox.shrink();
      late Widget built;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            built = const AppScrollBehavior().buildOverscrollIndicator(
              context,
              child,
              const ScrollableDetails.vertical(),
            );
            return const SizedBox.shrink();
          },
        ),
      );

      expect(built, same(child));
    });
  });
}
