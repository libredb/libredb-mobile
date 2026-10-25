import 'package:libredb_mobile/features/app_lock/data/repositories/app_lock_settings_preferences.dart';
import 'package:libredb_mobile/features/app_lock/data/services/channel_recents_preview.dart';
import 'package:libredb_mobile/features/app_lock/data/services/local_auth_device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/domain/repositories/app_lock_settings_repository.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/recents_preview.dart';
import 'package:libredb_mobile/features/auth/application/usecases/switch_session_target_usecase.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_grant_repository.dart';
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
import 'package:libredb_mobile/features/sql_editor/data/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/platform_connections/data/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/platform_audit/data/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/features/platform_audit/domain/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/platform_status/data/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/features/platform_status/domain/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/features/studio_status/data/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/analytics/log_analytics_service.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/security/screen_capture_platform.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';
import 'package:libredb_mobile/infrastructure/analytics/sentry_analytics_service.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_token_rotation.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinning_adapter.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_session_policy.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/statement_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_session_policy.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/infrastructure/storage/active_catalog_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/active_connection_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/encrypted_text_file_store.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/result_view_mode_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_store.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_store.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';

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
  /// route, from libredb-studio#1922 on. No refresh fixes it, so the session stays and the shell shows the refusal
  /// page.
  AccountRefusal get accountRefusal => studioAccountRefusal;

  /// The [ApiClient], which refreshes the session through [tokenRotation] at the identity provider. [onSessionExpired]
  /// runs when the token refresh fails; the caller ends the session there. [onSessionRefused] runs when Studio refuses
  /// the token a refresh has just issued ([sessionRefusedPredicate]), and [onSessionExpired] does when it is null.
  /// [onAccountRefused] is told every answer that refuses the signed-in account ([accountRefusal]).
  ApiClient createApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    required TokenRotation tokenRotation,
  }) => ApiClient(
    appConfig: appConfig,
    secureStorage: secureStorage,
    onSessionExpired: onSessionExpired,
    onSessionRefused: onSessionRefused,
    tokenRotation: tokenRotation,
    isSessionExpired: sessionExpiredPredicate,
    isSessionRefused: sessionRefusedPredicate,
    onAccountRefused: onAccountRefused,
    accountRefusal: accountRefusal,
  );

  // --- LibreDB Platform (Platform mode) ---

  /// Which 401 of LibreDB Platform starts a token refresh: a 401 `BEARER_INVALID`. A 401 without Platform's envelope,
  /// or any 502 or 503, reaches the caller and keeps the session.
  SessionExpiredPredicate get platformSessionExpiredPredicate => isPlatformSessionExpired;

  /// Which 401 of LibreDB Platform for a request sent again after a refresh ends the session: a 401 `BEARER_INVALID`.
  SessionRefusedPredicate get platformSessionRefusedPredicate => isPlatformSessionRefused;

  /// Which answer of LibreDB Platform refuses the signed-in admin itself: a 403 `ADMIN_ROLE_REQUIRED` or
  /// `LICENSE_ADMIN_SEATS`. No refresh fixes it, so the session stays and the Platform shell shows the refusal page.
  AccountRefusal get platformAccountRefusalOf => platformAccountRefusal;

  /// The [PlatformApiClient], built from [AppConfig.platform], which refreshes the session through [tokenRotation], the
  /// same rotation as the Studio [ApiClient]. [onSessionExpired] runs when the token refresh fails, and
  /// [onSessionRefused] when a 401 `BEARER_INVALID` survives the refresh ([onSessionExpired] when it is null);
  /// [onAccountRefused] is told every answer that refuses the signed-in admin ([platformAccountRefusalOf]). In a build
  /// without a Platform target every call fails without a request.
  PlatformApiClient createPlatformApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    required TokenRotation tokenRotation,
  }) => PlatformApiClient(
    appConfig: appConfig,
    secureStorage: secureStorage,
    onSessionExpired: onSessionExpired,
    onSessionRefused: onSessionRefused,
    tokenRotation: tokenRotation,
    isSessionExpired: platformSessionExpiredPredicate,
    isSessionRefused: platformSessionRefusedPredicate,
    onAccountRefused: onAccountRefused,
    accountRefusal: platformAccountRefusalOf,
  );

  /// The app's one screen capture protection, which every `ScreenCaptureGuard` holds a lease of, switched by
  /// [AppConfig.screenCaptureProtection]: switched off, a guard takes no lease and every screen can be captured.
  ScreenCaptureProtection createScreenCaptureProtection() =>
      ScreenCaptureProtection(platform: const ScreenCapturePlatform(), enabled: appConfig.screenCaptureProtection);

  /// The app lock settings, kept in the device preferences.
  IAppLockSettingsRepository createAppLockSettingsRepository() => AppLockSettingsPreferences();

  /// The device's biometrics and screen lock, which open the app lock.
  IDeviceAuthenticator createDeviceAuthenticator() => LocalAuthDeviceAuthenticator();

  /// The switch of the app's recent-apps preview, which the app lock turns off while it is on.
  IRecentsPreview createRecentsPreview() => const ChannelRecentsPreview();

  /// The logout clears the session through [sessionRepository], as the idle timeout and an unrefreshable 401 do.
  IAuthRepository createAuthRepository(IAuthSessionRepository sessionRepository) =>
      LoginRepository(sessionRepository: sessionRepository);

  /// Ending a session also clears the cache of GET responses that [ApiClient] keeps in SharedPreferences, and the files
  /// the share sheet got.
  IAuthSessionRepository createAuthSessionRepository(ISecureStorage secureStorage) => AuthSessionRepository(
    secureStorage: secureStorage,
    cacheStorage: SharedPrefsCacheStorage(),
    shareFiles: createTemporaryShareFiles(),
  );

  /// The files the share sheet gets, such as an object source too long to share as text, in the temporary directory.
  /// It keeps no state, so every instance works on the same files.
  TemporaryShareFiles createTemporaryShareFiles() => TemporaryShareFiles();

  /// The OpenID Connect client, which talks to the identity provider. With `OIDC_CERT_PINS` set, discovery, the key
  /// set, the token exchange and the refresh go through a client pinned to them; the sign-in page itself opens in the
  /// system browser, which the app cannot pin.
  IOidcClient createOidcClient(OidcSettings settings) {
    final pins = appConfig.oidcCertificatePins;
    return OidcClient(settings: settings, httpClient: pins.isEmpty ? null : pinnedHttpClient(pins));
  }

  /// The single sign-on, which removes the files a share left and then stores the session through [sessionRepository].
  ISsoAuthRepository createSsoAuthRepository(IOidcClient client, IAuthSessionRepository sessionRepository) =>
      SsoAuthRepository(client: client, sessionRepository: sessionRepository, shareFiles: createTemporaryShareFiles());

  /// The token refresh, through [client] at the provider's token endpoint.
  TokenRotation createOidcTokenRotation(IOidcClient client, ISecureStorage secureStorage) =>
      OidcTokenRotation(client: client, secureStorage: secureStorage);

  /// Studio's connection API, which fills [queryTimeouts] from every list it reads.
  IConnectionRepository createConnectionRepository(ApiClient apiClient, ConnectionQueryTimeouts queryTimeouts) =>
      ConnectionRepository(apiClient, queryTimeouts);

  /// The sections of the connection list the user collapsed on this device.
  ICollapsedSectionsRepository createCollapsedSectionsRepository() => CollapsedSectionsRepository();

  /// The connections each signed-in subject starred and opened on this device.
  IFavoriteConnectionsRepository createFavoriteConnectionsRepository() => FavoriteConnectionsRepository();

  /// The connection each signed-in user had open last on this device.
  IActiveConnectionStore createActiveConnectionStore() => ActiveConnectionPreferences();

  /// The database each signed-in user ran statements in last on each server-level connection on this device.
  IActiveCatalogStore createActiveCatalogStore() => ActiveCatalogPreferences();

  /// Whether results show cards or a table on this device.
  IResultViewModeStore createResultViewModeStore() => ResultViewModePreferences();

  /// Studio's session endpoint: who the signed-in user is.
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) => StudioIdentityRepository(apiClient);

  /// Platform's identity endpoint: who the signed-in admin is.
  IPlatformIdentityRepository createPlatformIdentityRepository(PlatformApiClient apiClient) =>
      PlatformIdentityRepository(apiClient);

  /// Platform's connection list: every connection of the install, read only.
  IPlatformConnectionRepository createPlatformConnectionRepository(PlatformApiClient client) =>
      PlatformConnectionRepository(client);

  /// Platform's grants of a connection: list and revoke.
  IPlatformGrantRepository createPlatformGrantRepository(PlatformApiClient apiClient) =>
      PlatformGrantRepository(apiClient);

  /// Platform's directory of Keycloak users, the people a grant can name.
  IPlatformDirectoryRepository createPlatformDirectoryRepository(PlatformApiClient apiClient) =>
      PlatformDirectoryRepository(apiClient);

  /// Platform's audit log, the governed query events of the install.
  IPlatformAuditRepository createPlatformAuditRepository(PlatformApiClient apiClient) =>
      PlatformAuditRepository(apiClient);

  /// Platform's public liveness probe, which the login page and a Platform session ask.
  IPlatformStatusRepository createPlatformStatusRepository(PlatformApiClient apiClient) =>
      PlatformStatusRepository(apiClient);

  /// The in-place switch of the live session between Studio and Platform, which asks the gate of the target switched
  /// to; [platformIdentity] is null in a build without a Platform target.
  SwitchSessionTargetUseCase createSwitchSessionTargetUseCase(
    IStudioIdentityRepository studioIdentity,
    IPlatformIdentityRepository? platformIdentity,
    IAuthSessionRepository sessionRepository,
  ) => SwitchSessionTargetUseCase(studioIdentity, platformIdentity, sessionRepository);

  /// What the engine of a connection can do, which several features read, kept in memory for the session.
  CachedProviderMetaRepository createProviderMetaRepository(ApiClient apiClient) =>
      CachedProviderMetaRepository(ProviderMetaRepository(apiClient));

  /// Studio's read-only object routes, with their answers kept in memory for ten minutes.
  CachedObjectBrowserRepository createObjectBrowserRepository(ApiClient apiClient) =>
      CachedObjectBrowserRepository(ObjectBrowserRepository(apiClient));

  /// The one way a feature runs a statement and reads its result: `POST /api/db/query`, waiting the connection's
  /// query timeout from [queryTimeouts].
  IStatementRepository createStatementRepository(ApiClient apiClient, ConnectionQueryTimeouts queryTimeouts) =>
      StatementRepository(apiClient, queryTimeouts);

  /// Studio's statement routes, with a single statement run through [statements]; a transaction waits the
  /// connection's query timeout from [queryTimeouts].
  ISqlEditorRepository createSqlEditorRepository(
    ApiClient apiClient,
    IStatementRepository statements,
    ConnectionQueryTimeouts queryTimeouts,
  ) => SqlEditorRepository(apiClient, statements, queryTimeouts);

  /// The statement text each account keeps on the device, the editor drafts and the history, encrypted with a key per
  /// account in [secureStorage].
  IStatementTextStore createStatementTextStore(ISecureStorage secureStorage) =>
      StatementTextStore(EncryptedTextFileStore(secureStorage: secureStorage));

  /// Every store that keeps data of a signed-in account on this device, which the user's 'Remove my data' clears: the
  /// drafts and the history, the starred and recent connections, the last open connection, the database of each
  /// server-level connection, the collapsed sections of the connection list, whose keys are Studio's environment and
  /// group names, and the files the share sheet got, which every sign-out also removes. The language, the theme and
  /// the result view mode are device preferences and stay.
  ///
  /// Each store is the instance the app works with, so a clear joins the queue of the statement text store.
  UserDataRegistry createUserDataRegistry({
    required IStatementTextStore statementText,
    required IFavoriteConnectionsRepository favorites,
    required IActiveConnectionStore activeConnection,
    required IActiveCatalogStore activeCatalog,
    required ICollapsedSectionsRepository collapsedSections,
    required TemporaryShareFiles shareFiles,
  }) => UserDataRegistry([
    UserDataStore(
      name: 'statement_text',
      clear: (subject) async {
        if (await statementText.clearSubject(subjectHash(subject)) case Failure(:final error)) throw error;
      },
    ),
    UserDataStore(name: StorageKeys.connectionFavorites.key, clear: favorites.clear),
    UserDataStore(name: StorageKeys.activeConnection.key, clear: (subject) => activeConnection.write(subject, null)),
    UserDataStore(name: StorageKeys.activeCatalog.key, clear: activeCatalog.clear),
    UserDataStore(name: StorageKeys.connectionSectionsCollapsed.key, clear: (_) => collapsedSections.clear()),
    UserDataStore(name: 'share_files', clear: (_) => shareFiles.clear()),
  ]);

  /// The statement history each account keeps on the device, in the history of [store].
  IStatementHistoryRepository createStatementHistoryRepository(IStatementTextStore store) =>
      StatementHistoryRepository(store);

  /// The app's lifecycle, which the SQL editor's run follows.
  BindingAppLifecycleSource createAppLifecycleSource() => BindingAppLifecycleSource();

  /// The background time a statement run asks for: `beginBackgroundTask` on iOS, nothing on Android.
  IBackgroundRunTime createBackgroundRunTime() => BackgroundRunTime.forPlatform();

  /// Studio's liveness and readiness, which tell an unreachable Studio apart from a session failure.
  IStudioStatusRepository createStudioStatusRepository(ApiClient apiClient) => StudioStatusRepository(apiClient);

  /// The device preferences, such as the language the user picked.
  AppLocalStorage createLocalStorage() => AppLocalStorage();

  ISecureStorage createSecureStorage() => FlutterSecureStorageAdapter();
}
