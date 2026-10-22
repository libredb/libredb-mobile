import 'package:flutter/widgets.dart';

/// How a connection screen reports a governance outage and words it, for every screen below it.
///
/// A connection route's own 503 `GOVERNANCE_UNAVAILABLE` is the outage. The screen calls [reportOutage] when it starts
/// showing one and [reportRecovered] when the route answers anything else again, and shows [noticeBuilder]'s wording,
/// which Studio's readiness and the user's role choose. `AppShell` in `lib/app/shell/` provides it from the app's
/// Studio status and identity, so a feature reads it without importing the app layer or another feature.
class GovernanceStatus extends InheritedWidget {
  const GovernanceStatus({
    super.key,
    required this.reportOutage,
    required this.reportRecovered,
    required this.noticeBuilder,
    required super.child,
  });

  final VoidCallback reportOutage;
  final VoidCallback reportRecovered;

  /// Builds the outage's wording; it rebuilds itself when the wording changes.
  final WidgetBuilder noticeBuilder;

  /// The [GovernanceStatus] above [context].
  ///
  /// Throws a [FlutterError] when there is none.
  static GovernanceStatus of(BuildContext context) {
    final status = context.getInheritedWidgetOfExactType<GovernanceStatus>();
    if (status == null) {
      throw FlutterError(
        'GovernanceStatus.of() was called with a context that has no GovernanceStatus above it.\n'
        'AppShell provides one above every signed-in screen; a test wraps the widget in a GovernanceStatus.',
      );
    }
    return status;
  }

  @override
  bool updateShouldNotify(GovernanceStatus oldWidget) =>
      oldWidget.reportOutage != reportOutage ||
      oldWidget.reportRecovered != reportRecovered ||
      oldWidget.noticeBuilder != noticeBuilder;
}
