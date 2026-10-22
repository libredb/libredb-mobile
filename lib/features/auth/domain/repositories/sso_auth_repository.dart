import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';

/// Signs the user in through the OpenID Connect provider and stores the session the sign-in gives.
abstract class ISsoAuthRepository {
  /// Signs the user in through the provider's page.
  Future<SsoProviderSignIn> signIn();
}
