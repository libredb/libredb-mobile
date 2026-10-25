import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/target_reachability.dart';

/// Whether Studio and Platform answer their liveness checks, for the login page, with a way to ask one again.
///
/// The app layer builds it from its Studio and Platform status blocs above the router, so the login page reads it
/// without importing another feature or the app layer.
class TargetReachabilityScope extends InheritedWidget {
  const TargetReachabilityScope({
    super.key,
    required this.studio,
    required this.platform,
    required this.onRetry,
    required super.child,
  });

  /// Whether Studio answers.
  final TargetReachability studio;

  /// Whether Platform answers; [TargetReachability.unknown] in a build without a Platform target, which never asks.
  final TargetReachability platform;

  /// Asks the server of a target again, as a retry.
  final void Function(SessionTarget target) onRetry;

  /// The reachability of [target].
  TargetReachability of(SessionTarget target) => switch (target) {
    SessionTarget.studio => studio,
    SessionTarget.platform => platform,
  };

  /// The scope above [context], which rebuilds when a reachability changes, or null when there is none: a page
  /// mounted without the app, such as under a test router, has no check to show, as before any check.
  static TargetReachabilityScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TargetReachabilityScope>();

  @override
  bool updateShouldNotify(TargetReachabilityScope oldWidget) =>
      oldWidget.studio != studio || oldWidget.platform != platform || oldWidget.onRetry != onRetry;
}
