import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/dev_console/time_travel/time_travel_bloc_observer.dart';
import 'package:libredb_mobile/app/dev_console/time_travel/time_travel_store.dart';
import 'package:libredb_mobile/features/account/application/usecases/change_password_usecase.dart';
import 'package:libredb_mobile/features/account/application/usecases/get_account_usecase.dart';
import 'package:libredb_mobile/features/account/data/repositories/account_repository.dart';
import 'package:libredb_mobile/features/auth/application/change_password_bloc.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/usecases/authenticate_user_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/clear_auth_session_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/persist_auth_session_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/send_otp_usecase.dart';
import 'package:libredb_mobile/features/auth/application/usecases/verify_otp_usecase.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/infrastructure/http/dev_console_store.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_env.dart';

void main() {
  late BlocObserver previousObserver;

  setUp(() {
    previousObserver = Bloc.observer;
    Bloc.observer = TimeTravelBlocObserver();
    DevConsoleStore.instance.clearAll();
    TimeTravelStore.instance.clear();
  });

  tearDown(() {
    Bloc.observer = previousObserver;
    DevConsoleStore.instance.clearAll();
    TimeTravelStore.instance.clear();
  });

  // Regression: AppBootstrap installs this observer in every debug build, and it records the text of each event and
  // state. The events of the sign-in, OTP and change password forms printed the password, the code and both passwords,
  // so the BLoC and Time Travel tabs of the dev console showed them, and their Copy and Export buttons put them on the
  // clipboard.
  test('records the sign-in, OTP and change password flows without their secrets', () async {
    const secrets = ['S3cret!pw', '493817', 'OldPass#1', 'NewPass#2'];
    final api = TestEnv.apiClient();
    final secureStorage = FlutterSecureStorageAdapter();
    final loginRepository = LoginRepository(apiClient: api, secureStorage: secureStorage);
    final sessionRepository = AuthSessionRepository(secureStorage: secureStorage);
    final login = LoginBloc(
      authenticateUserUseCase: AuthenticateUserUseCase(loginRepository),
      sendOtpUseCase: SendOtpUseCase(loginRepository),
      verifyOtpUseCase: VerifyOtpUseCase(loginRepository),
      getAccountUseCase: GetAccountUseCase(AccountRepository(api)),
      persistAuthSessionUseCase: PersistAuthSessionUseCase(sessionRepository),
      clearAuthSessionUseCase: ClearAuthSessionUseCase(sessionRepository),
    );
    final changePassword = ChangePasswordBloc(changePasswordUseCase: ChangePasswordUseCase(AccountRepository(api)));

    login.add(const LoginFormSubmitted(username: 'admin', password: 'S3cret!pw'));
    await login.stream.firstWhere((s) => s is LoginLoadedState || s is LoginErrorState);
    login.add(const VerifyOtpSubmitted(email: 'otp.user@example.com', otpCode: '493817'));
    await login.stream.firstWhere((s) => s is LoginLoadedState || s is LoginErrorState);
    changePassword.add(const ChangePasswordChanged(currentPassword: 'OldPass#1', newPassword: 'NewPass#2'));
    await changePassword.stream.firstWhere((s) => s is ChangePasswordSuccessState || s is ChangePasswordFailureState);
    await Future.wait([login.close(), changePassword.close()]);

    final entries = DevConsoleStore.instance.blocEntries;
    final recorded = [
      for (final entry in entries) '${entry.event} | ${entry.currentState} | ${entry.nextState}',
      TimeTravelStore.instance.exportAsJson(),
    ];
    expect(recorded, everyElement(allOf([for (final secret in secrets) isNot(contains(secret))])));
    // The tabs still name each event, so the flow can be followed.
    final events = entries.map((entry) => entry.event);
    for (final event in ['LoginFormSubmitted', 'VerifyOtpSubmitted', 'ChangePasswordChanged']) {
      expect(events, anyElement(startsWith(event)));
    }
  });
}
