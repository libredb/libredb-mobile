import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/key_value_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/redis_key_read_generator.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

QueryResult _recorded(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

/// A one-row answer of Redis's provider: `{result: text}` (`formatResult`, `redis.ts:1635-1697`).
QueryResult _single(String text, {int rowCount = 1}) => QueryResult(
  fields: const ['result'],
  rows: [
    {'result': text},
  ],
  rowCount: rowCount,
  executionTime: Duration.zero,
);

void main() {
  late MockIStatementRepository statements;
  late MockIProviderMetaRepository providerMeta;
  const redis = 'seed:dev-redis';

  setUp(() {
    statements = MockIStatementRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(redis)).thenAnswer((_) async => Success(metaAnswer('meta_redis')));
  });

  var ids = 0;
  KeyValueBloc build({
    String connectionId = redis,
    List<String> container = const ['1'],
    String keyName = 'cache:greeting',
    String? type = 'string',
  }) => KeyValueBloc(
    statements: statements,
    providerMeta: providerMeta,
    connectionId: connectionId,
    container: container,
    keyName: keyName,
    type: type,
    newRunId: () => 'run-${++ids}',
  );

  void answerRun(String sql, Result<QueryResult> Function() answer) => when(
    () => statements.run(
      redis,
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      database: any(named: 'database'),
    ),
  ).thenAnswer((_) async => answer());

  int runsOf(String sql) => verify(
    () => statements.run(
      redis,
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      database: any(named: 'database'),
    ),
  ).callCount;

  group('the typed read of each recorded type in database 1', () {
    for (final (fixture, key, type, command, rows) in [
      ('query_redis_string', 'cache:greeting', 'string', 'GET cache:greeting', 1),
      ('query_redis_json', 'user:2:profile', 'string', 'GET user:2:profile', 1),
      ('query_redis_hash', 'user:2', 'hash', 'HGETALL user:2', 3),
      ('query_redis_list', 'session:2:events', 'list', 'LRANGE session:2:events 0 -1', 3),
      ('query_redis_set', 'user:2:roles', 'set', 'SMEMBERS user:2:roles', 2),
      ('query_redis_zset', 'cache:leaderboard', 'zset', 'ZRANGE cache:leaderboard 0 -1 WITHSCORES', 3),
      ('query_redis_stream', 'session:2:log', 'stream', 'XRANGE session:2:log - + COUNT 100', 2),
    ]) {
      blocTest<KeyValueBloc, KeyValueState>(
        '$type ($fixture) runs $command with database 1 as a number and a fresh run id',
        setUp: () => answerRun(command, () => Success(_recorded(fixture))),
        build: () => build(keyName: key, type: type),
        act: (bloc) => bloc.add(const KeyValueRequested(role: StudioAdminRole())),
        expect: () => [
          isA<KeyValueLoaded>()
              .having((s) => s.read, 'read', RedisKeyRead(statement: command, type: type))
              .having((s) => s.masked.result.rows, 'rows', hasLength(rows))
              .having((s) => s.policy, 'policy', MaskingPolicy.forRole(const StudioAdminRole()))
              .having((s) => s.isRefreshing, 'refreshing', isFalse),
        ],
        verify: (_) {
          final call = verify(
            () => statements.run(
              redis,
              command,
              queryId: captureAny(named: 'queryId'),
              page: QueryPage.first,
              database: 1,
            ),
          )..called(1);
          expect(call.captured.single, startsWith('run-'));
        },
      );
    }
  });

  blocTest<KeyValueBloc, KeyValueState>(
    'a container that is not all digits sends no database',
    setUp: () => answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string'))),
    build: () => build(container: const ['db1']),
    act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
    expect: () => [isA<KeyValueLoaded>()],
    verify: (_) => verify(
      () => statements.run(
        redis,
        'GET cache:greeting',
        queryId: any(named: 'queryId'),
        page: QueryPage.first,
      ),
    ).called(1),
  );

  blocTest<KeyValueBloc, KeyValueState>(
    'a stream field named email is masked by its name, and the entry id stays clear',
    setUp: () => answerRun(
      'XRANGE events - + COUNT 100',
      () => const Success(
        QueryResult(
          fields: ['id', 'email', 'action'],
          rows: [
            {'id': '1700000000000-0', 'email': 'grace@example.com', 'action': 'login'},
          ],
          rowCount: 1,
          executionTime: Duration.zero,
        ),
      ),
    ),
    build: () => build(keyName: 'events', type: 'stream'),
    act: (bloc) => bloc.add(const KeyValueRequested(role: StudioUserRole())),
    expect: () => [
      isA<KeyValueLoaded>()
          .having((s) => s.masked.maskedColumns, 'masked columns', {'email'})
          .having((s) => s.masked.result.rows.single['email'], 'email', isNot('grace@example.com'))
          .having((s) => s.masked.result.rows.single['id'], 'id', '1700000000000-0'),
    ],
  );

  blocTest<KeyValueBloc, KeyValueState>(
    'a hash field named email stays clear, as Studio\'s grid masks column names only (S-22)',
    setUp: () => answerRun('HGETALL user:2', () => Success(_recorded('query_redis_hash'))),
    build: () => build(keyName: 'user:2', type: 'hash'),
    act: (bloc) => bloc.add(const KeyValueRequested(role: StudioUserRole())),
    expect: () => [
      isA<KeyValueLoaded>()
          .having((s) => s.masked.maskedColumns, 'masked columns', isEmpty)
          .having((s) => s.masked.result.rows[1]['value'], 'email value', 'grace@example.com'),
    ],
  );

  group('a key the page named no type for', () {
    blocTest<KeyValueBloc, KeyValueState>(
      'runs TYPE only and shows Studio\'s answer with the typed read to offer',
      setUp: () => answerRun('TYPE user:2', () => Success(_single('hash'))),
      build: () => build(keyName: 'user:2', type: null),
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [
        isA<KeyValueTypeAnswered>().having((s) => s.type, 'type', 'hash').having((s) => s.readable, 'readable', 'hash'),
      ],
      verify: (_) => verifyNever(
        () => statements.run(
          redis,
          'HGETALL user:2',
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          database: any(named: 'database'),
        ),
      ),
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'Read value then runs the typed read for that type, and a refresh runs it again',
      setUp: () {
        answerRun('TYPE user:2', () => Success(_single('hash')));
        answerRun('HGETALL user:2', () => Success(_recorded('query_redis_hash')));
      },
      build: () => build(keyName: 'user:2', type: null),
      act: (bloc) async {
        bloc.add(const KeyValueRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const KeyValueTypedReadRequested(role: null, type: 'hash'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const KeyValueRequested(role: null));
      },
      expect: () => [
        isA<KeyValueTypeAnswered>(),
        isA<KeyValueTypeAnswered>().having((s) => s.isRefreshing, 'refreshing', isTrue),
        isA<KeyValueLoaded>().having((s) => s.read.type, 'type', 'hash').having((s) => s.run, 'run', 1),
        isA<KeyValueLoaded>().having((s) => s.isRefreshing, 'refreshing', isTrue),
        isA<KeyValueLoaded>().having((s) => s.run, 'run', 2),
      ],
      verify: (_) {
        expect(runsOf('TYPE user:2'), 1);
        expect(runsOf('HGETALL user:2'), 2);
      },
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'none says the key no longer exists',
      setUp: () => answerRun('TYPE gone', () => Success(_single('none'))),
      build: () => build(keyName: 'gone', type: null),
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [isA<KeyValueVanished>()],
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'a type outside the seven is shown with no read to offer',
      setUp: () => answerRun('TYPE vec', () => Success(_single('vectorset'))),
      build: () => build(keyName: 'vec', type: null),
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [
        isA<KeyValueTypeAnswered>()
            .having((s) => s.type, 'type', 'vectorset')
            .having((s) => s.readable, 'readable', isNull),
      ],
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'a page type outside the seven runs TYPE too',
      setUp: () => answerRun('TYPE vec', () => Success(_single('vectorset'))),
      build: () => build(keyName: 'vec', type: 'vectorset'),
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [isA<KeyValueTypeAnswered>()],
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'a TYPE answer without one text result is a failure of an unreadable answer',
      setUp: () => answerRun('TYPE odd', () => Success(_recorded('query_redis_hash'))),
      build: () => build(keyName: 'odd', type: null),
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [
        isA<KeyValueFailure>().having((s) => s.error.code, 'code', AppErrorCode.studioUnreadableAnswer.key),
      ],
    );
  });

  group('a key that vanished after the page listed it', () {
    for (final marker in ['(nil)', '(empty list)']) {
      blocTest<KeyValueBloc, KeyValueState>(
        '$marker with rowCount 0 says the key no longer exists',
        setUp: () => answerRun('GET cache:greeting', () => Success(_single(marker, rowCount: 0))),
        build: build,
        act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
        expect: () => [isA<KeyValueVanished>()],
      );
    }

    blocTest<KeyValueBloc, KeyValueState>(
      'a string whose value is the text (nil) is a value, since its rowCount is 1',
      setUp: () => answerRun('GET cache:greeting', () => Success(_single('(nil)'))),
      build: build,
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [isA<KeyValueLoaded>()],
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'a refresh reads it again, only when asked',
      setUp: () {
        var calls = 0;
        answerRun(
          'GET cache:greeting',
          () => calls++ == 0 ? Success(_single('(nil)', rowCount: 0)) : Success(_recorded('query_redis_string')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const KeyValueRequested(role: null));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const KeyValueRequested(role: null));
      },
      expect: () => [
        isA<KeyValueVanished>(),
        isA<KeyValueVanished>().having((s) => s.isRefreshing, 'refreshing', isTrue),
        isA<KeyValueLoaded>(),
      ],
    );
  });

  group('a failed read', () {
    const wrongType = ValidationError(
      'WRONGTYPE Operation against a key holding the wrong kind of value',
      code: 'studio.query_error',
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'keeps the error itself and is not run again by itself',
      setUp: () => answerRun('GET cache:greeting', () => const Failure(wrongType)),
      build: build,
      act: (bloc) async {
        bloc.add(const KeyValueRequested(role: null));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [const KeyValueFailure(error: wrongType)],
      verify: (_) => expect(runsOf('GET cache:greeting'), 1),
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'a refresh that fails keeps the value under the error',
      setUp: () {
        var calls = 0;
        answerRun(
          'GET cache:greeting',
          () => calls++ == 0 ? Success(_recorded('query_redis_string')) : const Failure(ServerError('down')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const KeyValueRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const KeyValueRequested(role: null));
      },
      skip: 2,
      expect: () => [
        isA<KeyValueFailure>()
            .having((s) => s.error, 'error', const ServerError('down'))
            .having((s) => s.previous, 'previous', isA<KeyValueLoaded>().having((p) => p.isRefreshing, 'r', isFalse)),
      ],
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'offline, a refresh that was never sent keeps the value as it was',
      setUp: () {
        var calls = 0;
        answerRun(
          'GET cache:greeting',
          () => calls++ == 0
              ? Success(_recorded('query_redis_string'))
              : Failure(NetworkError('offline', code: AppErrorCode.networkOffline.key)),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const KeyValueRequested(role: null));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const KeyValueRequested(role: null));
      },
      skip: 2,
      expect: () => [isA<KeyValueLoaded>().having((s) => s.isRefreshing, 'refreshing', isFalse)],
    );

    blocTest<KeyValueBloc, KeyValueState>(
      'a provider-meta failure is the page\'s failure, and nothing runs',
      setUp: () =>
          when(() => providerMeta.providerMeta(redis)).thenAnswer((_) async => const Failure(ServerError('down'))),
      build: build,
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [const KeyValueFailure(error: ServerError('down'))],
      verify: (_) => verifyNever(() => statements.run(any(), any(), page: any(named: 'page'))),
    );
  });

  for (final (label, connectionId, meta) in [
    ('an engine with a key-browser kind (etcd)', 'seed:etcd', 'handwritten/etcd/meta'),
    ('an engine that is not Redis (PostgreSQL)', 'seed:dev-postgres', 'meta_postgres'),
  ]) {
    blocTest<KeyValueBloc, KeyValueState>(
      '$label runs nothing and says so',
      setUp: () =>
          when(() => providerMeta.providerMeta(connectionId)).thenAnswer((_) async => Success(metaAnswer(meta))),
      build: () => build(connectionId: connectionId),
      act: (bloc) => bloc.add(const KeyValueRequested(role: null)),
      expect: () => [const KeyValueUnavailable()],
      verify: (_) => verifyNever(() => statements.run(any(), any(), page: any(named: 'page'))),
    );
  }
}
