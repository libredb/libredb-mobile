import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/account/data/repositories/account_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/account/domain/repositories/account_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/lifecycle/data/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/analytics/log_analytics_service.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_analytics_service.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_token_rotation.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

class AppDependencies {
  const AppDependencies({
    this.appConfig = const AppConfig.dev(),
    this.projectLinks = const ProjectLinks(),
    this.authMode = const JwtAuthMode(),
  });

  final AppConfig appConfig;

  /// The project's repository, documentation and sponsor links that the app shows.
  final ProjectLinks projectLinks;

  /// How the user signs in, read from `AUTH_PROVIDER` at bootstrap.
  final AuthMode authMode;

  /// Returns the analytics implementation appropriate for the active
  /// environment. Production + non-empty DSN → [SentryAnalyticsService]
  /// (Sentry SDK assumed already-initialized by bootstrap); any other
  /// case → [LogAnalyticsService] (local-only, no network egress).
  IAnalyticsService createAnalyticsService() {
    if (appConfig.sentryDsn != null) {
      return SentryAnalyticsService();
    }
    return LogAnalyticsService();
  }

  /// Which 401 means that the bearer is no longer valid, so the HTTP layer refreshes the session and ends it when the
  /// refresh cannot fix the 401. LibreDB Studio, the app's backend, also answers 401 for a refused database credential,
  /// so only its `AUTH_REQUIRED` code, or a 401 without a code, counts.
  SessionExpiredPredicate get sessionExpiredPredicate => isStudioSessionExpired;

  /// Which 401 for a request sent again after a refresh ends the session. Studio's `GET /api/auth/me` also answers 401
  /// without a code when Studio cannot reach the identity provider, which a new session would not fix, so only its
  /// `AUTH_REQUIRED` code counts; any other 401 reaches the caller with the session kept.
  SessionRefusedPredicate get sessionRefusedPredicate => isStudioSessionRefused;

  /// [onSessionExpired] runs when a 401 cannot be fixed by a token refresh; the caller ends the session there.
  ApiClient createApiClient(ISecureStorage secureStorage, {required OnSessionExpired onSessionExpired}) => ApiClient(
    appConfig: appConfig,
    secureStorage: secureStorage,
    onSessionExpired: onSessionExpired,
    isSessionExpired: sessionExpiredPredicate,
    isSessionRefused: sessionRefusedPredicate,
  );

  /// The [ApiClient] of an `oidc` build, which refreshes the session through [tokenRotation] instead of the backend's
  /// refresh endpoint. [onSessionExpired] runs when a 401 cannot be fixed by a token refresh.
  ApiClient createOidcApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    required TokenRotation tokenRotation,
  }) => ApiClient(
    appConfig: appConfig,
    secureStorage: secureStorage,
    onSessionExpired: onSessionExpired,
    tokenRotation: tokenRotation,
    isSessionExpired: sessionExpiredPredicate,
    isSessionRefused: sessionRefusedPredicate,
  );

  IAccountRepository createAccountRepository(ApiClient apiClient) => AccountRepository(apiClient);

  /// The logout clears the session through [sessionRepository], as the idle timeout and an unrefreshable 401 do.
  IAuthRepository createAuthRepository(IAuthSessionRepository sessionRepository, ApiClient apiClient) =>
      LoginRepository(sessionRepository: sessionRepository, apiClient: apiClient);

  /// Ending a session also clears the cache of GET responses that [ApiClient] keeps in SharedPreferences. Only an
  /// `oidc` build stores the OIDC ID token and the access token expiry.
  IAuthSessionRepository createAuthSessionRepository(ISecureStorage secureStorage) => AuthSessionRepository(
    secureStorage: secureStorage,
    cacheStorage: SharedPrefsCacheStorage(),
    oidcKeys: authMode.usesOidc,
  );

  /// The OpenID Connect client of an `oidc` build.
  IOidcClient createOidcClient(OidcSettings settings) => OidcClient(settings: settings);

  /// The single sign-on of an `oidc` build, which stores the session through [sessionRepository].
  ISsoAuthRepository createSsoAuthRepository(
    IOidcClient client,
    IAuthSessionRepository sessionRepository,
    OidcSettings settings,
  ) => SsoAuthRepository(client: client, sessionRepository: sessionRepository, settings: settings);

  /// The token refresh of an `oidc` build, through [client] at the provider's token endpoint.
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) =>
      OidcTokenRotation(client: client, secureStorage: secureStorage);

  /// Studio's connection API.
  IConnectionRepository createConnectionRepository(ApiClient apiClient) => ConnectionRepository(apiClient);

  /// Studio's session endpoint: who the signed-in user is.
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) => StudioIdentityRepository(apiClient);

  /// What the engine of a connection can do, which several features read.
  IProviderMetaRepository createProviderMetaRepository(ApiClient apiClient) => ProviderMetaRepository(apiClient);

  /// Studio's read-only object routes.
  IObjectBrowserRepository createObjectBrowserRepository(ApiClient apiClient) => ObjectBrowserRepository(apiClient);

  /// Studio's statement routes.
  ISqlEditorRepository createSqlEditorRepository(ApiClient apiClient) => SqlEditorRepository(apiClient);

  /// Reads the remote app config that decides whether the app opens, shows the maintenance screen or asks for an
  /// update.
  ILifecycleRepository createLifecycleRepository(ApiClient apiClient) => LifecycleRepository(apiClient);

  /// The device preferences, such as the language the user picked.
  AppLocalStorage createLocalStorage() => AppLocalStorage();

  ISecureStorage createSecureStorage() => FlutterSecureStorageAdapter();
}
