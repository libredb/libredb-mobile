import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/usecases/switch_session_target_usecase.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';

/// The switch to Studio over the production interceptor chain, retry and circuit breaker included, with only the
/// network replaced: what a Platform session meets when the edge in front of a stopped Studio answers 502 (#338).
void main() {
  late _QueuedAdapter adapter;
  late MockIAuthSessionRepository sessionRepository;
  late SwitchSessionTargetUseCase switchTarget;

  setUp(() {
    ResilienceInterceptor.instance.resetAll();
    adapter = _QueuedAdapter();
    TestEnv.authenticate(target: SessionTarget.platform);
    final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
    client.instance.httpClientAdapter = adapter;
    sessionRepository = MockIAuthSessionRepository();
    when(() => sessionRepository.persistTarget(any(), generation: any(named: 'generation')))
        .thenAnswer((_) async => const Success(null));
    switchTarget = SwitchSessionTargetUseCase(StudioIdentityRepository(client), null, sessionRepository);
  });

  tearDown(() => ResilienceInterceptor.instance.resetAll());

  test('an edge 502 without a code refuses the switch as Studio not answering, after one request', () async {
    adapter.replies.add((502, '<html>Bad Gateway</html>'));

    final result = await switchTarget(SessionTarget.studio);

    expect(result, const SessionTargetSwitchRefused(AppErrorCode.studioUnreachable));
    expect(adapter.requestCount, 1);
    verifyZeroInteractions(sessionRepository);
  });

  test('a connection that fails refuses the switch as Studio not answering', () async {
    adapter.replies.add(DioExceptionType.connectionError);

    final result = await switchTarget(SessionTarget.studio);

    expect(result, const SessionTargetSwitchRefused(AppErrorCode.studioUnreachable));
  });

  // A refused switch counts nothing toward the circuit for /auth/me, so the user's next tap once Studio is back
  // reaches Studio instead of waiting out a circuit the refusals opened.
  test('refused switches leave the circuit closed, so the switch right after Studio recovers reaches Studio', () async {
    adapter.replies.addAll([(502, ''), (502, ''), (502, '')]);
    for (var i = 0; i < 3; i++) {
      expect(
        await switchTarget(SessionTarget.studio),
        const SessionTargetSwitchRefused(AppErrorCode.studioUnreachable),
      );
    }
    adapter.replies.add((200, _me));

    final result = await switchTarget(SessionTarget.studio);

    expect(result, isA<SwitchedToStudio>());
    expect(adapter.requestCount, 4);
    expect(ResilienceInterceptor.instance.circuitBreakers['/auth/me']?.failureCount ?? 0, 0);
  });

  test('a circuit that other requests to /auth/me opened does not hold back the switch', () async {
    final breaker = ResilienceInterceptor.instance;
    final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
    client.instance.httpClientAdapter = adapter;
    adapter.replies.addAll(List.filled(2 * (breaker.maxRetries + 1), (502, '')));
    // Two identity reads of the shell, which are retried and counted until the circuit opens.
    await StudioIdentityRepository(client).fetch();
    await StudioIdentityRepository(client).fetch();
    expect(breaker.circuitBreakers['/auth/me']!.allowRequest, isFalse);
    adapter.replies
      ..clear()
      ..add((200, _me));

    final result = await switchTarget(SessionTarget.studio);

    expect(result, isA<SwitchedToStudio>());
  });
}

const _me = '{"authenticated":true,"user":{"role":"admin","username":"user@example.com","channel":"bearer"}}';

const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
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
          Headers.contentTypeHeader: [status == 200 ? Headers.jsonContentType : 'text/html'],
        },
      ),
      final DioExceptionType type => throw DioException(requestOptions: options, type: type),
      final Object other => throw StateError('No reply of $other'),
    };
  }

  @override
  void close({bool force = false}) {}
}
