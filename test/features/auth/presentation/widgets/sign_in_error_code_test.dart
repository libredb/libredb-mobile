import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/sign_in_error_line.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Which error the sign-in surface shows.
///
/// Two places have to agree about this: the line the user reads, and the auto-redirect gate, which must not send
/// the user to the provider while an error is on screen — a redirect over an error is the loop that gate exists to
/// prevent. The answer used to be a method on the page's `State`, reachable only by pumping the whole screen with a
/// router and a bloc; as a function it is checked here directly (#379).
void main() {
  final working = OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app'));
  const misconfigured = OidcMisconfiguredAuthMode('OIDC_ISSUER is empty');

  AppErrorCode? codeFor({
    required AuthMode mode,
    required LoginState state,
    AppErrorCode? startupError,
    bool tapped = false,
  }) => signInErrorCode(mode: mode, state: state, startupError: startupError, tapped: tapped);

  test('a failed sign-in shows its own error, whatever the build', () {
    expect(
      codeFor(
        mode: working,
        state: const LoginErrorState(errorCode: AppErrorCode.authOidcDiscovery),
      ),
      AppErrorCode.authOidcDiscovery,
    );
    expect(
      codeFor(
        mode: misconfigured,
        state: const LoginErrorState(errorCode: AppErrorCode.authOidcDiscovery),
      ),
      AppErrorCode.authOidcDiscovery,
      reason: 'the error of the attempt the user just made outranks the build it was made on',
    );
  });

  test('a sign-in in flight shows no error', () {
    expect(
      codeFor(
        mode: working,
        state: const LoginLoadingState(target: SessionTarget.studio),
      ),
      isNull,
    );
    expect(
      codeFor(
        mode: misconfigured,
        state: const LoginLoadingState(target: SessionTarget.studio),
      ),
      isNull,
      reason: 'a spinner and an error at once says two things about one attempt',
    );
  });

  test('a misconfigured build says so before anything is tried', () {
    expect(codeFor(mode: misconfigured, state: const LoginInitialState()), AppErrorCode.authOidcConfig);
    expect(codeFor(mode: working, state: const LoginInitialState()), isNull);
  });

  group('an error the app arrived with', () {
    test('is shown until the user tries', () {
      expect(
        codeFor(mode: working, state: const LoginInitialState(), startupError: AppErrorCode.authInvalidAccessToken),
        AppErrorCode.authInvalidAccessToken,
      );
    });

    test('stops being theirs once they have', () {
      expect(
        codeFor(
          mode: working,
          state: const LoginInitialState(),
          startupError: AppErrorCode.authInvalidAccessToken,
          tapped: true,
        ),
        isNull,
        reason: 'it belongs to the build they arrived on, not to the attempt they just made',
      );
    });

    test('does not hide a misconfigured build once they have', () {
      expect(
        codeFor(
          mode: misconfigured,
          state: const LoginInitialState(),
          startupError: AppErrorCode.authInvalidAccessToken,
          tapped: true,
        ),
        AppErrorCode.authOidcConfig,
        reason: 'the build is still misconfigured however many times the user tries',
      );
    });
  });
}
