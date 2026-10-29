import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/app_lock/data/services/android_biometric_hardware.dart';
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

  group('availableBiometric', () {
    Future<DeviceBiometric> askWith(List<BiometricType> types) {
      when(() => auth.getAvailableBiometrics()).thenAnswer((_) async => types);
      return authenticator.availableBiometric();
    }

    test('names a single kind', () async {
      expect(await askWith([BiometricType.face]), DeviceBiometric.face);
      expect(await askWith([BiometricType.fingerprint]), DeviceBiometric.fingerprint);
      expect(await askWith([BiometricType.iris]), DeviceBiometric.iris);
    });

    test('says several for two kinds, and for the unspecific strong or weak classes', () async {
      expect(await askWith([BiometricType.face, BiometricType.fingerprint]), DeviceBiometric.several);
      expect(await askWith([BiometricType.strong]), DeviceBiometric.several);
      expect(await askWith([BiometricType.weak, BiometricType.strong]), DeviceBiometric.several);
    });

    test('a named kind wins over the strong class that the platform repeats beside it', () async {
      expect(await askWith([BiometricType.face, BiometricType.strong]), DeviceBiometric.face);
    });

    test('says none when nothing is enrolled', () async {
      expect(await askWith([]), DeviceBiometric.none);
    });

    group('on Android, which reports only the strong and weak classes', () {
      Future<DeviceBiometric> askWithHardware(List<BiometricType> types, Set<String>? hardware) {
        when(() => auth.getAvailableBiometrics()).thenAnswer((_) async => types);
        return LocalAuthDeviceAuthenticator(auth: auth, hardwareKinds: () async => hardware).availableBiometric();
      }

      test('names the one kind the hardware has when something is enrolled', () async {
        expect(await askWithHardware([BiometricType.strong], {'fingerprint'}), DeviceBiometric.fingerprint);
        expect(await askWithHardware([BiometricType.weak], {'face'}), DeviceBiometric.face);
        expect(await askWithHardware([BiometricType.strong, BiometricType.weak], {'iris'}), DeviceBiometric.iris);
      });

      test('stays neutral when the hardware has several kinds, as it cannot tell which is enrolled', () async {
        expect(await askWithHardware([BiometricType.strong], {'fingerprint', 'face'}), DeviceBiometric.several);
      });

      test('stays neutral when the hardware check has no answer or names no kind', () async {
        expect(await askWithHardware([BiometricType.strong], null), DeviceBiometric.several);
        expect(await askWithHardware([BiometricType.strong], {}), DeviceBiometric.several);
        expect(await askWithHardware([BiometricType.strong], {'unknown'}), DeviceBiometric.several);
      });

      test('claims nothing when nothing is enrolled, whatever the hardware', () async {
        expect(await askWithHardware([], {'fingerprint'}), DeviceBiometric.none);
      });

      test('stays neutral when the hardware check throws', () async {
        when(() => auth.getAvailableBiometrics()).thenAnswer((_) async => [BiometricType.strong]);
        final throwing = LocalAuthDeviceAuthenticator(
          auth: auth,
          hardwareKinds: () => throw PlatformException(code: 'x'),
        );
        expect(await throwing.availableBiometric(), DeviceBiometric.several);
      });
    });

    test('the default hardware check asks the Android channel and is skipped off Android', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidBiometricHardware.channel,
        (call) async {
          calls.add(call.method);
          return ['fingerprint'];
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          AndroidBiometricHardware.channel,
          null,
        ),
      );
      when(() => auth.getAvailableBiometrics()).thenAnswer((_) async => [BiometricType.strong]);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await LocalAuthDeviceAuthenticator(auth: auth).availableBiometric(), DeviceBiometric.fingerprint);
      expect(calls, ['kinds']);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await LocalAuthDeviceAuthenticator(auth: auth).availableBiometric(), DeviceBiometric.several);
      expect(calls, ['kinds']);
      debugDefaultTargetPlatformOverride = null;
    });
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
