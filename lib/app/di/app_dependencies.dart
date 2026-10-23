import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/lifecycle/data/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/features/studio_status/data/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
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
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';
import 'package:libredb_mobile/infrastructure/storage/active_connection_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_store.dart';

/// What the app is built from. The app signs in only through the OpenID Connect provider; `main_local.dart` swaps the
/// provider for a debug-only double (`LocalSignInDependencies`), which `main_prod.dart` never imports.
class AppDependencies {
  const AppDependencies({
    required this.authMode,
    this.appConfig = const AppConfig.dev(),
    this.projectLinks = const ProjectLinks(),
  });

  final AppConfig appConfig;

  /// The project's repository, documentation and sponsor links that the app shows.
  final ProjectLinks projectLinks;

  /// The OpenID Connect settings of the build, read from the `OIDC_*` defines at bootstrap.
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

  /// Which answer refuses the signed-in account itself: Studio's 403 `BEARER_NO_ROLE` or `BEARER_NO_IDENTITY`, on any
  /// route, from libredb-studio#1922 on. No refresh fixes it, so the session stays and the shell shows the refusal page.
  AccountRefusal get accountRefusal => studioAccountRefusal;

  /// The [ApiClient], which refreshes the session through [tokenRotation] at the identity provider. [onSessionExpired]
  /// runs when a 401 cannot be fixed by a token refresh; the caller ends the session there. [onAccountRefused] is told
  /// every answer that refuses the signed-in account ([accountRefusal]).
  ApiClient createApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnAccountRefused? onAccountRefused,
    required TokenRotation tokenRotation,
  }) => ApiClient(
    appConfig: appConfig,
    secureStorage: secureStorage,
    onSessionExpired: onSessionExpired,
    tokenRotation: tokenRotation,
    isSessionExpired: sessionExpiredPredicate,
    isSessionRefused: sessionRefusedPredicate,
    onAccountRefused: onAccountRefused,
    accountRefusal: accountRefusal,
  );

  /// The logout clears the session through [sessionRepository], as the idle timeout and an unrefreshable 401 do.
  IAuthRepository createAuthRepository(IAuthSessionRepository sessionRepository) =>
      LoginRepository(sessionRepository: sessionRepository);

  /// Ending a session also clears the cache of GET responses that [ApiClient] keeps in SharedPreferences.
  IAuthSessionRepository createAuthSessionRepository(ISecureStorage secureStorage) =>
      AuthSessionRepository(secureStorage: secureStorage, cacheStorage: SharedPrefsCacheStorage());

  /// The OpenID Connect client, which talks to the identity provider.
  IOidcClient createOidcClient(OidcSettings settings) => OidcClient(settings: settings);

  /// The single sign-on, which stores the session through [sessionRepository].
  ISsoAuthRepository createSsoAuthRepository(IOidcClient client, IAuthSessionRepository sessionRepository) =>
      SsoAuthRepository(client: client, sessionRepository: sessionRepository);

  /// The token refresh, through [client] at the provider's token endpoint.
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) =>
      OidcTokenRotation(client: client, secureStorage: secureStorage);

  /// Studio's connection API.
  IConnectionRepository createConnectionRepository(ApiClient apiClient) => ConnectionRepository(apiClient);

  /// The sections of the connection list the user collapsed on this device.
  ICollapsedSectionsRepository createCollapsedSectionsRepository() => CollapsedSectionsRepository();

  /// The connections each signed-in subject starred and opened on this device.
  IFavoriteConnectionsRepository createFavoriteConnectionsRepository() => FavoriteConnectionsRepository();

  /// The connection each signed-in user had open last on this device.
  IActiveConnectionStore createActiveConnectionStore() => ActiveConnectionPreferences();

  /// Studio's session endpoint: who the signed-in user is.
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) => StudioIdentityRepository(apiClient);

  /// What the engine of a connection can do, which several features read, kept in memory for the session.
  CachedProviderMetaRepository createProviderMetaRepository(ApiClient apiClient) =>
      CachedProviderMetaRepository(ProviderMetaRepository(apiClient));

  /// Studio's read-only object routes, with their answers kept in memory for ten minutes.
  CachedObjectBrowserRepository createObjectBrowserRepository(ApiClient apiClient) =>
      CachedObjectBrowserRepository(ObjectBrowserRepository(apiClient));

  /// Studio's statement routes.
  ISqlEditorRepository createSqlEditorRepository(ApiClient apiClient) => SqlEditorRepository(apiClient);

  /// Reads the remote app config that decides whether the app opens, shows the maintenance screen or asks for an
  /// update.
  ILifecycleRepository createLifecycleRepository(ApiClient apiClient) => LifecycleRepository(apiClient);

  /// Studio's liveness and readiness, which tell an unreachable Studio apart from a session failure.
  IStudioStatusRepository createStudioStatusRepository(ApiClient apiClient) => StudioStatusRepository(apiClient);

  /// The device preferences, such as the language the user picked.
  AppLocalStorage createLocalStorage() => AppLocalStorage();

  ISecureStorage createSecureStorage() => FlutterSecureStorageAdapter();
}
