import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/data/models/studio_status_json.dart';
import 'package:libredb_mobile/features/studio_status/data/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';

import '../../../../support/test_env.dart';

void main() {
  group('through the mock', () {
    // Both endpoints are public: the app checks Studio before anyone has signed in.
    test('liveness succeeds without a stored token', () async {
      expect(await StudioStatusRepository(TestEnv.apiClient()).liveness(), isA<Success<void>>());
    });

    test('readiness reads Studio without governance as ready, without a stored token', () async {
      expect(
        await StudioStatusRepository(TestEnv.apiClient()).readiness(),
        const Success<StudioReadiness>(StudioReadinessReady()),
      );
    });
  });

  group('over the production chain', () {
    late _QueuedAdapter adapter;
    late StudioStatusRepository repository;

    setUp(() {
      ResilienceInterceptor.instance.resetAll();
      adapter = _QueuedAdapter();
      final client = ApiClient(appConfig: _prodConfig);
      client.instance.httpClientAdapter = adapter;
      repository = StudioStatusRepository(client);
    });

    tearDown(() => ResilienceInterceptor.instance.resetAll());

    test('liveness asks GET /api/health without a token and with the probe timeout', () async {
      adapter.replies.add((
        200,
        '{"status":"healthy","timestamp":"2026-10-22T15:00:55.811Z","service":"libredb-studio"}',
      ));

      expect(await repository.liveness(), isA<Success<void>>());
      final sent = adapter.requests.single;
      expect(sent.uri.toString(), 'https://studio.example.test/api/health');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(sent.connectTimeout, studioProbeTimeout);
      expect(sent.receiveTimeout, studioProbeTimeout);
    });

    test('liveness fails with a network error after one request when Studio cannot be reached', () async {
      adapter.replies.add(const SocketException('Network is unreachable'));

      final result = await repository.liveness();

      expect(result, isA<Failure<void>>().having((f) => f.error, 'error', isA<NetworkError>()));
      expect(adapter.requests, hasLength(1), reason: 'the probe is not retried');
    });

    // The probe timeout is the whole wait: a Studio that accepts the connection and hangs shows the page after it.
    test('liveness fails with a timeout error after one request when Studio does not answer in time', () async {
      adapter.replies.add(DioExceptionType.receiveTimeout);

      final result = await repository.liveness();

      expect(result, isA<Failure<void>>().having((f) => f.error, 'error', isA<TimeoutError>()));
      expect(adapter.requests, hasLength(1), reason: 'the probe is not retried');
    });

    // Regression: the failed checks of a starting Studio opened the /health circuit, so Retry kept failing with
    // CircuitBreakerOpenException for 30 seconds after Studio was up, without sending a request.
    test('liveness reaches Studio as soon as it answers after earlier checks failed', () async {
      adapter.replies.addAll([for (var i = 0; i < 8; i++) const SocketException('Connection refused')]);
      for (var i = 0; i < 8; i++) {
        expect(await repository.liveness(), isA<Failure<void>>());
      }
      adapter.replies.add((
        200,
        '{"status":"healthy","timestamp":"2026-10-22T15:00:55.811Z","service":"libredb-studio"}',
      ));

      expect(await repository.liveness(), isA<Success<void>>());
      expect(adapter.requests, hasLength(9));
      expect(ResilienceInterceptor.instance.circuitBreakers['/health']?.failureCount ?? 0, 0);
    });

    test('readiness is sent once and not counted when Studio cannot be reached', () async {
      adapter.replies.addAll([for (var i = 0; i < 6; i++) const SocketException('Connection refused')]);
      for (var i = 0; i < 6; i++) {
        expect(await repository.readiness(), isA<Failure<StudioReadiness>>());
      }

      expect(adapter.requests, hasLength(6));
      expect(ResilienceInterceptor.instance.circuitBreakers['/ready']?.failureCount ?? 0, 0);
    });

    // A captive portal or another server at the configured address answers 200 too.
    test('liveness fails with studio.unreadable_answer for a 200 that is not Studio', () async {
      adapter.replies.add((200, '{"status":"ok"}'));

      final result = await repository.liveness();

      expect(result, isA<Failure<void>>().having((f) => f.error.code, 'code', AppErrorCode.studioUnreadableAnswer.key));
    });

    for (final (status, body, expected) in <(int, String, StudioReadiness)>[
      (200, '{"status":"ready","contract":{"supported":[1],"active":null}}', const StudioReadinessReady()),
      (200, '{"status":"ok","contract":{"supported":[1],"active":1}}', const StudioReadinessOk()),
      (200, '{"status":"degraded","contract":{"supported":[1],"active":1}}', const StudioReadinessDegraded()),
      (503, '{"status":"loading","contract":{"supported":[1],"active":null}}', const StudioReadinessLoading()),
      (
        503,
        '{"status":"misconfigured","contract":{"supported":[1],"active":null},"detail":"libredb_connections: 42501"}',
        const StudioReadinessMisconfigured(detail: 'libredb_connections: 42501'),
      ),
      (
        503,
        '{"status":"incompatible","contract":{"supported":[1],"active":null},"detail":"supported 1, source 2"}',
        const StudioReadinessIncompatible(detail: 'supported 1, source 2'),
      ),
    ]) {
      test('readiness reads $status ${expected.runtimeType} after one request', () async {
        adapter.replies.add((status, body));

        expect(await repository.readiness(), Success(expected));
        expect(adapter.requests, hasLength(1), reason: "Studio's answer is not retried");
        expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
        expect(ResilienceInterceptor.instance.circuitBreakers['/ready']?.failureCount ?? 0, 0);
      });
    }

    // A proxy in front of a stopped Studio answers 503 with a page of its own.
    test('readiness fails with studio.unreadable_answer for a 503 that is not a readiness answer', () async {
      adapter.replies.add((503, '<html>Service Unavailable</html>'));

      final result = await repository.readiness();

      expect(
        result,
        isA<Failure<StudioReadiness>>().having((f) => f.error.code, 'code', AppErrorCode.studioUnreadableAnswer.key),
      );
    });

    test('readiness fails for an unknown status', () async {
      adapter.replies.add((200, '{"status":"starting"}'));

      final result = await repository.readiness();

      expect(
        result,
        isA<Failure<StudioReadiness>>().having((f) => f.error.code, 'code', AppErrorCode.studioUnreadableAnswer.key),
      );
    });
  });

  group('StudioStatusJson', () {
    test('liveness accepts only a healthy LibreDB Studio', () {
      StudioStatusJson.liveness('{"status":"healthy","timestamp":"t","service":"libredb-studio"}');
      for (final body in [
        '{"status":"healthy","service":"other"}',
        '{"status":"down","service":"libredb-studio"}',
        '{"service":"libredb-studio"}',
        '[]',
        'healthy',
      ]) {
        expect(() => StudioStatusJson.liveness(body), throwsFormatException, reason: body);
      }
    });

    test('readiness leaves out a detail that is not a string', () {
      expect(
        StudioStatusJson.readiness('{"status":"misconfigured","detail":42}'),
        const StudioReadinessMisconfigured(),
      );
    });

    test('readiness refuses an answer without a string status', () {
      for (final body in ['{}', '{"status":1}', '[]', 'ready']) {
        expect(() => StudioStatusJson.readiness(body), throwsFormatException, reason: body);
      }
    });
  });
}

/// The production chain, without a stored token.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
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
      // Dio reports a timeout with the options of the request it sent.
      final DioExceptionType type => throw DioException(requestOptions: options, type: type),
      final Object error => throw error,
    };
  }

  @override
  void close({bool force = false}) {}
}
