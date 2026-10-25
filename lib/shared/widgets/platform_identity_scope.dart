import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';

/// Who LibreDB Platform's `GET /api/v1/me` says the signed-in admin is, for every Platform screen below it.
///
/// [identity] is null while it is not loaded, and [failed] says that its read failed, in which case [onRetry] asks
/// again. The Platform shell provides it from the app's identity (`AppPlatformIdentityScope` in `lib/app/shell/`), so a
/// feature reads the identity without importing the app layer or the auth feature.
class PlatformIdentityScope extends InheritedWidget {
  const PlatformIdentityScope({
    super.key,
    required this.identity,
    required this.failed,
    required this.onRetry,
    required super.child,
  });

  final PlatformIdentity? identity;
  final bool failed;
  final VoidCallback onRetry;

  /// The [PlatformIdentityScope] above [context]; [context] rebuilds when it changes.
  ///
  /// Throws a [FlutterError] when there is none.
  static PlatformIdentityScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlatformIdentityScope>();
    if (scope == null) {
      throw FlutterError(
        'PlatformIdentityScope.of() was called with a context that has no PlatformIdentityScope above it.\n'
        'The Platform shell provides one above every Platform screen; a test wraps the widget in a '
        'PlatformIdentityScope.',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(PlatformIdentityScope oldWidget) =>
      oldWidget.identity != identity || oldWidget.failed != failed || oldWidget.onRetry != onRetry;
}
