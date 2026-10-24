import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/app_lock/data/services/local_auth_device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuthentication extends Mock implements LocalAuthentication {}

const _prompt = DeviceAuthPrompt(reason: 'Unlock LibreDB', title: 'LibreDB is locked', cancel: 'Cancel');

void main() {
  late _MockLocalAuthentication auth;
  late LocalAuthDeviceAuthenticator authenticator;

  setUp(() {
    auth = _MockLocalAuthentication();
    authenticator = LocalAuthDeviceAuthenticator(auth: auth);
  });

  void answer(Future<bool> Function() result) {
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        authMessages: any(named: 'authMessages'),
        biometricOnly: any(named: 'biometricOnly'),
        sensitiveTransaction: any(named: 'sensitiveTransaction'),
        persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
      ),
    ).thenAnswer((_) => result());
  }

  test('can authenticate when the device answers that it is supported, which needs a screen lock', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    expect(await authenticator.canAuthenticate(), isTrue);

    when(() => auth.isDeviceSupported()).thenAnswer((_) async => false);
    expect(await authenticator.canAuthenticate(), isFalse);
  });

  test('opens the prompt with biometrics and the screen lock as the fallback, in the given texts', () async {
    answer(() async => true);

    expect(await authenticator.authenticate(_prompt), isA<DeviceAuthSucceeded>());

    final call = verify(
      () => auth.authenticate(
        localizedReason: 'Unlock LibreDB',
        authMessages: captureAny(named: 'authMessages'),
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      ),
    )..called(1);
    final messages = (call.captured.single as Iterable<Object?>).toList();
    final android = messages.whereType<AndroidAuthMessages>().single;
    expect(android.signInTitle, 'LibreDB is locked');
    expect(android.cancelButton, 'Cancel');
    expect(messages.whereType<IOSAuthMessages>().single.cancelButton, 'Cancel');
  });

  test('a prompt that answers false failed', () async {
    answer(() async => false);

    expect(await authenticator.authenticate(_prompt), isA<DeviceAuthFailed>());
  });

  for (final code in [
    LocalAuthExceptionCode.userCanceled,
    LocalAuthExceptionCode.systemCanceled,
    LocalAuthExceptionCode.timeout,
    LocalAuthExceptionCode.userRequestedFallback,
  ]) {
    test('${code.name} is a cancel', () async {
      answer(() => throw LocalAuthException(code: code));

      expect(await authenticator.authenticate(_prompt), isA<DeviceAuthCancelled>());
    });
  }

  test('no credentials set means the device has no screen lock', () async {
    answer(() => throw const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet));

    expect(await authenticator.authenticate(_prompt), isA<DeviceAuthNoScreenLock>());
  });

  for (final code in [LocalAuthExceptionCode.temporaryLockout, LocalAuthExceptionCode.biometricLockout]) {
    test('${code.name} is a failure after too many attempts', () async {
      answer(() => throw LocalAuthException(code: code));

      expect(
        await authenticator.authenticate(_prompt),
        isA<DeviceAuthFailed>().having((failed) => failed.lockedOut, 'lockedOut', isTrue),
      );
    });
  }

  for (final code in [
    LocalAuthExceptionCode.uiUnavailable,
    LocalAuthExceptionCode.deviceError,
    LocalAuthExceptionCode.unknownError,
    LocalAuthExceptionCode.authInProgress,
  ]) {
    test('${code.name} is a failure', () async {
      answer(() => throw LocalAuthException(code: code, description: 'detail'));

      expect(
        await authenticator.authenticate(_prompt),
        isA<DeviceAuthFailed>().having((failed) => failed.lockedOut, 'lockedOut', isFalse),
      );
    });
  }
}
