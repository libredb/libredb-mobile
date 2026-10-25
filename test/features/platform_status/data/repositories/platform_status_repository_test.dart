import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_status/data/models/platform_status_json.dart';
import 'package:libredb_mobile/features/platform_status/data/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/infrastructure/cache/shared_prefs_cache_storage.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

import '../../../../support/test_env.dart';

void main() {
  group('through the mock', () {
    // The probe is public: the login page asks it before anyone has signed in.
    test('liveness succeeds without a stored token', () async {
      expect(await PlatformStatusRepository(TestEnv.platformApiClient()).liveness(), isA<Success<void>>());
    });
  });

  group('over the production chain', () {
    late _QueuedAdapter adapter;
    late PlatformStatusRepository repository;

    setUp(() {
      ResilienceInterceptor.instance.resetAll();
      // A signed-in Platform session: the probe still carries no token.
      TestEnv.authenticate();
      adapter = _QueuedAdapter();
      final client = PlatformApiClient(
        appConfig: _prodWith(const PlatformConfigured(baseUrl: 'https://platform.example.test/api')),
        secureStorage: FlutterSecureStorageAdapter(),
        tokenRotation: const RefusingTokenRotation(),
      );
      client.instance.httpClientAdapter = adapter;
      repository = PlatformStatusRepository(client);
    });

    tearDown(() => ResilienceInterceptor.instance.resetAll());

    test('liveness asks GET /api/health/live without a token and with the probe timeout', () async {
      adapter.replies.add((200, '{"status":"live"}'));

      expect(await repository.liveness(), isA<Success<void>>());
      final sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.uri.toString(), 'https://platform.example.test/api/health/live');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.connectTimeout, PlatformStatusRepository.probeTimeout);
      expect(sent.receiveTimeout, PlatformStatusRepository.probeTimeout);
      expect(PlatformStatusRepository.probeTimeout, const Duration(seconds: 10));
    });

    test('liveness is sent once and fails on a 503', () async {
      adapter.replies.add((503, '{"error":{"code":"INTERNAL_ERROR","message":"down"}}'));

      final result = await repository.liveness();

      expect(result, isA<Failure<void>>().having((f) => f.error, 'error', isA<ServerError>()));
      expect(adapter.requests, hasLength(1), reason: 'the probe is not retried');
    });

    test('liveness is sent once and fails with a network error when Platform cannot be reached', () async {
      adapter.replies.add(const SocketException('Network is unreachable'));

      final result = await repository.liveness();

      expect(result, isA<Failure<void>>().having((f) => f.error, 'error', isA<NetworkError>()));
      expect(adapter.requests, hasLength(1), reason: 'the probe is not retried');
    });

    test('liveness fails with a timeout error after one request when Platform does not answer in time', () async {
      adapter.replies.add(DioExceptionType.receiveTimeout);

      final result = await repository.liveness();

      expect(result, isA<Failure<void>>().having((f) => f.error, 'error', isA<TimeoutError>()));
      expect(adapter.requests, hasLength(1));
    });

    test('liveness reaches Platform as soon as it answers after earlier checks failed', () async {
      adapter.replies.addAll([for (var i = 0; i < 8; i++) const SocketException('Connection refused')]);
      for (var i = 0; i < 8; i++) {
        expect(await repository.liveness(), isA<Failure<void>>());
      }
      adapter.replies.add((200, '{"status":"live"}'));

      expect(await repository.liveness(), isA<Success<void>>());
      expect(adapter.requests, hasLength(9));
    });

    // A cached answer would report an offline Platform as live.
    test('liveness is never answered from the cache', () async {
      adapter.replies.add((200, '{"status":"live"}'));
      expect(await repository.liveness(), isA<Success<void>>());
      adapter.replies.add(const SocketException('Network is unreachable'));

      expect(await repository.liveness(), isA<Failure<void>>());
      expect(await SharedPrefsCacheStorage().count(), 0);
    });

    // A captive portal or another server at the configured address answers 200 too.
    test('liveness fails with platform.unreadable_answer for a 200 that is not the liveness answer', () async {
      adapter.replies.add((200, '{"status":"healthy","service":"libredb-studio"}'));

      final result = await repository.liveness();

      expect(
        result,
        isA<Failure<void>>().having((f) => f.error.code, 'code', AppErrorCode.platformUnreadableAnswer.key),
      );
    });
  });

  // The client of such a build has no Dio at all, so it cannot send anything.
  test('a build without a Platform target fails without a request', () async {
    final client = PlatformApiClient(
      appConfig: _prodWith(const PlatformNotConfigured()),
      secureStorage: FlutterSecureStorageAdapter(),
      tokenRotation: const RefusingTokenRotation(),
    );

    final result = await PlatformStatusRepository(client).liveness();

    expect(result, isA<Failure<void>>().having((f) => f.error.code, 'code', AppErrorCode.platformNotConfigured.key));
    expect(() => client.instance, throwsA(isA<PlatformNotConfiguredException>()));
  });

  group('PlatformStatusJson', () {
    test('liveness accepts only {"status":"live"}', () {
      PlatformStatusJson.liveness('{"status":"live"}');
      for (final body in ['{"status":"healthy"}', '{"status":"ready"}', '{}', '[]', 'live', '{"status":1}']) {
        expect(() => PlatformStatusJson.liveness(body), throwsFormatException, reason: body);
      }
    });
  });
}

AppConfig _prodWith(PlatformTargetConfig platform) => AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: const [],
  idleTimeout: null,
  platform: platform,
);

/// Answers each request with the next queued status code and JSON body, or throws the next queued error (a
/// [DioExceptionType] for a [DioException] on the request), and keeps the requests it was sent.
class _QueuedAdapter implements HttpClientAdapter {
  final List<Object> replies = [];
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return switch (replies.removeAt(0)) {
      (final int status, final String body) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      final DioExceptionType type => throw DioException(requestOptions: options, type: type),
      final Object error => throw error,
    };
  }

  @override
  void close({bool force = false}) {}
}
