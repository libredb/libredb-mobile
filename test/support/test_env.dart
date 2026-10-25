import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Static test-support harness. Replaces the old instance-based `TestUtils`.
///
/// One-time global config and the per-test reset are wired in
/// `test/flutter_test_config.dart`. Individual test files normally need
/// nothing; files that manage the secure-storage MethodChannel themselves
/// opt out with `setUpAll(() => TestEnv.autoReset = false);`.
class TestEnv {
  TestEnv._();

  /// When false, the global setUp/tearDown in flutter_test_config skip
  /// [reset]. Set in a file's `setUpAll` for tests that install their own
  /// MethodChannel handler (per-file isolate, so it never leaks). Defaults
  /// to true at isolate start.
  static bool autoReset = true;

  /// In-memory backing for the mocked flutter_secure_storage channel.
  /// Production code instantiates [FlutterSecureStorageAdapter] in several
  /// places (AuthInterceptor, TokenRefreshInterceptor, SessionCubit,
  /// AuthSessionRepository); each
  /// routes through this MethodChannel. Without the mock those paths throw
  /// MissingPluginException.
  static final Map<String, String> _secureStore = {};

  static const _secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  static const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  /// The temporary directory path_provider answers, made on the first call of a test and removed by [reset]. Every
  /// sign-out clears the share files in it (`TemporaryShareFiles`), so a test that signs out needs one.
  static Directory? _temporaryDirectory;

  /// Mock-backed client for tests: test AppConfig → MockInterceptor serves
  /// assets/mock/*.json; shared secure adapter → same MethodChannel mock the
  /// repo layer reads; the token refresh of `main_local.dart`'s local sign-in.
  /// Pass [dio] to inject a stub.
  static ApiClient apiClient({Dio? dio}) {
    final dependencies = LocalSignInDependencies(appConfig: const AppConfig.test());
    final secureStorage = FlutterSecureStorageAdapter();
    final settings = (dependencies.authMode as OidcAuthMode).settings;
    return ApiClient(
      appConfig: dependencies.appConfig,
      secureStorage: secureStorage,
      dio: dio,
      tokenRotation: dependencies.createOidcTokenRotation(dependencies.createOidcClient(settings), secureStorage),
    );
  }

  /// The mock-backed LibreDB Platform client, built like [apiClient]: the test AppConfig's Platform target has no base
  /// URL, so MockInterceptor serves `assets/mock/*_v1_*.json`. Pass [dio] to inject a stub.
  static PlatformApiClient platformApiClient({Dio? dio}) {
    final dependencies = LocalSignInDependencies(appConfig: const AppConfig.test());
    final secureStorage = FlutterSecureStorageAdapter();
    final settings = (dependencies.authMode as OidcAuthMode).settings;
    return PlatformApiClient(
      appConfig: dependencies.appConfig,
      secureStorage: secureStorage,
      dio: dio,
      tokenRotation: dependencies.createOidcTokenRotation(dependencies.createOidcClient(settings), secureStorage),
    );
  }

  /// Resets the per-test environment: re-installs the secure-storage and
  /// temporary directory mocks and clears all storage.
  /// No language is stored, so an `App` starts in the language passed to it,
  /// as on a first launch. Idempotent and cheap (in-memory).
  static Future<void> reset() async {
    _installSecureStorageMock();
    _installTemporaryDirectoryMock();
    await _clearStorage();
  }

  /// Seeds a mock JWT and the session [target] (Studio unless given) in the
  /// secure-store backing, as a sign-in of this build stores them. Call inside
  /// a test body or `setUp` (i.e. AFTER the global reset has cleared the
  /// store), never in `setUpAll`. Synchronous: the backing is just an
  /// in-memory map.
  static void authenticate({SessionTarget target = SessionTarget.studio}) {
    _secureStore[SecureStorageKeys.sessionTarget.key] = target.storedValue;
    _secureStore[SecureStorageKeys.jwtToken.key] = 'MOCK_TOKEN';
  }

  /// Always re-installs the handler. `secure_storage_test.dart` temporarily
  /// overrides the same channel and resets the handler to null in its
  /// tearDown; re-installing here is cheap and idempotent.
  static void _installSecureStorageMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_secureChannel, (
      call,
    ) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return _secureStore[key];
        case 'readAll':
          return Map<String, String>.from(_secureStore);
        case 'write':
          _secureStore[key!] = args['value'] as String;
          return null;
        case 'delete':
          _secureStore.remove(key);
          return null;
        case 'deleteAll':
          _secureStore.clear();
          return null;
        case 'containsKey':
          return _secureStore.containsKey(key);
        default:
          return null;
      }
    });
  }

  /// Answers path_provider's temporary directory with [_temporaryDirectory]; any other directory stays unanswered, as
  /// without a mock. A test that needs another answer installs its own handler, which this replaces at the next reset.
  static void _installTemporaryDirectoryMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProviderChannel, (
      call,
    ) async {
      if (call.method != 'getTemporaryDirectory') throw MissingPluginException();
      return (_temporaryDirectory ??= Directory.systemTemp.createTempSync('libredb_test_temporary')).path;
    });
  }

  static Future<void> _clearStorage() async {
    final temporary = _temporaryDirectory;
    _temporaryDirectory = null;
    if (temporary != null && temporary.existsSync()) temporary.deleteSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    _secureStore.clear();
    await AppLocalStorage().clear();
  }
}
