import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// Whether the device is offline, for every screen below it.
///
/// `AppConnectivityScope` in `lib/app/connectivity/` provides it from the app's `ConnectivityCubit`, so a feature reads
/// it without importing the app layer. The widgets in this file read it: [OfflineStaleMarker] for data a screen keeps
/// while offline, [OnlineOnlyAction] for an action that needs Studio, and [OnReconnect] to refresh once the device is
/// back online.
class OfflineStatus extends InheritedWidget {
  const OfflineStatus({super.key, required this.isOffline, required super.child});

  final bool isOffline;

  /// Whether the device is offline, and rebuilds [context] when that changes.
  ///
  /// Throws a [FlutterError] when no [OfflineStatus] is above [context].
  static bool isOfflineOf(BuildContext context) {
    final status = context.dependOnInheritedWidgetOfExactType<OfflineStatus>();
    if (status == null) {
      throw FlutterError(
        'OfflineStatus.isOfflineOf() was called with a context that has no OfflineStatus above it.\n'
        'AppConnectivityScope provides one above MaterialApp; a test wraps the widget in an OfflineStatus.',
      );
    }
    return status.isOffline;
  }

  @override
  bool updateShouldNotify(OfflineStatus oldWidget) => oldWidget.isOffline != isOffline;
}

/// "Offline: showing what was loaded at <time>" above data that a screen keeps on screen while the device is offline,
/// and nothing while it is online.
///
/// A screen that holds loaded data, such as the connection list, a browser level or a result view, keeps it offline
/// rather than refreshing to an error, and shows this marker with the time the data was loaded, and its date when that
/// was not today.
class OfflineStaleMarker extends StatelessWidget {
  const OfflineStaleMarker({super.key, required this.loadedAt});

  /// When the data on screen was loaded.
  final DateTime loadedAt;

  @override
  Widget build(BuildContext context) {
    if (!OfflineStatus.isOfflineOf(context)) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final loaded = loadedAt.toLocal();
    final now = clock.now().toLocal();
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(loaded),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    // Data from an earlier day names its date, so it cannot read as loaded today.
    final loadedToday = loaded.year == now.year && loaded.month == now.month && loaded.day == now.day;
    final when = loadedToday ? time : '${localizations.formatShortDate(loaded)} $time';
    return Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              S.of(context).offline_stale_data(when),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// An action that needs Studio, such as Run or Check: enabled online, and disabled offline with the reason under it.
///
/// [builder] builds the action, enabled or not; the reason shows below it while the device is offline.
class OnlineOnlyAction extends StatelessWidget {
  const OnlineOnlyAction({super.key, required this.builder});

  final Widget Function(BuildContext context, bool enabled) builder;

  @override
  Widget build(BuildContext context) {
    if (!OfflineStatus.isOfflineOf(context)) return builder(context, true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        builder(context, false),
        const SizedBox(height: AppSpacing.xs),
        Text(
          S.of(context).offline_action_unavailable,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }
}

/// Calls [onReconnect] once each time the device comes back online while [child] is mounted, so a screen refreshes
/// what it shows; opening online is not a reconnect.
class OnReconnect extends StatefulWidget {
  const OnReconnect({super.key, required this.onReconnect, required this.child});

  final VoidCallback onReconnect;
  final Widget child;

  @override
  State<OnReconnect> createState() => _OnReconnectState();
}

class _OnReconnectState extends State<OnReconnect> {
  bool? _wasOffline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isOffline = OfflineStatus.isOfflineOf(context);
    final reconnected = _wasOffline == true && !isOffline;
    _wasOffline = isOffline;
    if (reconnected) widget.onReconnect();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
