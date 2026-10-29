@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';

import '../../../support/route_change_frames.dart';

/// Whether the placeholder keeps sweeping on a page that is being left.
///
/// The skeleton's shimmer never stops on its own: it is an `AnimationController.repeat()`, and five Platform pages
/// show one while they wait for an answer. Flutter mutes the tickers of a route only once the route above it has
/// finished arriving, so for the length of every transition out of a loading page the sweep runs on a page that is
/// on its way off the screen — motion where the transition wants stillness, and the same class of defect as the
/// animation #367 left running on a child nobody could see (#421).
///
/// The route change here draws nothing of its own: `disableAnimations` is on, which is the one branch of
/// `appTransitionPage` that returns the page unchanged, and the arriving page is transparent, so the page being left
/// keeps painting underneath it. Any pixel that changes in that window changed because something on the leaving page
/// animated, which is the whole measurement.
void main() {
  const surface = ValueKey('skeleton-route-change-surface');

  /// The frames the leaving page draws while the route change runs, and the frames it draws before it starts.
  ///
  /// `pumpAndSettle` is never used: a repeating shimmer never settles, and waiting for it to is a timeout rather
  /// than an assertion.
  Future<({int changedAtRest, int changedWhileLeaving})> framesAroundPush(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: Column(children: [AppSkeleton.text(width: 300)]),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'next',
              // Transparent on purpose: the page being left has to stay visible to be measured.
              pageBuilder: (context, state) => appTransitionPage(state: state, child: const SizedBox.expand()),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepaintBoundary(
        key: surface,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp.router(routerConfig: router, debugShowCheckedModeBanner: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The control: the sweep has to be visible to this measurement before the route change, or the answer below
    // would be "nothing moved" whatever the skeleton does.
    final before = await surfaceFrame(tester, surface);
    await tester.pump(const Duration(milliseconds: 200));
    final changedAtRest = changedPixels(before, await surfaceFrame(tester, surface));

    router.push('/next');
    await tester.pump();
    var changedWhileLeaving = 0;
    var previous = await surfaceFrame(tester, surface);
    final steps = (AppDurations.slow.inMilliseconds / 16).ceil() - 1;
    for (var step = 0; step < steps; step++) {
      await tester.pump(const Duration(milliseconds: 16));
      final frame = await surfaceFrame(tester, surface);
      changedWhileLeaving += changedPixels(previous, frame);
      previous = frame;
    }
    return (changedAtRest: changedAtRest, changedWhileLeaving: changedWhileLeaving);
  }

  testWidgets('the skeleton stops sweeping while its page is being left', (tester) async {
    final frames = await framesAroundPush(tester);

    expect(
      frames.changedAtRest,
      greaterThan(0),
      reason: 'the shimmer did not move on the page at rest either, so this measurement sees nothing at all',
    );
    expect(
      frames.changedWhileLeaving,
      0,
      reason:
          '${frames.changedWhileLeaving} pixels changed on the page being left while the route changed.\n'
          'The placeholder keeps sweeping on a page on its way off the screen; stop its ticker while the route moves.',
    );
  });
}
