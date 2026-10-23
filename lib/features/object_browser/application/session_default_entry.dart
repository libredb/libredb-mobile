import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';

/// Decides when a container level opens its session-default container by itself: on the first entry of a connection
/// only, so a user who goes back to the level stays there.
///
/// The first entry starts each time another connection becomes active, as [connectionIds] tells, and opening Browse
/// again for the same connection is no first entry. On it, the top level opens its session-default container, and each
/// level opened that way opens its own in turn, so the user lands where a statement runs when it names no container.
class SessionDefaultEntry {
  SessionDefaultEntry(Stream<String?> connectionIds) {
    _subscription = connectionIds.listen((_) {
      _entered = null;
      _opened = null;
    });
  }

  late final StreamSubscription<String?> _subscription;

  /// The connection whose first entry has been used.
  String? _entered;

  /// The container the first entry opened last, whose level may open its own session default.
  List<String>? _opened;

  /// The container the level under [parent] of [connectionId] opens by itself now, or null; called once per level,
  /// with the containers of its first answer.
  ObjectContainer? take(String connectionId, List<String> parent, List<ObjectContainer> containers) {
    if (parent.isEmpty) {
      if (_entered == connectionId) return null;
      _entered = connectionId;
    } else {
      final opened = _opened;
      if (_entered != connectionId || opened == null || !listEquals(opened, parent)) return null;
    }
    final open = _sessionDefaultOf(containers);
    _opened = open?.path;
    return open;
  }

  static ObjectContainer? _sessionDefaultOf(List<ObjectContainer> containers) {
    for (final container in containers) {
      if (container.isSessionDefault) return container;
    }
    return null;
  }

  Future<void> dispose() => _subscription.cancel();
}
