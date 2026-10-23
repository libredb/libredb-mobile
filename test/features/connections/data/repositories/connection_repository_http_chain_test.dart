import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';

/// [ConnectionRepository] over the production interceptor chain, retry, circuit breaker and response cache included,
/// with only the network replaced.
void main() {
  late _QueuedAdapter adapter;
  late ConnectionRepository repository;

  setUp(() {
    ResilienceInterceptor.instance.resetAll();
    adapter = _QueuedAdapter();
    final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
    client.instance.httpClientAdapter = adapter;
    repository = ConnectionRepository(client, ConnectionQueryTimeouts());
  });

  tearDown(() => ResilienceInterceptor.instance.resetAll());

  test('a 503 GOVERNANCE_UNAVAILABLE reaches the repository after one request and does not move the breaker', () async {
    adapter.replies.add((503, '{"error":"Governance unavailable","code":"GOVERNANCE_UNAVAILABLE","statusCode":503}'));

    final result = await repository.listManaged();

    expect(
      result,
      isA<Failure<ManagedConnections>>().having(
        (f) => f.error.code,
        'code',
        AppErrorCode.studioGovernanceUnavailable.key,
      ),
    );
    expect(adapter.requestCount, 1);
    expect(ResilienceInterceptor.instance.circuitBreakers['/connections/managed']?.failureCount ?? 0, 0);
  });

  test('a check whose database refuses its credential reaches the sheet after one request, with its fix', () async {
    adapter.replies.add((
      401,
      '{"error":"password authentication failed","code":"AUTH_ERROR","fixStatement":"ALTER USER app PASSWORD"}',
    ));

    final result = await repository.test('seed:sales-postgres');

    expect(
      result,
      isA<Failure<ConnectionTestResult>>().having(
        (f) => f.error,
        'error',
        isA<AuthError>()
            .having((e) => e.code, 'code', AppErrorCode.studioDatabaseAuth.key)
            .having((e) => e.fixStatement, 'fixStatement', 'ALTER USER app PASSWORD'),
      ),
    );
    expect(adapter.requestCount, 1);
  });

  test('a rate-limited check is not sent again and carries the delay Studio asked for', () async {
    adapter.replies.add((
      429,
      '{"error":"Too many requests","code":"RATE_LIMITED"}',
      {
        'retry-after': ['12'],
      },
    ));

    final result = await repository.test('seed:sales-postgres');

    expect(
      result,
      isA<Failure<ConnectionTestResult>>().having(
        (f) => f.error,
        'error',
        isA<RateLimitedError>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 12)),
      ),
    );
    expect(adapter.requestCount, 1);
  });

  test('offline, listManaged returns a network failure, not the list it read before', () async {
    adapter.replies.add((200, '{"connections":[{"id":"seed:sales-postgres","name":"Sales","type":"postgres"}]}'));
    expect(await repository.listManaged(), isA<Success<ManagedConnections>>());

    adapter.replies.addAll([for (var i = 0; i < 4; i++) const SocketException('Network is unreachable')]);
    final result = await repository.listManaged();

    expect(result, isA<Failure<ManagedConnections>>().having((f) => f.error, 'error', isA<NetworkError>()));
  });

  test('offline, fetchPolicy returns a network failure, not the policy it read before', () async {
    adapter.replies.add((200, '{"customConnections":false,"governance":true,"statementCapture":"full"}'));
    expect(await repository.fetchPolicy(), isA<Success>());

    adapter.replies.addAll([for (var i = 0; i < 4; i++) const SocketException('Network is unreachable')]);
    final result = await repository.fetchPolicy();

    expect(result, isA<Failure>().having((f) => f.error, 'error', isA<NetworkError>()));
  });
}

/// The production chain, without a stored token and on a status the refresh leaves alone.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
);

/// Answers each request with the next queued status code, JSON body and headers, or throws the next queued error.
class _QueuedAdapter implements HttpClientAdapter {
  final List<Object> replies = [];
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    return switch (replies.removeAt(0)) {
      (final int status, final String body) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      (final int status, final String body, final Map<String, List<String>> headers) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      ),
      final Object error => throw error,
    };
  }

  @override
  void close({bool force = false}) {}
}
