import 'package:libredb_mobile/app/router/app_routes_constants.dart';

/// Where the introduction hands the user over: the login page, carrying [returnUrl] when the first run was heading
/// somewhere in particular, so the deep link survives the introduction.
///
/// A pure function in `navigation/` rather than a getter on the page, because it is a route concern and not text on
/// a screen — the same slot `login_destination` occupies. The login page re-validates the value through
/// `safeReturnPath` before honoring it, so nothing here has to.
String onboardingDestination({required String? returnUrl}) {
  if (returnUrl == null) return ApplicationRoutesConstants.login;
  return '${ApplicationRoutesConstants.login}?returnUrl=${Uri.encodeQueryComponent(returnUrl)}';
}
