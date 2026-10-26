import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tells go_router to run its redirect again, whenever any of [streams] emits.
///
/// It takes a list rather than one stream because more than one cubit decides where a user belongs: the session says
/// whether they are signed in, and the introduction flag says whether they have seen it. A redirect that depends on a
/// stream nobody listens to leaves the user on a page it would now send them off — and nothing fails, which is why
/// the fan-out is tested rather than assumed.
class AppRouterRefreshNotifier extends ChangeNotifier {
  /// Listens to each stream directly. An earlier `asBroadcastStream()` here held a subscription to the source that
  /// cancelling the outer one never released, so [dispose] left the cubit with a listener for the rest of the run —
  /// invisible while the notifier lived as long as the app, and a leak as soon as one does not. A cubit's stream is
  /// already a broadcast stream, so the wrapper bought nothing.
  AppRouterRefreshNotifier(List<Stream<dynamic>> streams) {
    _subscriptions = [for (final stream in streams) stream.listen((_) => notifyListeners())];
  }

  late final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
