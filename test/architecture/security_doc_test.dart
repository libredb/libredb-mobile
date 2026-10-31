import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/security/idle_timeout_observer.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';

/// Holds the two clocks `docs/security.md` describes to the two the app runs.
///
/// The page's "App lock" section said the lock measures the time away "as `IdleTimeoutObserver` measures it", and
/// built its "the idle sign-out wins over the lock" reasoning on that. They are not the same clock: the lock's starts
/// when the app leaves the screen (`hidden` or `paused`, `AppLockBloc._backgroundedAt`) and the observer's starts at
/// the last input (`IdleTimeoutObserver._windowStartedAt`), which is usually earlier and may be much earlier. A reader
/// who believes the page cannot work out when the sign-out arrives instead of the lock.
///
/// So the difference is measured here rather than asserted in prose: the behaviour of both clocks is run, and the page
/// is held to naming each one's anchor and to not claiming they are the same.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final page = File(_docPath).readAsStringSync();

  test('the lock does not start its clock on an `inactive`, and the idle observer never stops counting', () {
    expect(
      isInBackground(AppLifecycleState.inactive),
      isFalse,
      reason: 'the lock counts time away only from `hidden` or `paused`, so an `inactive` is not time away',
    );

    fakeAsync((async) {
      var fired = 0;
      var now = DateTime(2026, 5, 21, 12);
      final observer = IdleTimeoutObserver(
        idleThreshold: const Duration(minutes: 15),
        onTimeout: () => fired++,
        clock: () => now,
      );
      observer.start();

      // Fourteen minutes of untouched foreground, then two minutes away: the app was away for two minutes, which no
      // lock timeout would reach, and the observer fires all the same because its window began at the last input.
      now = now.add(const Duration(minutes: 14));
      async.elapse(const Duration(minutes: 14));
      observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      now = now.add(const Duration(minutes: 2));
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(fired, 1, reason: 'the observer measures from the last input, not from the moment the app went away');
      observer.stop();
    });
  });

  test('the page does not say the two clocks are the same', () {
    expect(
      page,
      isNot(contains('as `IdleTimeoutObserver` measures it')),
      reason:
          'The lock measures from the moment the app leaves the screen; the observer measures from the last input. '
          '$_docPath must not tell a reader that one measures time as the other does.',
    );
  });

  test('the page names what each clock is anchored on', () {
    expect(
      page,
      contains('from the moment the app leaves the screen (`hidden` or `paused`)'),
      reason: '$_docPath must say where the lock starts counting.',
    );
    expect(
      page,
      contains('from the last input'),
      reason: '$_docPath must say where the inactivity sign-out starts counting.',
    );
  });

  test('the page says the idle sign-out can arrive after a stay away the lock alone would not act on', () {
    expect(
      page,
      contains('shorter than the idle period'),
      reason:
          'The observer\'s window began at the last input, so a resume it signs out on can follow a stay away far '
          'shorter than the idle period. $_docPath must say so, because its "the idle sign-out wins" paragraph '
          'otherwise reads as a promise that only a long stay away ends the session.',
    );
  });
}

const _docPath = 'docs/security.md';
