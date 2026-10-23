import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';

/// Background execution time the platform grants while a statement runs, so a short switch to another app does not
/// end the run's request.
///
/// iOS suspends an app's sockets soon after it leaves the screen, and Studio cancels a run whose request drops
/// (libredb-studio `src/lib/api/abort-cancel.ts`), so on iOS the run asks `UIApplication.beginBackgroundTask` through
/// [ChannelBackgroundRunTime] and gives the time back when its answer arrives. Android keeps a backgrounded process's
/// socket for a while, so [NoBackgroundRunTime] asks nothing.
abstract interface class IBackgroundRunTime {
  /// Asks for background time at once; the lease's [BackgroundRunLease.end] gives it back.
  BackgroundRunLease begin();
}

/// Background time asked for one run. [end] gives it back once, also when it is called before the platform answered
/// the request; a later call does nothing.
abstract interface class BackgroundRunLease {
  Future<void> end();
}

/// The background time of the platform the app runs on.
abstract final class BackgroundRunTime {
  static IBackgroundRunTime forPlatform() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => const ChannelBackgroundRunTime(),
    _ => const NoBackgroundRunTime(),
  };
}

/// iOS: `beginBackgroundTask` and `endBackgroundTask` through a method channel that `AppDelegate` answers. The native
/// side ends a task itself when its time runs out, as iOS requires, and ignores a later end of it.
///
/// A begin the platform refused is logged as an error and the run goes on without background time, so a switch to
/// another app may still interrupt it; the run's own answer, or the interrupted message, tells the user what happened.
/// A refused end is logged as an error too; iOS then ends the task itself when its time runs out.
class ChannelBackgroundRunTime implements IBackgroundRunTime {
  const ChannelBackgroundRunTime();

  static const channel = MethodChannel('org.libredb.mobile/background_run_time');

  static final _log = AppLogger.getLogger('BackgroundRunTime');

  @override
  BackgroundRunLease begin() => _ChannelLease(_begin());

  static Future<int?> _begin() async {
    try {
      return await channel.invokeMethod<int>('begin');
    } on Object catch (error) {
      _log.error('background time not granted: {}', [error]);
      return null;
    }
  }
}

class _ChannelLease implements BackgroundRunLease {
  _ChannelLease(this._id);

  final Future<int?> _id;
  bool _ended = false;

  @override
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    final id = await _id;
    if (id == null) return;
    try {
      await ChannelBackgroundRunTime.channel.invokeMethod<void>('end', {'id': id});
    } on Object catch (error) {
      ChannelBackgroundRunTime._log.error('background time not given back: {}', [error]);
    }
  }
}

/// Android: nothing is asked, since the process normally keeps its socket for a while after it leaves the screen.
class NoBackgroundRunTime implements IBackgroundRunTime {
  const NoBackgroundRunTime();

  @override
  BackgroundRunLease begin() => const _NoLease();
}

class _NoLease implements BackgroundRunLease {
  const _NoLease();

  @override
  Future<void> end() async {}
}
