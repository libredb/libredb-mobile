import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';

/// The connection list through the production interceptor chain, fed the answers recorded from the governed profile of
/// tool/studio-dev: the granted list, the 503 while its governance source was stopped, and the list again once it was
/// back (docs/studio.md).
void main() {
  String fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

  late _QueuedAdapter adapter;
  late ConnectionListBloc bloc;

  setUp(() {
    ResilienceInterceptor.instance.resetAll();
    adapter = _QueuedAdapter();
    final client = ApiClient(tokenRotation: const RefusingTokenRotation(), appConfig: _prodConfig);
    client.instance.httpClientAdapter = adapter;
    bloc = ConnectionListBloc(
      listManagedConnectionsUseCase: ListManagedConnectionsUseCase(
        ConnectionRepository(client, ConnectionQueryTimeouts()),
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
    ResilienceInterceptor.instance.resetAll();
  });

  Future<ConnectionListState> settle(ConnectionListEvent event) {
    final settled = bloc.stream.firstWhere(
      (state) => switch (state) {
        ConnectionListLoaded(:final isRefreshing) => !isRefreshing,
        ConnectionListUnavailable(:final isRetrying) => !isRetrying,
        ConnectionListFailure() => true,
        ConnectionListInitial() || ConnectionListLoading() => false,
      },
    );
    bloc.add(event);
    return settled;
  }

  test('a governance outage keeps the granted rows and the list comes back once the source answers again', () async {
    adapter.replies.addAll([
      (200, fixture('managed_governed')),
      (503, fixture('governance_unavailable')),
      (200, fixture('managed_governed')),
    ]);

    final loaded = await settle(const ConnectionListRequested()) as ConnectionListLoaded;
    expect(loaded.connections.map((c) => c.id), ['seed:sales-dev', 'seed:sales-prod']);
    expect(loaded.cacheHint, const Duration(seconds: 10));

    final unavailable = await settle(const ConnectionListRefreshed());
    expect(
      unavailable,
      isA<ConnectionListUnavailable>()
          .having((s) => s.errorCode, 'errorCode', AppErrorCode.studioGovernanceUnavailable)
          .having((s) => s.previous?.connections, 'previous rows', loaded.connections),
    );

    final recovered = await settle(const ConnectionListRefreshed());
    expect(recovered, isA<ConnectionListLoaded>().having((s) => s.connections, 'connections', loaded.connections));
    expect(adapter.requestCount, 3);
  });

  test('a governance outage on a cold start shows no rows and no empty list', () async {
    adapter.replies.add((503, fixture('governance_unavailable')));

    expect(
      await settle(const ConnectionListRequested()),
      const ConnectionListUnavailable(errorCode: AppErrorCode.studioGovernanceUnavailable),
    );
  });
}

/// The production chain, without a stored token and on a status the refresh leaves alone.
const _prodConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://studio.example.test/api',
  certificatePins: [],
  idleTimeout: null,
);

/// Answers each request with the next queued status code and JSON body.
class _QueuedAdapter implements HttpClientAdapter {
  final List<(int, String)> replies = [];
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    final (status, body) = replies.removeAt(0);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
