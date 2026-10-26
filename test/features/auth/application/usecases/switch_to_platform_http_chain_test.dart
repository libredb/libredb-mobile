import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/switch_session_target_usecase.dart';
import 'package:libredb_mobile/features/auth/data/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';

/// The switch to Platform over the production interceptor chain, retry and circuit breaker included, with only the
/// network replaced: what a Studio session meets when the edge in front of a stopped Platform answers 502 (#343), the
/// mirror of the switch to Studio (#338).
void main() {
  late _QueuedAdapter adapter;
  late MockIAuthSessionRepository sessionRepository;
  late SwitchSessionTargetUseCase switchTarget;

  PlatformApiClient platformClient() {
    final client = PlatformApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
    client.instance.httpClientAdapter = adapter;
    return client;
  }

  setUp(() {
    ResilienceInterceptor.instance.resetAll();
    adapter = _QueuedAdapter();
    TestEnv.authenticate();
    sessionRepository = MockIAuthSessionRepository();
    when(() => sessionRepository.persistTarget(any(), generation: any(named: 'generation')))
        .thenAnswer((_) async => const Success(null));
    switchTarget = SwitchSessionTargetUseCase(
      MockIStudioIdentityRepository(),
      PlatformIdentityRepository(platformClient()),
      sessionRepository,
    );
  });

  tearDown(() => ResilienceInterceptor.instance.resetAll());

  test('an edge 502 without a code refuses the switch as Platform not answering, after one request', () async {
    adapter.replies.add((502, '<html>Bad Gateway</html>'));

    final result = await switchTarget(SessionTarget.platform);

    expect(result, const SessionTargetSwitchRefused(AppErrorCode.platformUnreachable));
    expect(adapter.requestCount, 1);
    verifyZeroInteractions(sessionRepository);
  });

  test('a connection that fails refuses the switch as Platform not answering', () async {
    adapter.replies.add(DioExceptionType.connectionError);

    final result = await switchTarget(SessionTarget.platform);

    expect(result, const SessionTargetSwitchRefused(AppErrorCode.platformUnreachable));
  });

  test('a 500 INTERNAL_ERROR, which Platform answered itself, keeps its own code', () async {
    adapter.replies.add((500, '{"error":{"code":"INTERNAL_ERROR","message":"Internal server error"}}'));

    final result = await switchTarget(SessionTarget.platform);

    expect(result, const SessionTargetSwitchRefused(AppErrorCode.platformInternalError));
  });

  // A refused switch counts nothing toward the circuit for /v1/me, so the user's next tap once Platform is back
  // reaches Platform instead of waiting out a circuit the refusals opened.
  test('refused switches leave the circuit closed, so the switch right after Platform recovers reaches it', () async {
    adapter.replies.addAll([(502, ''), (502, ''), (502, '')]);
    for (var i = 0; i < 3; i++) {
      expect(
        await switchTarget(SessionTarget.platform),
        const SessionTargetSwitchRefused(AppErrorCode.platformUnreachable),
      );
    }
    adapter.replies.add((200, _me));

    final result = await switchTarget(SessionTarget.platform);

    expect(result, isA<SwitchedToPlatform>());
    expect(adapter.requestCount, 4);
    expect(
      ResilienceInterceptor.instance.circuitBreakers.values.map((breaker) => breaker.failureCount),
      everyElement(0),
    );
  });

  test('a circuit that other requests to /v1/me opened does not hold back the switch', () async {
    final breaker = ResilienceInterceptor.instance;
    adapter.replies.addAll(List.filled(2 * (breaker.maxRetries + 1), (502, '')));
    // Two identity reads of the Platform shell, which are retried and counted until the circuit opens.
    await PlatformIdentityRepository(platformClient()).fetch();
    await PlatformIdentityRepository(platformClient()).fetch();
    expect(breaker.circuitBreakers.values.any((circuit) => !circuit.allowRequest), isTrue);
    adapter.replies
      ..clear()
      ..add((200, _me));

    final result = await switchTarget(SessionTarget.platform);

    expect(result, isA<SwitchedToPlatform>());
  });
}

const _me =
    '{"id":"usr_1","email":"admin@example.com","name":"Ada Admin","roles":["PLATFORM_ADMIN"],'
    '"permissions":["connections:read"],"tenant":{"id":"tnt_1","name":"Example","slug":"example"}}';

const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
  platform: PlatformConfigured(baseUrl: 'https://platform.example.test/api', certificatePins: []),
);

/// Answers each request with the next queued status code and body, or throws a [DioException] of the next queued type.
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
          Headers.contentTypeHeader: [status == 200 || body.startsWith('{') ? Headers.jsonContentType : 'text/html'],
        },
      ),
      final DioExceptionType type => throw DioException(requestOptions: options, type: type),
      final Object other => throw StateError('No reply of $other'),
    };
  }

  @override
  void close({bool force = false}) {}
}
