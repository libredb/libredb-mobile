import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Signs the user in through the OpenID Connect provider and stores the session the sign-in gives.
abstract class ISsoAuthRepository {
  /// Signs the user in through the provider's page, and stores the session for [target].
  Future<SsoProviderSignIn> signIn({required SessionTarget target});
}
