import 'package:flutter/widgets.dart';

/// Whether Platform's unreachable page covers the screens below it, for every screen below it: the mirror of
/// `StudioUnreachableStatus`.
///
/// `PlatformStatusGate` in `lib/features/platform_status/` provides it around the screens it covers, so a feature reads
/// it without importing that feature. A screen stays mounted under the page and may load, and fail, while covered;
/// [OnPlatformReachable] tells it when Platform answers again and the page uncovers it.
class PlatformUnreachableStatus extends InheritedWidget {
  const PlatformUnreachableStatus({super.key, required this.isUnreachable, required super.child});

  final bool isUnreachable;

  /// Whether Platform's unreachable page covers [context], and rebuilds [context] when that changes.
  ///
  /// Throws a [FlutterError] when no [PlatformUnreachableStatus] is above [context].
  static bool isUnreachableOf(BuildContext context) {
    final status = context.dependOnInheritedWidgetOfExactType<PlatformUnreachableStatus>();
    if (status == null) {
      throw FlutterError(
        'PlatformUnreachableStatus.isUnreachableOf() was called with a context that has no PlatformUnreachableStatus '
        'above it.\n'
        'PlatformStatusGate provides one around the app; a test wraps the widget in a PlatformUnreachableStatus.',
      );
    }
    return status.isUnreachable;
  }

  @override
  bool updateShouldNotify(PlatformUnreachableStatus oldWidget) => oldWidget.isUnreachable != isUnreachable;
}

/// Calls [onReachable] once each time Platform's unreachable page uncovers [child] after covering it while [child] is
/// mounted, so a screen that failed under the page loads again; opening uncovered is not a recovery.
///
/// The screen decides whether to load: only one whose last answer was a failure does, and never by sending a write
/// again.
class OnPlatformReachable extends StatefulWidget {
  const OnPlatformReachable({super.key, required this.onReachable, required this.child});

  final VoidCallback onReachable;
  final Widget child;

  @override
  State<OnPlatformReachable> createState() => _OnPlatformReachableState();
}

class _OnPlatformReachableState extends State<OnPlatformReachable> {
  bool? _wasUnreachable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isUnreachable = PlatformUnreachableStatus.isUnreachableOf(context);
    final reachable = _wasUnreachable == true && !isUnreachable;
    _wasUnreachable = isUnreachable;
    if (reachable) widget.onReachable();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
