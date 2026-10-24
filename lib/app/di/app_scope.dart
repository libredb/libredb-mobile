import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/features/object_browser/application/session_default_entry.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/localization/locale_cubit.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_with_sso_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sso_sign_out_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_sign_out_repository.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/auth/data/services/misconfigured_sso_session_startup.dart';
import 'package:libredb_mobile/features/auth/data/services/sso_session_startup_impl.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_store.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_store.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';

class AppScope extends StatelessWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    this.secureStorage,
    required this.defaultLocale,
    required this.child,
  });

  final AppDependencies dependencies;

  /// Pre-constructed ISecureStorage from bootstrap. When provided, it is
  /// shared via `.value` so bootstrap and runtime consumers use the same
  /// instance. When null, AppScope falls back to `dependencies.createSecureStorage()`
  /// (useful for tests that don't go through bootstrap).
  final ISecureStorage? secureStorage;

  /// The language [LocaleCubit] shows when no language is stored on the device.
  final Locale defaultLocale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final secure = secureStorage;
    final oidcSettings = switch (dependencies.authMode) {
      OidcAuthMode(:final settings) => settings,
      OidcMisconfiguredAuthMode() => null,
    };
    return MultiRepositoryProvider(
      providers: [
        if (secure != null)
          RepositoryProvider<ISecureStorage>.value(value: secure)
        else
          RepositoryProvider<ISecureStorage>(create: (_) => dependencies.createSecureStorage()),
        RepositoryProvider<AppConfig>.value(value: dependencies.appConfig),
        RepositoryProvider<ProjectLinks>.value(value: dependencies.projectLinks),
        RepositoryProvider<AuthMode>.value(value: dependencies.authMode),
        // Provided above SessionCubit and IAuthRepository, which clear the stored session when they end one.
        RepositoryProvider<IAuthSessionRepository>(
          create: (context) => dependencies.createAuthSessionRepository(context.read<ISecureStorage>()),
        ),
        // Only a correctly configured build can reach the provider. These come before SessionCubit, which refreshes the
        // session at startup, and the one TokenRotation is shared with the ApiClient.
        if (oidcSettings != null) ...[
          RepositoryProvider<IOidcClient>(create: (_) => dependencies.createOidcClient(oidcSettings)),
          RepositoryProvider<ISsoAuthRepository>(
            create: (context) => dependencies.createSsoAuthRepository(
              context.read<IOidcClient>(),
              context.read<IAuthSessionRepository>(),
            ),
          ),
          RepositoryProvider<TokenRotation>(
            create: (context) =>
                dependencies.createOidcTokenRotation(context.read<IOidcClient>(), context.read<ISecureStorage>()),
          ),
          RepositoryProvider<SsoAutoRedirectGate>(create: (_) => SsoAutoRedirectGate()),
        ],
        // Provided above ApiClient so a failed token refresh can end the session.
        BlocProvider<SessionCubit>(
          create: (context) {
            final session = SessionCubit(
              secureStorage: context.read<ISecureStorage>(),
              sessionRepository: context.read<IAuthSessionRepository>(),
              ssoStartup: switch (dependencies.authMode) {
                OidcAuthMode() => SsoSessionStartup(
                  rotation: context.read<TokenRotation>(),
                  secureStorage: context.read<ISecureStorage>(),
                  sessionRepository: context.read<IAuthSessionRepository>(),
                  gate: context.read<SsoAutoRedirectGate>(),
                ),
                // Fails closed: a session that an earlier build stored is never restored.
                OidcMisconfiguredAuthMode() => const MisconfiguredSsoSessionStartup(),
              },
            );
            return session..restore();
          },
        ),
        // Provided above ApiClient, which tells it when Studio refuses the signed-in account.
        BlocProvider<StudioAccountRefusalCubit>(create: (_) => StudioAccountRefusalCubit()),
        RepositoryProvider<ApiClient>(
          create: (context) {
            final session = context.read<SessionCubit>();
            final refusal = context.read<StudioAccountRefusalCubit>();
            void onSessionExpired() => session.endSession(reason: SessionExpiredReason.expired);
            // A refusal during the sign-in is the login page's to tell, so only a signed-in account is refused here.
            void onAccountRefused(AppErrorCode code) {
              if (session.state is SessionAuthenticated) refusal.refuse(code);
            }

            return dependencies.createApiClient(
              context.read<ISecureStorage>(),
              onSessionExpired: onSessionExpired,
              onAccountRefused: onAccountRefused,
              tokenRotation: switch (dependencies.authMode) {
                OidcAuthMode() => context.read<TokenRotation>(),
                // A misconfigured build cannot reach the provider, so a stored session is never refreshed.
                OidcMisconfiguredAuthMode() => const RefusingTokenRotation(),
              },
            );
          },
        ),
        // One set for the app: the managed list fills it, and the statement routes wait for what it holds.
        RepositoryProvider<ConnectionQueryTimeouts>(create: (_) => ConnectionQueryTimeouts()),
        RepositoryProvider<IConnectionRepository>(
          create: (context) => dependencies.createConnectionRepository(
            context.read<ApiClient>(),
            context.read<ConnectionQueryTimeouts>(),
          ),
        ),
        RepositoryProvider<ICollapsedSectionsRepository>(
          create: (_) => dependencies.createCollapsedSectionsRepository(),
        ),
        RepositoryProvider<IFavoriteConnectionsRepository>(
          create: (_) => dependencies.createFavoriteConnectionsRepository(),
        ),
        RepositoryProvider<IStudioIdentityRepository>(
          create: (context) => dependencies.createStudioIdentityRepository(context.read<ApiClient>()),
        ),
        // The caches are provided by their own type too, so the app clears them when the session ends and the
        // features read them through their interfaces.
        RepositoryProvider<CachedProviderMetaRepository>(
          create: (context) => dependencies.createProviderMetaRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider<IProviderMetaRepository>(create: (context) => context.read<CachedProviderMetaRepository>()),
        RepositoryProvider<CachedObjectBrowserRepository>(
          create: (context) => dependencies.createObjectBrowserRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider<IObjectBrowserRepository>(
          create: (context) => context.read<CachedObjectBrowserRepository>(),
        ),
        // The same instance, so the SQL editor's list of a server's databases shares Browse's kept answer.
        RepositoryProvider<IContainersRepository>(create: (context) => context.read<CachedObjectBrowserRepository>()),
        RepositoryProvider<SchemaChangeNotifier>(
          create: (context) => SchemaChangeNotifier(
            providerMeta: context.read<IProviderMetaRepository>(),
            invalidateConnection: context.read<CachedObjectBrowserRepository>().invalidate,
          ),
          dispose: (notifier) => notifier.dispose(),
        ),
        RepositoryProvider<BindingAppLifecycleSource>(
          create: (_) => dependencies.createAppLifecycleSource(),
          dispose: (source) => source.dispose(),
        ),
        RepositoryProvider<IAppLifecycleSource>(create: (context) => context.read<BindingAppLifecycleSource>()),
        RepositoryProvider<IBackgroundRunTime>(create: (_) => dependencies.createBackgroundRunTime()),
        RepositoryProvider<IStatementRepository>(
          create: (context) => dependencies.createStatementRepository(
            context.read<ApiClient>(),
            context.read<ConnectionQueryTimeouts>(),
          ),
        ),
        RepositoryProvider<ISqlEditorRepository>(
          create: (context) => dependencies.createSqlEditorRepository(
            context.read<ApiClient>(),
            context.read<IStatementRepository>(),
            context.read<ConnectionQueryTimeouts>(),
          ),
        ),
        // One store for the app, so a draft save and a history append share its queue.
        RepositoryProvider<IStatementTextStore>(
          create: (context) => dependencies.createStatementTextStore(context.read<ISecureStorage>()),
        ),
        RepositoryProvider<IStatementHistoryRepository>(
          create: (context) => dependencies.createStatementHistoryRepository(context.read<IStatementTextStore>()),
        ),
        // One instance each, shared by the cubits below and the registry, so 'Remove my data' clears what they store.
        RepositoryProvider<IActiveConnectionStore>(create: (_) => dependencies.createActiveConnectionStore()),
        RepositoryProvider<IActiveCatalogStore>(create: (_) => dependencies.createActiveCatalogStore()),
        RepositoryProvider<UserDataRegistry>(
          create: (context) => dependencies.createUserDataRegistry(
            statementText: context.read<IStatementTextStore>(),
            favorites: context.read<IFavoriteConnectionsRepository>(),
            activeConnection: context.read<IActiveConnectionStore>(),
            activeCatalog: context.read<IActiveCatalogStore>(),
            collapsedSections: context.read<ICollapsedSectionsRepository>(),
          ),
        ),
        if (oidcSettings == null)
          RepositoryProvider<IAuthRepository>(
            create: (context) => dependencies.createAuthRepository(context.read<IAuthSessionRepository>()),
          )
        else ...[
          // A logout the user starts also ends the session at the identity provider.
          RepositoryProvider<SsoSignOutAuthRepository>(
            create: (context) => SsoSignOutAuthRepository(
              inner: dependencies.createAuthRepository(context.read<IAuthSessionRepository>()),
              client: context.read<IOidcClient>(),
              secureStorage: context.read<ISecureStorage>(),
              settings: oidcSettings,
              studioIdentity: context.read<IStudioIdentityRepository>(),
              sessionRefresh: SsoSessionStartup(
                rotation: context.read<TokenRotation>(),
                secureStorage: context.read<ISecureStorage>(),
                sessionRepository: context.read<IAuthSessionRepository>(),
                gate: context.read<SsoAutoRedirectGate>(),
              ),
            ),
          ),
          RepositoryProvider<IAuthRepository>(create: (context) => context.read<SsoSignOutAuthRepository>()),
          RepositoryProvider<ISsoSignOutRepository>(create: (context) => context.read<SsoSignOutAuthRepository>()),
        ],
        RepositoryProvider<IStudioStatusRepository>(
          create: (context) => dependencies.createStudioStatusRepository(context.read<ApiClient>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityCubit>(create: (_) => ConnectivityCubit()..monitor()),
          BlocProvider<LoginBloc>(
            // A misconfigured build has no sign-in: its login page shows why and offers none. A sign-in succeeds only
            // once Studio's GET /api/auth/me accepts the account.
            create: (context) => LoginBloc(
              signInWithSsoUseCase: oidcSettings == null
                  ? null
                  : SignInWithSsoUseCase(
                      context.read<ISsoAuthRepository>(),
                      context.read<IStudioIdentityRepository>(),
                      context.read<IAuthSessionRepository>(),
                    ),
            ),
          ),
          BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()..add(const LoadTheme())),
          // Created, and the first liveness check sent, when App's StudioStatusGate first builds, which is before the
          // stored session is restored.
          BlocProvider<StudioStatusBloc>(
            create: (context) => StudioStatusBloc(
              checkLivenessUseCase: CheckStudioLivenessUseCase(context.read<IStudioStatusRepository>()),
              readReadinessUseCase: ReadStudioReadinessUseCase(context.read<IStudioStatusRepository>()),
            )..add(const StudioLivenessCheckRequested()),
          ),
          BlocProvider<LocaleCubit>(
            create: (_) =>
                LocaleCubit(storage: dependencies.createLocalStorage(), defaultLocale: defaultLocale)..restore(),
          ),
          // Above the router, so the shell, every feature and a route guard read the same answer; the shell loads them
          // when it opens and AppSessionListeners clears them at the session's end.
          BlocProvider<StudioIdentityCubit>(
            create: (context) => StudioIdentityCubit(repository: context.read<IStudioIdentityRepository>()),
          ),
          BlocProvider<ConnectionPolicyCubit>(
            create: (context) => ConnectionPolicyCubit(repository: context.read<IConnectionRepository>()),
          ),
          // Above the router, so the connection list and the app-bar switcher show the same stars; AppSessionListeners
          // tells it whose they are from StudioIdentityCubit.
          BlocProvider<FavoriteConnectionsBloc>(
            create: (context) => FavoriteConnectionsBloc(repository: context.read<IFavoriteConnectionsRepository>()),
          ),
          // Above the router, so the shell, the connection list and every page that works on a connection share one;
          // AppSessionListeners tells it who signed in and closes it at the session's end.
          BlocProvider<ActiveConnectionCubit>(
            create: (context) => ActiveConnectionCubit(store: context.read<IActiveConnectionStore>()),
          ),
          // Beside the active connection, which it follows: Browse and the SQL editor share the database a
          // server-level connection runs statements in; AppSessionListeners tells it who signed in and clears it at the
          // session's end.
          BlocProvider<ActiveCatalogCubit>(
            create: (context) => ActiveCatalogCubit(
              store: context.read<IActiveCatalogStore>(),
              connectionIds: context.read<ActiveConnectionCubit>().connectionIds,
            ),
          ),
          // Above the router, so every result view shows the same mode; a device setting, which no session end clears.
          BlocProvider<ResultViewModeCubit>(
            create: (_) => ResultViewModeCubit(store: dependencies.createResultViewModeStore())..restore(),
          ),
          // Follows the active connection, so the Browse tab opens a session-default container on its first entry only.
          RepositoryProvider<SessionDefaultEntry>(
            create: (context) => SessionDefaultEntry(context.read<ActiveConnectionCubit>().connectionIds),
            dispose: (entry) => entry.dispose(),
          ),
          BlocProvider<SignOutBloc>(
            create: (context) => SignOutBloc(
              logoutUseCase: LogoutUseCase(context.read<IAuthRepository>()),
              ssoSignOutUseCase: oidcSettings == null ? null : SsoSignOutUseCase(context.read<ISsoSignOutRepository>()),
            ),
          ),
        ],
        child: child,
      ),
    );
  }
}
