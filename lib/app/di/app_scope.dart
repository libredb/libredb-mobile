import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/localization/locale_cubit.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
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
import 'package:libredb_mobile/features/lifecycle/application/lifecycle_bloc.dart';
import 'package:libredb_mobile/features/lifecycle/application/lifecycle_event.dart';
import 'package:libredb_mobile/features/lifecycle/application/usecases/fetch_app_config_usecase.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/core/feature_flags/feature_flag_service.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

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
              appConfig: context.read<AppConfig>(),
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
        RepositoryProvider<ApiClient>(
          create: (context) {
            final session = context.read<SessionCubit>();
            void onSessionExpired() => session.endSession(reason: SessionExpiredReason.expired);
            return dependencies.createApiClient(
              context.read<ISecureStorage>(),
              onSessionExpired: onSessionExpired,
              tokenRotation: switch (dependencies.authMode) {
                OidcAuthMode() => context.read<TokenRotation>(),
                // A misconfigured build cannot reach the provider, so a stored session is never refreshed.
                OidcMisconfiguredAuthMode() => const RefusingTokenRotation(),
              },
            );
          },
        ),
        RepositoryProvider<IConnectionRepository>(
          create: (context) => dependencies.createConnectionRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider<IStudioIdentityRepository>(
          create: (context) => dependencies.createStudioIdentityRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider<IProviderMetaRepository>(
          create: (context) => dependencies.createProviderMetaRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider<IObjectBrowserRepository>(
          create: (context) => dependencies.createObjectBrowserRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider<ISqlEditorRepository>(
          create: (context) => dependencies.createSqlEditorRepository(context.read<ApiClient>()),
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
        RepositoryProvider<ILifecycleRepository>(
          create: (context) => dependencies.createLifecycleRepository(context.read<ApiClient>()),
        ),
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
          // Created, and the first check sent, when App's LifecycleGate first builds.
          BlocProvider<LifecycleBloc>(
            create: (context) => LifecycleBloc(
              fetchAppConfigUseCase: FetchAppConfigUseCase(context.read<ILifecycleRepository>()),
              featureFlagService: FeatureFlagService.instance,
            )..add(const LifecycleCheckEvent()),
          ),
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
