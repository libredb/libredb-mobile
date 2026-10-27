import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Whether the login page may still send the user to the identity provider on its own, without a tap.
///
/// The automatic redirect fires at most once per app run, and never after a sign-in error, a cancel or a user logout:
/// each of those closes the gate for the rest of the run, so no redirect loop can start. The gate starts open and
/// never opens again.
final class SsoAutoRedirectGate {
  bool _open = true;

  bool get isOpen => _open;

  void close() => _open = false;
}

/// Whether the login page should send the user to the provider without a tap, and which entry it would use.
///
/// Null means it should not. The rules, all four of which have to hold:
///
/// * the build signs in through a provider that asked for it (`autoRedirect`);
/// * there is exactly one entry, because a build that offers a choice must let the user make it;
/// * the gate is still open, so no redirect has fired and nothing has closed it;
/// * no error is on screen — a redirect over an error is the loop the gate exists to prevent, and the error is read
///   from the same function the page's error line reads, so the two cannot disagree.
///
/// A function rather than four conditions inside the page's `State`, so the rules can be read and checked without
/// pumping a screen with a router and a bloc (#379).
///
/// [gateIsOpen] and [hasError] are read only once the first two rules have passed, because the page answers them
/// from providers a build that cannot auto-redirect may not have at all — a golden renders the screen with neither.
SessionTarget? autoRedirectTarget({
  required AuthMode mode,
  required List<SessionTarget> entries,
  required bool Function() gateIsOpen,
  required bool Function() hasError,
}) {
  if (mode is! OidcAuthMode || !mode.settings.autoRedirect) return null;
  if (entries.length != 1) return null;
  if (!gateIsOpen() || hasError()) return null;
  return switch (entries) {
    [final target] => target,
    _ => null,
  };
}
