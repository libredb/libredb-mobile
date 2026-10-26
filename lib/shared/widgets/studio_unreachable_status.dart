import 'package:flutter/widgets.dart';

/// Whether Studio's unreachable page covers the screens below it, for every screen below it.
///
/// `StudioStatusGate` in `lib/features/studio_status/` provides it around the screens it covers, so a feature reads it
/// without importing that feature. A screen stays mounted under the page and may load, and fail, while covered;
/// [OnStudioReachable] tells it when Studio answers again and the page uncovers it.
class StudioUnreachableStatus extends InheritedWidget {
  const StudioUnreachableStatus({super.key, required this.isUnreachable, required super.child});

  final bool isUnreachable;

  /// Whether Studio's unreachable page covers [context], and rebuilds [context] when that changes.
  ///
  /// Throws a [FlutterError] when no [StudioUnreachableStatus] is above [context].
  static bool isUnreachableOf(BuildContext context) {
    final status = context.dependOnInheritedWidgetOfExactType<StudioUnreachableStatus>();
    if (status == null) {
      throw FlutterError(
        'StudioUnreachableStatus.isUnreachableOf() was called with a context that has no StudioUnreachableStatus '
        'above it.\n'
        'StudioStatusGate provides one around the app; a test wraps the widget in a StudioUnreachableStatus.',
      );
    }
    return status.isUnreachable;
  }

  @override
  bool updateShouldNotify(StudioUnreachableStatus oldWidget) => oldWidget.isUnreachable != isUnreachable;
}

/// Calls [onReachable] once each time Studio's unreachable page uncovers [child] after covering it while [child] is
/// mounted, so a screen that failed under the page loads again; opening uncovered is not a recovery.
///
/// The screen decides whether to load: only one whose last answer was a failure does, and never by running a statement
/// again.
class OnStudioReachable extends StatefulWidget {
  const OnStudioReachable({super.key, required this.onReachable, required this.child});

  final VoidCallback onReachable;
  final Widget child;

  @override
  State<OnStudioReachable> createState() => _OnStudioReachableState();
}

class _OnStudioReachableState extends State<OnStudioReachable> {
  bool? _wasUnreachable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isUnreachable = StudioUnreachableStatus.isUnreachableOf(context);
    final reachable = _wasUnreachable == true && !isUnreachable;
    _wasUnreachable = isUnreachable;
    if (reachable) widget.onReachable();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
