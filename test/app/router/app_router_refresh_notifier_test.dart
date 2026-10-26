import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_router_refresh_notifier.dart';

/// What makes go_router re-run its redirect.
///
/// It took a single stream — the session's — and had no test of its own, which was survivable while the session was
/// the only thing a redirect depended on. It is not survivable once a second cubit decides a route: an event on the
/// stream the notifier does not listen to leaves the user on a page the redirect would now send them off.
///
/// So the thing to pin is the fan-out: **any** of the streams notifies, and `dispose` cancels **every** subscription.
/// A notifier that keeps listening after disposal calls `notifyListeners` on a disposed `ChangeNotifier`, which throws
/// in debug and is silent in release — the worst shape of bug to find later.
void main() {
  test('notifies on an event from its one stream', () async {
    final session = StreamController<Object>.broadcast();
    final notifier = AppRouterRefreshNotifier([session.stream]);
    var notified = 0;
    notifier.addListener(() => notified++);

    session.add('signed in');
    await Future<void>.delayed(Duration.zero);

    expect(notified, 1);

    notifier.dispose();
    await session.close();
  });

  test('notifies on an event from any of its streams, not only the first', () async {
    final session = StreamController<Object>.broadcast();
    final onboarding = StreamController<Object>.broadcast();
    final notifier = AppRouterRefreshNotifier([session.stream, onboarding.stream]);
    var notified = 0;
    notifier.addListener(() => notified++);

    onboarding.add('seen');
    await Future<void>.delayed(Duration.zero);

    expect(notified, 1, reason: 'the second stream was not listened to');

    session.add('signed out');
    await Future<void>.delayed(Duration.zero);

    expect(notified, 2);

    notifier.dispose();
    await session.close();
    await onboarding.close();
  });

  test('notifies once per event, so one change does not re-run the redirect twice', () async {
    final session = StreamController<Object>.broadcast();
    final onboarding = StreamController<Object>.broadcast();
    final notifier = AppRouterRefreshNotifier([session.stream, onboarding.stream]);
    var notified = 0;
    notifier.addListener(() => notified++);

    session.add('signed in');
    await Future<void>.delayed(Duration.zero);

    expect(notified, 1);

    notifier.dispose();
    await session.close();
    await onboarding.close();
  });

  test('stops listening to every stream on dispose, so no event reaches a disposed notifier', () async {
    final session = StreamController<Object>.broadcast();
    final onboarding = StreamController<Object>.broadcast();
    final notifier = AppRouterRefreshNotifier([session.stream, onboarding.stream]);

    notifier.dispose();
    session.add('signed out');
    onboarding.add('seen');
    await Future<void>.delayed(Duration.zero);

    expect(session.hasListener, isFalse);
    expect(onboarding.hasListener, isFalse);

    await session.close();
    await onboarding.close();
  });

  test('takes no stream at all, so a build with nothing to watch still mounts a router', () async {
    final notifier = AppRouterRefreshNotifier(const []);

    expect(notifier.dispose, returnsNormally);
  });
}
