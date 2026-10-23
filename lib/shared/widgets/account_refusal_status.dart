import 'package:flutter/widgets.dart';

/// Whether Studio refuses the signed-in account, for every screen below it.
///
/// `AppShell` in `lib/app/shell/` provides it from the app's refusal of the account and covers the screens with the
/// refusal page meanwhile, so a feature reads it without importing the app layer. A screen stays mounted under the page
/// and may meet the refusal itself; [OnAccountAccepted] tells it when Studio accepts the account again.
class AccountRefusalStatus extends InheritedWidget {
  const AccountRefusalStatus({super.key, required this.isRefused, required super.child});

  final bool isRefused;

  /// Whether Studio refuses the signed-in account, and rebuilds [context] when that changes.
  ///
  /// Throws a [FlutterError] when no [AccountRefusalStatus] is above [context].
  static bool isRefusedOf(BuildContext context) {
    final status = context.dependOnInheritedWidgetOfExactType<AccountRefusalStatus>();
    if (status == null) {
      throw FlutterError(
        'AccountRefusalStatus.isRefusedOf() was called with a context that has no AccountRefusalStatus above it.\n'
        'AppShell provides one above every signed-in screen; a test wraps the widget in an AccountRefusalStatus.',
      );
    }
    return status.isRefused;
  }

  @override
  bool updateShouldNotify(AccountRefusalStatus oldWidget) => oldWidget.isRefused != isRefused;
}

/// Calls [onAccepted] once each time Studio accepts the signed-in account again after refusing it while [child] is
/// mounted, so a screen that failed under the refusal page loads again; opening accepted is not an acceptance.
///
/// The screen decides whether to load: only one whose last answer was a failure does, and never by running a statement
/// again.
class OnAccountAccepted extends StatefulWidget {
  const OnAccountAccepted({super.key, required this.onAccepted, required this.child});

  final VoidCallback onAccepted;
  final Widget child;

  @override
  State<OnAccountAccepted> createState() => _OnAccountAcceptedState();
}

class _OnAccountAcceptedState extends State<OnAccountAccepted> {
  bool? _wasRefused;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRefused = AccountRefusalStatus.isRefusedOf(context);
    final accepted = _wasRefused == true && !isRefused;
    _wasRefused = isRefused;
    if (accepted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
