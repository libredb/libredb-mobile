import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/answered.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';

/// Counts the requests the cache lets through, and names each answer after the request that got it, so a test can
/// tell a stored answer from a new one.
class _CountingBrowser implements IObjectBrowserRepository {
  final calls = <String>[];

  /// When true, each request waits until the test answers it through [pending], oldest first.
  bool hold = false;
  final pending = <Completer<Object>>[];

  /// When set, every request that does not wait fails with it.
  AppError? failWith;

  Future<Result<T>> _send<T>(String call, T data) async {
    calls.add(call);
    if (hold) {
      final answer = Completer<Object>();
      pending.add(answer);
      return await answer.future as Result<T>;
    }
    final error = failWith;
    return error == null ? Success(data) : Failure(error);
  }

  /// [_send], answered by Studio at the time the answer arrives.
  Future<Result<Answered<T>>> _sendAnswered<T>(String call, T data) async => switch (await _send(call, data)) {
    Success(:final data) => Success(Answered(data, at: clock.now())),
    Failure(:final error) => Failure(error),
  };

  /// Answers the oldest waiting request with [result], or the one at [index] of those still waiting.
  void answer(Object result, {int index = 0}) => pending.removeAt(index).complete(result);

  String get _n => '${calls.length + 1}';

  @override
  Future<Result<Answered<List<ObjectContainer>>>> containers(
    String connectionId, {
    List<String>? parent,
    bool refresh = false,
  }) => _sendAnswered('containers $connectionId $parent', [
    ObjectContainer(path: const ['public'], name: 'public $_n', level: 0),
  ]);

  @override
  Future<Result<Answered<Map<String, KindCount>>>> counts(
    String connectionId, {
    required List<String> container,
    bool refresh = false,
  }) => _sendAnswered('counts $connectionId $container', {'table': KindCounted(calls.length + 1)});

  @override
  Future<Result<Answered<List<DatabaseObject>>>> list(
    String connectionId, {
    required List<String> container,
    required String kind,
    bool refresh = false,
  }) => _sendAnswered('list $connectionId $container $kind', [
    DatabaseObject(path: [...container, 'orders'], name: 'orders $_n', kind: kind),
  ]);

  @override
  Future<Result<Answered<ObjectDetail>>> describe(
    String connectionId, {
    required List<String> path,
    required String kind,
    bool refresh = false,
  }) => _sendAnswered(
    'describe $connectionId $path $kind',
    ObjectDetail(path: [...path, _n], columns: const [], foreignKeys: const []),
  );

  @override
  Future<Result<ObjectSource>> source(String connectionId, {required List<String> path, required String kind}) =>
      _send('source $connectionId $path $kind', ObjectSource(path: path, kind: kind, parts: const []));

  @override
  Future<Result<List<DatabaseObject>>> search(String connectionId, {required String term, List<String>? kinds}) =>
      _send('search $connectionId $term', const <DatabaseObject>[]);

  @override
  Future<Result<KeyScanPage>> scanKeys(
    String connectionId, {
    String? cursor,
    String? pattern,
    int? count,
    int? database,
    bool level = false,
  }) => _send(
    'scanKeys $connectionId $cursor $pattern $count $database $level',
    const KeyScanPage(keys: [], cursor: '0', types: {}, total: 0),
  );
}

T _data<T>(Result<Answered<T>> result) => (result as Success<Answered<T>>).data.value;

const _sales = 'seed:sales-db';
const _crm = 'seed:crm-db';
const _public = ['public'];

/// Ends the session as a logout, an idle timeout or an unrefreshable 401 does: the stored session is wiped, and the
/// app drops the session's in-memory state.
Future<void> _endSession(CachedObjectBrowserRepository cache) async {
  await SessionGeneration.wipe(() async {});
  cache.clear();
}

void main() {
  late _CountingBrowser inner;
  late CachedObjectBrowserRepository cache;

  setUp(() {
    inner = _CountingBrowser();
    cache = CachedObjectBrowserRepository(inner);
  });

  group('within the time to live', () {
    test('going back and forth between levels sends each request once', () async {
      for (var visit = 0; visit < 3; visit++) {
        await cache.containers(_sales);
        await cache.containers(_sales, parent: const ['sales']);
        await cache.counts(_sales, container: _public);
        await cache.list(_sales, container: _public, kind: 'table');
        await cache.describe(_sales, path: const ['public', 'orders'], kind: 'table');
      }

      expect(inner.calls, [
        'containers $_sales null',
        'containers $_sales [sales]',
        'counts $_sales [public]',
        'list $_sales [public] table',
        'describe $_sales [public, orders] table',
      ]);
    });

    test('a stored answer is the answer the first request got', () async {
      final first = _data(await cache.list(_sales, container: _public, kind: 'table'));
      final second = _data(await cache.list(_sales, container: _public, kind: 'table'));

      expect(second, first);
      expect(second.single.name, 'orders 1');
    });

    test('a stored answer keeps the time Studio gave it, not the time it is read again', () async {
      var now = DateTime.utc(2026, 10, 23, 14);
      final answeredAt = now;
      await withClock(Clock(() => now), () async {
        cache = CachedObjectBrowserRepository(inner, now: () => now);
        await cache.containers(_sales);
        await cache.counts(_sales, container: _public);
        await cache.list(_sales, container: _public, kind: 'table');
        await cache.describe(_sales, path: const ['public', 'orders'], kind: 'table');

        now = now.add(const Duration(minutes: 9));
        final times = [
          (await cache.containers(_sales) as Success<Answered<Object>>).data.at,
          (await cache.counts(_sales, container: _public) as Success<Answered<Object>>).data.at,
          (await cache.list(_sales, container: _public, kind: 'table') as Success<Answered<Object>>).data.at,
          (await cache.describe(
            _sales,
            path: const ['public', 'orders'],
            kind: 'table',
          ) as Success<Answered<Object>>).data.at,
        ];

        expect(inner.calls, hasLength(4), reason: 'every second read came from the cache');
        expect(times, everyElement(answeredAt));
        final refreshed = await cache.containers(_sales, refresh: true);
        expect((refreshed as Success<Answered<Object>>).data.at, now, reason: 'a fresh answer has its own time');
      });
    });

    test('each connection, method, container, kind and path has its own entry', () async {
      await cache.list(_sales, container: _public, kind: 'table');
      await cache.list(_sales, container: _public, kind: 'view');
      await cache.list(_sales, container: const ['sales'], kind: 'table');
      await cache.list(_crm, container: _public, kind: 'table');
      await cache.counts(_sales, container: _public);
      await cache.describe(_sales, path: const ['public', 'orders'], kind: 'table');
      await cache.describe(_sales, path: const ['public', 'customers'], kind: 'table');

      expect(inner.calls, hasLength(7));
    });

    test('source, search and key pages are never stored', () async {
      for (var i = 0; i < 2; i++) {
        await cache.source(_sales, path: const ['public', 'active_orders'], kind: 'view');
        await cache.search(_sales, term: 'ord');
        await cache.scanKeys(_sales);
      }

      expect(inner.calls, hasLength(6));
    });

    test('a key page reaches Studio with its cursor, pattern, count, database and level as asked', () async {
      await cache.scanKeys(_sales, cursor: 'c1', pattern: 'users/', count: 10, database: 2, level: true);
      await cache.scanKeys(_sales);

      expect(inner.calls, ['scanKeys $_sales c1 users/ 10 2 true', 'scanKeys $_sales null null null null false']);
    });
  });

  test('an answer older than ten minutes is read again', () {
    fakeAsync((async) {
      final cache = CachedObjectBrowserRepository(inner);
      cache.counts(_sales, container: _public);
      async.flushMicrotasks();

      async.elapse(const Duration(minutes: 9, seconds: 59));
      cache.counts(_sales, container: _public);
      async.flushMicrotasks();
      expect(inner.calls, hasLength(1));

      async.elapse(const Duration(seconds: 1));
      Result<Answered<Map<String, KindCount>>>? result;
      cache.counts(_sales, container: _public).then((r) => result = r);
      async.flushMicrotasks();

      expect(inner.calls, hasLength(2));
      expect(_data(result!), {'table': const KindCounted(2)});
    });
  });

  test('two callers asking while the request is in flight share it', () async {
    inner.hold = true;
    final first = cache.containers(_sales);
    final second = cache.containers(_sales);

    inner.answer(
      Success([
        const ObjectContainer(path: ['public'], name: 'public', level: 0),
      ]),
    );

    expect(await first, await second);
    expect(inner.calls, hasLength(1));
  });

  group('a failure', () {
    test('is not stored', () async {
      inner.failWith = const ServerError('boom');
      expect(await cache.containers(_sales), isA<Failure<Answered<List<ObjectContainer>>>>());

      inner.failWith = null;
      expect(_data(await cache.containers(_sales)).single.name, 'public 2');
      expect(inner.calls, hasLength(2));
    });

    test('a 429 on a refresh is returned and the entry that was there stays', () async {
      await cache.list(_sales, container: _public, kind: 'table');
      inner.failWith = const RateLimitedError('slow down', retryAfter: Duration(seconds: 30));

      final refreshed = await cache.list(_sales, container: _public, kind: 'table', refresh: true);

      expect(
        refreshed,
        isA<Failure<Answered<List<DatabaseObject>>>>().having((f) => f.error, 'error', isA<RateLimitedError>()),
      );
      expect(_data(await cache.list(_sales, container: _public, kind: 'table')).single.name, 'orders 1');
      expect(inner.calls, hasLength(2));
    });
  });

  test('a refresh sends a request and replaces the entry', () async {
    await cache.counts(_sales, container: _public);

    final refreshed = await cache.counts(_sales, container: _public, refresh: true);

    expect(_data(refreshed), {'table': const KindCounted(2)});
    expect(_data(await cache.counts(_sales, container: _public)), {'table': const KindCounted(2)});
    expect(inner.calls, hasLength(2));
  });

  test('a request in flight when a refresh starts does not overwrite the refreshed answer', () async {
    inner.hold = true;
    final first = cache.containers(_sales);
    final refreshed = cache.containers(_sales, refresh: true);

    inner.answer(
      Success([
        const ObjectContainer(path: ['public'], name: 'refreshed', level: 0),
      ]),
      index: 1,
    );
    await refreshed;
    inner.answer(
      Success([
        const ObjectContainer(path: ['public'], name: 'older', level: 0),
      ]),
    );
    await first;

    inner.hold = false;
    expect(_data(await cache.containers(_sales)).single.name, 'refreshed');
    expect(inner.calls, hasLength(2));
  });

  test('a request overtaken by a refresh that answers first leaves later callers joining the refresh', () async {
    inner.hold = true;
    final first = cache.containers(_sales);
    final refreshed = cache.containers(_sales, refresh: true);

    inner.answer(
      Success([
        const ObjectContainer(path: ['public'], name: 'older', level: 0),
      ]),
    );
    await first;
    final third = cache.containers(_sales);

    expect(inner.calls, hasLength(2));
    inner.answer(
      Success([
        const ObjectContainer(path: ['public'], name: 'refreshed', level: 0),
      ]),
    );
    expect(_data(await third).single.name, 'refreshed');
    expect(_data(await refreshed).single.name, 'refreshed');
  });

  group('invalidation', () {
    test('invalidate drops every entry of the connection and no other', () async {
      await cache.containers(_sales);
      await cache.list(_sales, container: _public, kind: 'table');
      await cache.containers(_crm);

      cache.invalidate(_sales);
      await cache.containers(_sales);
      await cache.list(_sales, container: _public, kind: 'table');
      await cache.containers(_crm);

      expect(inner.calls, hasLength(5));
    });

    test(
      'invalidateContainer drops the container, what is under it and the list that names it, and nothing else',
      () async {
        await cache.containers(_sales);
        await cache.containers(_sales, parent: _public);
        await cache.counts(_sales, container: _public);
        await cache.list(_sales, container: _public, kind: 'table');
        await cache.describe(_sales, path: const ['public', 'orders'], kind: 'table');
        await cache.counts(_sales, container: const ['sales']);
        await cache.counts(_sales, container: const ['public_archive']);
        await cache.counts(_crm, container: _public);
        inner.calls.clear();

        cache.invalidateContainer(_sales, _public);
        await cache.containers(_sales);
        await cache.containers(_sales, parent: _public);
        await cache.counts(_sales, container: _public);
        await cache.list(_sales, container: _public, kind: 'table');
        await cache.describe(_sales, path: const ['public', 'orders'], kind: 'table');
        await cache.counts(_sales, container: const ['sales']);
        await cache.counts(_sales, container: const ['public_archive']);
        await cache.counts(_crm, container: _public);

        expect(inner.calls, [
          'containers $_sales null',
          'containers $_sales [public]',
          'counts $_sales [public]',
          'list $_sales [public] table',
          'describe $_sales [public, orders] table',
        ]);
      },
    );

    test('invalidateContainer of a nested container drops the list of its parent and keeps the top level', () async {
      await cache.containers(_sales);
      await cache.containers(_sales, parent: const ['sales']);
      await cache.containers(_sales, parent: const ['sales', 'public']);
      await cache.containers(_sales, parent: const ['crm']);
      inner.calls.clear();

      cache.invalidateContainer(_sales, const ['sales', 'public']);
      await cache.containers(_sales);
      await cache.containers(_sales, parent: const ['sales']);
      await cache.containers(_sales, parent: const ['sales', 'public']);
      await cache.containers(_sales, parent: const ['crm']);

      expect(inner.calls, ['containers $_sales [sales]', 'containers $_sales [sales, public]']);
    });

    test('an entry keeps its key when the caller changes the list it passed', () async {
      final container = ['public'];
      await cache.counts(_sales, container: container);
      container[0] = 'sales';

      cache.invalidateContainer(_sales, const ['sales']);
      await cache.counts(_sales, container: const ['public']);

      expect(inner.calls, hasLength(1));
    });

    for (final (name, invalidate) in <(String, void Function(CachedObjectBrowserRepository))>[
      ('invalidate', (cache) => cache.invalidate(_sales)),
      ('invalidateContainer', (cache) => cache.invalidateContainer(_sales, _public)),
    ]) {
      test('an answer in flight across $name is returned but not stored, and no later caller joins it', () async {
        inner.hold = true;
        final before = cache.list(_sales, container: _public, kind: 'table');

        invalidate(cache);
        final after = cache.list(_sales, container: _public, kind: 'table');
        expect(inner.calls, hasLength(2), reason: 'the caller after the invalidation sends its own request');

        inner.answer(
          Success([
            const DatabaseObject(path: ['public', 'dropped'], name: 'dropped', kind: 'table'),
          ]),
        );
        expect(_data(await before).single.name, 'dropped');
        inner.answer(
          Success([
            const DatabaseObject(path: ['public', 'orders'], name: 'orders', kind: 'table'),
          ]),
        );
        await after;

        inner.hold = false;
        expect(_data(await cache.list(_sales, container: _public, kind: 'table')).single.name, 'orders');
        expect(inner.calls, hasLength(2));
      });
    }

    for (final (name, invalidate) in <(String, void Function(CachedObjectBrowserRepository))>[
      ('invalidate', (cache) => cache.invalidate(_sales)),
      ('invalidateContainer', (cache) => cache.invalidateContainer(_sales, _public)),
      ('clear', (cache) => cache.clear()),
    ]) {
      test('the only answer in flight across $name is not stored, so the next read sends a request', () async {
        inner.hold = true;
        final before = cache.list(_sales, container: _public, kind: 'table');

        invalidate(cache);
        inner.answer(
          Success([
            const DatabaseObject(path: ['public', 'dropped'], name: 'dropped', kind: 'table'),
          ]),
        );
        await before;

        inner.hold = false;
        expect(_data(await cache.list(_sales, container: _public, kind: 'table')).single.name, 'orders 2');
        expect(inner.calls, hasLength(2));
      });
    }

    test('an answer in flight for another connection survives an invalidation', () async {
      inner.hold = true;
      final crm = cache.containers(_crm);
      cache.invalidate(_sales);
      inner.answer(
        Success([
          const ObjectContainer(path: ['public'], name: 'crm', level: 0),
        ]),
      );
      await crm;

      inner.hold = false;
      expect(_data(await cache.containers(_crm)).single.name, 'crm');
      expect(inner.calls, hasLength(1));
    });
  });

  group('the session end', () {
    test('clears every entry', () async {
      await cache.containers(_sales);
      await cache.counts(_crm, container: _public);

      await _endSession(cache);

      expect(cache.entryCount, 0);
      await cache.containers(_sales);
      await cache.counts(_crm, container: _public);
      expect(inner.calls, hasLength(4));
    });

    test('a wiped session serves no entry stored under it, even before the clear runs', () async {
      await cache.containers(_sales);

      await SessionGeneration.wipe(() async {});

      await cache.containers(_sales);
      expect(inner.calls, hasLength(2));
    });

    test('an answer in flight across it completes its callers and is not stored', () async {
      inner.hold = true;
      final before = cache.containers(_sales);

      await _endSession(cache);
      inner.answer(
        Success([
          const ObjectContainer(path: ['public'], name: 'previous user', level: 0),
        ]),
      );

      expect(_data(await before).single.name, 'previous user');
      expect(cache.entryCount, 0);
    });

    test('an answer in flight across a wipe is not stored when the clear has not run', () async {
      inner.hold = true;
      final before = cache.containers(_sales);

      await SessionGeneration.wipe(() async {});
      inner.answer(
        Success([
          const ObjectContainer(path: ['public'], name: 'previous user', level: 0),
        ]),
      );
      await before;

      expect(cache.entryCount, 0);
    });

    test('a caller after it gets its own request', () async {
      inner.hold = true;
      final before = cache.containers(_sales);

      await SessionGeneration.wipe(() async {});
      final after = cache.containers(_sales);

      expect(inner.calls, hasLength(2));
      inner.answer(
        Success([
          const ObjectContainer(path: ['public'], name: 'previous user', level: 0),
        ]),
      );
      inner.answer(
        Success([
          const ObjectContainer(path: ['public'], name: 'next user', level: 0),
        ]),
      );
      expect(_data(await before).single.name, 'previous user');
      expect(_data(await after).single.name, 'next user');

      inner.hold = false;
      expect(_data(await cache.containers(_sales)).single.name, 'next user');
      expect(inner.calls, hasLength(2));
    });
  });

  test('a connection switch keeps fresh entries and evicts expired ones', () {
    fakeAsync((async) {
      final cache = CachedObjectBrowserRepository(inner);
      cache.containers(_sales);
      async.elapse(const Duration(minutes: 6));
      cache.containers(_crm);
      async.elapse(const Duration(minutes: 5));

      cache.evictExpired();

      expect(cache.entryCount, 1);
      cache.containers(_crm);
      async.flushMicrotasks();
      expect(inner.calls, hasLength(2), reason: 'the entry stored five minutes ago is still served');
    });
  });

  test('a vanished connection, invalidated, has no entry left', () async {
    await cache.containers(_sales);
    await cache.counts(_sales, container: _public);
    await cache.containers(_crm);

    cache.invalidate(_sales);

    expect(cache.entryCount, 1);
  });
}
