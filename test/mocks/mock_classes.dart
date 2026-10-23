import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App imports
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';

// Service imports
import 'package:libredb_mobile/core/analytics/analytics_service.dart';

// Infrastructure imports
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

// BLoC imports
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_with_sso_usecase.dart';

// Repository imports (interfaces)
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
// Entity/model imports for fallback values
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_store.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';

// Interface repository mocks (for use case tests)
class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockIAuthSessionRepository extends Mock implements IAuthSessionRepository {}

class MockISsoAuthRepository extends Mock implements ISsoAuthRepository {}

class MockIStudioIdentityRepository extends Mock implements IStudioIdentityRepository {}

class MockIConnectionRepository extends Mock implements IConnectionRepository {}

class MockICollapsedSectionsRepository extends Mock implements ICollapsedSectionsRepository {}

class MockIFavoriteConnectionsRepository extends Mock implements IFavoriteConnectionsRepository {}

class MockILifecycleRepository extends Mock implements ILifecycleRepository {}

class MockIStudioStatusRepository extends Mock implements IStudioStatusRepository {}

class MockIProviderMetaRepository extends Mock implements IProviderMetaRepository {}

class MockIStatementRepository extends Mock implements IStatementRepository {}

class MockIObjectBrowserRepository extends Mock implements IObjectBrowserRepository {}

class MockIActiveConnectionStore extends Mock implements IActiveConnectionStore {}

class MockIResultViewModeStore extends Mock implements IResultViewModeStore {}

class MockIStatementTextStore extends Mock implements IStatementTextStore {}

// Use case mocks (for BLoC tests)
class MockSignInWithSsoUseCase extends Mock implements SignInWithSsoUseCase {}

// BLoC mocks (using MockBloc from bloc_test)
class MockLoginBloc extends MockBloc<LoginEvent, LoginState> implements LoginBloc {}

class MockStudioIdentityCubit extends MockCubit<StudioIdentityState> implements StudioIdentityCubit {}

class MockConnectionPolicyCubit extends MockCubit<ConnectionPolicyState> implements ConnectionPolicyCubit {}

class MockActiveConnectionCubit extends MockCubit<ActiveConnectionState> implements ActiveConnectionCubit {}

class MockConnectivityCubit extends MockCubit<ConnectivityState> implements ConnectivityCubit {}

class MockStudioStatusBloc extends MockBloc<StudioStatusEvent, StudioStatusState> implements StudioStatusBloc {}

// Service mocks
class MockAnalyticsService extends Mock implements IAnalyticsService {}

// Infrastructure mocks
class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockISecureStorage extends Mock implements ISecureStorage {}

class MockTokenRotation extends Mock implements TokenRotation {}

// Fake classes for fallback values
class FakeLoginEvent extends Fake implements LoginEvent {}

class FakeUri extends Fake implements Uri {}

/// Register all fallback values needed for mocktail's any() matcher.
/// Call this in setUpAll() for tests that use any() with non-nullable types.
void registerAllFallbackValues() {
  registerFallbackValue(FakeLoginEvent());
  registerFallbackValue(FakeUri());
  registerFallbackValue(<String>{});
  registerFallbackValue(ConnectionFavorites.empty);
  registerFallbackValue(QueryPage.first);
}
