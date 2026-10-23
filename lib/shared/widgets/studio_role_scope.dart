import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// The role Studio's `GET /api/auth/me` named for the signed-in user, for every screen below it.
///
/// It answers null while the identity is not loaded or its read failed, which builds the user settings of a
/// `MaskingPolicy`, so nothing shows unmasked before Studio has answered. `AppShell` in `lib/app/shell/` provides it
/// from the app's identity, so a feature reads the role without importing the app layer or the auth feature.
class StudioRoleScope extends InheritedWidget {
  const StudioRoleScope({super.key, required this.role, required super.child});

  final StudioRole? role;

  /// The role of the [StudioRoleScope] above [context], null while Studio has not named one; [context] rebuilds when
  /// it changes.
  ///
  /// Throws a [FlutterError] when there is none.
  static StudioRole? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StudioRoleScope>();
    if (scope == null) {
      throw FlutterError(
        'StudioRoleScope.of() was called with a context that has no StudioRoleScope above it.\n'
        'AppShell provides one above every signed-in screen; a test wraps the widget in a StudioRoleScope.',
      );
    }
    return scope.role;
  }

  @override
  bool updateShouldNotify(StudioRoleScope oldWidget) => oldWidget.role != role;
}
