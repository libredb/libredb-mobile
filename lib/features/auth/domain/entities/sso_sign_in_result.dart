import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// How a single sign-on ended, once the gate of its session target has answered whether it accepts the account.
sealed class SsoSignInResult {
  const SsoSignInResult();
}

/// The Studio session is stored and Studio accepted it: [identity] is Studio's `GET /api/auth/me` answer.
final class StudioSignInSucceeded extends SsoSignInResult {
  const StudioSignInSucceeded(this.identity);

  final StudioIdentity identity;
}

/// The Platform session is stored and Platform accepted it: [identity] is Platform's `GET /api/v1/me` answer.
final class PlatformSignInSucceeded extends SsoSignInResult {
  const PlatformSignInSucceeded(this.identity);

  final PlatformIdentity identity;
}

/// The user left the provider page without signing in.
final class SsoSignInCancelled extends SsoSignInResult {
  const SsoSignInCancelled();
}

/// The sign-in failed, or the gate of its target does not accept the account; nothing is stored. [errorCode] is shown
/// to the user.
final class SsoSignInRejected extends SsoSignInResult {
  const SsoSignInRejected(this.errorCode);

  final AppErrorCode errorCode;
}

/// How the sign-in at the identity provider ended, before the gate of its target is asked about the account.
sealed class SsoProviderSignIn {
  const SsoProviderSignIn();
}

/// The provider signed the user in, and its tokens are stored as the session.
final class SsoProviderSignedIn extends SsoProviderSignIn {
  const SsoProviderSignedIn();
}

/// The user left the provider page without signing in.
final class SsoProviderCancelled extends SsoProviderSignIn {
  const SsoProviderCancelled();
}

/// The provider sign-in failed, or its answer could not be stored; nothing is stored.
final class SsoProviderRejected extends SsoProviderSignIn {
  const SsoProviderRejected(this.errorCode);

  final AppErrorCode errorCode;
}
