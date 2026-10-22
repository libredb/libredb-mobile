import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Service imports
import 'package:libredb_mobile/core/analytics/analytics_service.dart';

// Infrastructure imports
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

// BLoC imports
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/usecases/sign_in_with_sso_usecase.dart';

// Repository imports (interfaces)
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
// Entity/model imports for fallback values
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';

// Interface repository mocks (for use case tests)
class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockIAuthSessionRepository extends Mock implements IAuthSessionRepository {}

class MockIConnectionRepository extends Mock implements IConnectionRepository {}

class MockILifecycleRepository extends Mock implements ILifecycleRepository {}

class MockIStudioStatusRepository extends Mock implements IStudioStatusRepository {}

// Use case mocks (for BLoC tests)
class MockSignInWithSsoUseCase extends Mock implements SignInWithSsoUseCase {}

// BLoC mocks (using MockBloc from bloc_test)
class MockLoginBloc extends MockBloc<LoginEvent, LoginState> implements LoginBloc {}

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
}
