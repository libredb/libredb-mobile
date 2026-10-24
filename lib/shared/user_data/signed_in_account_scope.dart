import 'package:flutter/widgets.dart';

/// Signs out the user through the app's sign-out and opens the login page; it asks for no confirmation.
///
/// It takes no context: the page that starts it closes during the sign-out, when Studio's identity is cleared.
typedef SignOutAction = Future<void> Function();

/// The signed-in account, as a page that removes its data needs it: the identity provider's subject Studio's
/// `GET /api/auth/me` named, and the app's sign-out.
///
/// `AppShell` in `lib/app/shell/` provides it, so a feature reads it without importing the app layer or the auth
/// feature.
class SignedInAccountScope extends InheritedWidget {
  const SignedInAccountScope({super.key, required this.subject, required this.signOut, required super.child});

  /// The subject, null while Studio has named none.
  final String? subject;

  final SignOutAction signOut;

  /// The [SignedInAccountScope] above [context], which rebuilds when it changes.
  ///
  /// Throws a [FlutterError] when there is none.
  static SignedInAccountScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SignedInAccountScope>();
    if (scope == null) {
      throw FlutterError(
        'SignedInAccountScope.of() was called with a context that has no SignedInAccountScope above it.\n'
        'AppShell provides one above every signed-in screen; a test wraps the widget in a SignedInAccountScope.',
      );
    }
    return scope;
  }

  /// Only a new subject notifies: the provider builds a new [signOut] closure each time, which signs out the same way.
  @override
  bool updateShouldNotify(SignedInAccountScope oldWidget) => oldWidget.subject != subject;
}
