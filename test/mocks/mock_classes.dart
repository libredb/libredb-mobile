import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Service imports
import 'package:libredb_mobile/core/analytics/analytics_service.dart';

// Infrastructure imports
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

// BLoC imports
import 'package:libredb_mobile/features/auth/application/change_password_bloc.dart';
import 'package:libredb_mobile/features/auth/application/forgot_password_bloc.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/register_bloc.dart';

// Repository imports (concrete)
import 'package:libredb_mobile/features/account/data/repositories/account_repository.dart';

// Repository imports (interfaces)
import 'package:libredb_mobile/features/account/domain/repositories/account_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/repositories/lifecycle_repository.dart';
// Entity/model imports for fallback values
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';
import 'package:libredb_mobile/features/account/data/models/change_password.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';

// Concrete repository mocks (for BLoC tests that depend on concrete types)
class MockAccountRepository extends Mock implements AccountRepository {}

// Interface repository mocks (for use case tests)
class MockIAccountRepository extends Mock implements IAccountRepository {}

class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockIAuthSessionRepository extends Mock implements IAuthSessionRepository {}

class MockIConnectionRepository extends Mock implements IConnectionRepository {}

class MockILifecycleRepository extends Mock implements ILifecycleRepository {}

// BLoC mocks (using MockBloc from bloc_test)
class MockChangePasswordBloc extends MockBloc<ChangePasswordEvent, ChangePasswordState> implements ChangePasswordBloc {}

class MockForgotPasswordBloc extends MockBloc<ForgotPasswordEvent, ForgotPasswordState> implements ForgotPasswordBloc {}

class MockRegisterBloc extends MockBloc<RegisterEvent, RegisterState> implements RegisterBloc {}

class MockLoginBloc extends MockBloc<LoginEvent, LoginState> implements LoginBloc {}

// Service mocks
class MockAnalyticsService extends Mock implements IAnalyticsService {}

// Infrastructure mocks
class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockISecureStorage extends Mock implements ISecureStorage {}

class MockTokenRotation extends Mock implements TokenRotation {}

// Fake classes for fallback values
class FakeUserEntity extends Fake implements UserEntity {}

class FakePasswordChangeDTO extends Fake implements PasswordChangeDTO {}

class FakeAuthCredentialsEntity extends Fake implements AuthCredentialsEntity {}

class FakeSendOtpEntity extends Fake implements SendOtpEntity {}

class FakeVerifyOtpEntity extends Fake implements VerifyOtpEntity {}

class FakeForgotPasswordEvent extends Fake implements ForgotPasswordEvent {}

class FakeChangePasswordEvent extends Fake implements ChangePasswordEvent {}

class FakeRegisterEvent extends Fake implements RegisterEvent {}

class FakeLoginEvent extends Fake implements LoginEvent {}

class FakeUri extends Fake implements Uri {}

/// Register all fallback values needed for mocktail's any() matcher.
/// Call this in setUpAll() for tests that use any() with non-nullable types.
void registerAllFallbackValues() {
  registerFallbackValue(FakeForgotPasswordEvent());
  registerFallbackValue(FakeChangePasswordEvent());
  registerFallbackValue(FakeRegisterEvent());
  registerFallbackValue(FakeLoginEvent());
  registerFallbackValue(FakeUri());
  registerFallbackValue(FakeUserEntity());
  registerFallbackValue(FakePasswordChangeDTO());
  registerFallbackValue(FakeAuthCredentialsEntity());
  registerFallbackValue(FakeSendOtpEntity());
  registerFallbackValue(FakeVerifyOtpEntity());
}
