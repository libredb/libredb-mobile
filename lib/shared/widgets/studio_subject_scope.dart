import 'package:flutter/widgets.dart';

/// The account Studio's `GET /api/auth/me` named for the signed-in user, as the SHA-256 hex of its subject
/// (`lib/shared/utils/subject_hash.dart`), which keys what the phone keeps per account, such as the statement history.
///
/// It answers null while Studio has named no subject, when nothing is kept per account. `AppShell` in `lib/app/shell/`
/// provides it from the app's identity, so a feature reads it without importing the app layer or the auth feature.
class StudioSubjectScope extends InheritedWidget {
  const StudioSubjectScope({super.key, required this.subjectHash, required super.child});

  final String? subjectHash;

  /// The subject hash of the [StudioSubjectScope] above [context], null while Studio has named no subject; [context]
  /// rebuilds when it changes.
  ///
  /// Throws a [FlutterError] when there is none.
  static String? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StudioSubjectScope>();
    if (scope == null) {
      throw FlutterError(
        'StudioSubjectScope.of() was called with a context that has no StudioSubjectScope above it.\n'
        'AppShell provides one above every signed-in screen; a test wraps the widget in a StudioSubjectScope.',
      );
    }
    return scope.subjectHash;
  }

  @override
  bool updateShouldNotify(StudioSubjectScope oldWidget) => oldWidget.subjectHash != subjectHash;
}
