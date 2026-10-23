import 'dart:async';

import 'package:flutter/widgets.dart';

/// The app's lifecycle as a source a bloc can follow, injected so tests drive it.
abstract interface class IAppLifecycleSource {
  /// The state now, null before the platform told one.
  AppLifecycleState? get current;

  /// Each change of the state.
  Stream<AppLifecycleState> get changes;
}

/// Whether [state] means the app is off the screen: `hidden`, `paused` or `detached`. `inactive` is not, since iOS
/// also reports it for a system sheet or the Control Center over the app, and the platform keeps the app running then.
bool isInBackground(AppLifecycleState? state) => switch (state) {
  AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => true,
  AppLifecycleState.resumed || AppLifecycleState.inactive || null => false,
};

/// The binding's lifecycle, through an [AppLifecycleListener]; [dispose] removes the listener.
class BindingAppLifecycleSource implements IAppLifecycleSource {
  BindingAppLifecycleSource() {
    _listener = AppLifecycleListener(onStateChange: _changes.add);
  }

  late final AppLifecycleListener _listener;
  final _changes = StreamController<AppLifecycleState>.broadcast(sync: true);

  @override
  AppLifecycleState? get current => WidgetsBinding.instance.lifecycleState;

  @override
  Stream<AppLifecycleState> get changes => _changes.stream;

  Future<void> dispose() {
    _listener.dispose();
    return _changes.close();
  }
}
