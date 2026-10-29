@Tags(['widget'])
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';

import '../../../support/route_change_frames.dart';

/// What a page transition draws while it runs, frame by frame.
///
/// A golden renders one resting frame and the edge-swipe guard next door proves a page can be left again. Neither
/// looks at the frames in between, which is where a hand-written transition goes wrong: the builder is handed
/// `secondaryAnimation` — the page's own "I am being covered" — and a builder that ignores it leaves the page it is
/// drawing fully opaque while the next one fades in over it. The two screens are then composited for the length of
/// the transition, which is what was reported from the device as a glitch rather than as a transition (#421).
///
/// Measured on `cae7504a`, with a 360 ms `fade`: 100% of the surface drawn from both pages for 14 consecutive frames
/// (t=80 ms to t=288 ms). `slideUp` peaked at 98.9%, `slideRight` at 95.9%.
///
/// Both ways in are measured, because the app navigates both ways and they take different paths through the
/// Navigator: a tab moves between two pages of the same shell, which replaces one with the other, and a drill-down
/// pushes a page over the one it came from. The tab change was 100% drawn twice for the same 14 frames.
///
/// The fixture is two pages of one flat colour each, in channels that cannot be confused — the page being left is
/// pure red, the page arriving pure blue, the backdrop behind them pure green. A pixel with both red and blue in it
/// can only have come from compositing the two pages, so "drawn twice" is counted rather than argued.
/// How the app leaves a page: a tab replaces it with its sibling, a drill-down pushes the next one over it.
enum RouteChange { tab, drillDown }

void main() {
  const surface = ValueKey('route-change-surface');
  const leavingColour = Color(0xFFFF0000);
  const arrivingColour = Color(0xFF0000FF);
  const backdropColour = Color(0xFF00FF00);

  /// How much of the screen may show both pages at once.
  ///
  /// Not zero: a page sliding in blends one column of pixels with whatever is under it along its own edge, and the
  /// surface is 800 px wide, so a single antialiased edge is 0.125% of it. 2% is room for a few such edges and
  /// nothing like the 96–100% the defect drew.
  const maxDrawnTwice = 0.02;

  /// What one frame of the route change is made of, as shares of the surface between 0 and 1.
  ///
  /// [drawnTwice] is the share where both pages contribute colour. [backdrop] is the share where neither does, which
  /// is the hole a transition would leave if it hid both pages at once instead of handing one over to the other.
  ({double drawnTwice, double leaving, double arriving, double backdrop}) partsOf(Uint8List pixels) {
    var drawnTwice = 0, leaving = 0, arriving = 0, backdrop = 0;
    for (var at = 0; at + 4 <= pixels.length; at += 4) {
      // Above the 8/255 floor rather than above zero: a page at 2% opacity is not a page a person can see, and
      // counting it would make the measurement an assertion about floating point rather than about the screen.
      final hasLeaving = pixels[at] > 8;
      final hasArriving = pixels[at + 2] > 8;
      if (hasLeaving && hasArriving) {
        drawnTwice++;
      } else if (hasLeaving) {
        leaving++;
      } else if (hasArriving) {
        arriving++;
      } else {
        backdrop++;
      }
    }
    final total = pixels.length / 4;
    return (
      drawnTwice: drawnTwice / total,
      leaving: leaving / total,
      arriving: arriving / total,
      backdrop: backdrop / total,
    );
  }

  /// Every 16 ms frame of a [change] between two [type] pages, from the navigation to past the end of the transition.
  Future<List<({double drawnTwice, double leaving, double arriving, double backdrop})>> framesOf(
    WidgetTester tester,
    AppPageTransitionType type,
    RouteChange change,
  ) async {
    Page<void> page(GoRouterState state, Color colour) => appTransitionPage(
      state: state,
      type: type,
      child: ColoredBox(color: colour),
    );

    final router = GoRouter(
      routes: [
        // Inside a shell, as every page built with `appTransitionPage` is: both shells hold their tabs this way, and
        // the shell's own Scaffold is what a frame drawing neither page would show.
        ShellRoute(
          pageBuilder: (context, state, child) => appPlatformPage(
            state: state,
            // The shell's own surface is the backdrop colour, not the theme's white: white holds red and blue
            // alike, and a classifier that reads the two pages out of those channels would count the shell
            // as both of them at once.
            child: Scaffold(backgroundColor: backdropColour, body: child),
          ),
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => page(state, leavingColour),
              routes: [GoRoute(path: 'deeper', pageBuilder: (context, state) => page(state, arrivingColour))],
            ),
            GoRoute(path: '/sibling', pageBuilder: (context, state) => page(state, arrivingColour)),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepaintBoundary(
        key: surface,
        child: ColoredBox(
          color: backdropColour,
          child: MaterialApp.router(routerConfig: router, debugShowCheckedModeBanner: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    switch (change) {
      case RouteChange.tab:
        router.go('/sibling');
      case RouteChange.drillDown:
        router.push('/deeper');
    }

    final frames = <({double drawnTwice, double leaving, double arriving, double backdrop})>[];
    // Past the end of the longer of the two durations, so the frames cover the whole transition and its last frame.
    final steps = (AppDurations.slow.inMilliseconds / 16).ceil() + 2;
    for (var step = 0; step <= steps; step++) {
      await tester.pump(step == 0 ? Duration.zero : const Duration(milliseconds: 16));
      frames.add(partsOf(await surfaceFrame(tester, surface)));
    }
    await tester.pumpAndSettle();
    return frames;
  }

  for (final type in AppPageTransitionType.values) {
    for (final change in RouteChange.values) {
      testWidgets('a ${type.name} ${change.name} never draws the two pages on top of each other', (tester) async {
        final frames = await framesOf(tester, type, change);
        final worst = frames.map((frame) => frame.drawnTwice).reduce(max);
        final at = frames.indexWhere((frame) => frame.drawnTwice == worst);

        expect(
          worst,
          lessThan(maxDrawnTwice),
          reason:
              'at t=${at * 16} ms, ${(worst * 100).toStringAsFixed(1)}% of the screen is composited from both '
              'pages.\nThe page being left has to leave before the next one is drawn, rather than stay opaque '
              'under it.',
        );
      });

      testWidgets('a ${type.name} ${change.name} replaces one page with the other', (tester) async {
        final frames = await framesOf(tester, type, change);

        // The measurement has to see a route change at all, or the guard above would pass on a blank screen.
        expect(frames.first.leaving, greaterThan(0.9), reason: 'the route change did not start from the first page');
        expect(frames.last.arriving, greaterThan(0.9), reason: 'the route change did not end on the second page');

        // And the hand-over has to be a hand-over. Hiding both pages would satisfy the overlap guard above and read
        // as a flash of the shell with nothing in it, which is the other way to get this wrong: a full-width
        // slide-in did exactly that, 93% of the surface showing nothing but the shell at the hand-over. The worst
        // frame now shows 27.9%, so half the screen is a bound with room in it and no room for that.
        final emptiest = frames.map((frame) => frame.backdrop).reduce(max);
        expect(
          emptiest,
          lessThan(0.5),
          reason:
              '${(emptiest * 100).toStringAsFixed(1)}% of a frame shows neither page — the transition empties the '
              'screen instead of handing one page over to the other',
        );
      });
    }
  }
}
