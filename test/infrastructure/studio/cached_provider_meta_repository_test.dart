import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

ProviderMeta _meta(String language) => ProviderMeta(
  queryLanguage: language,
  schemaRefreshPattern: r'(CREATE|DROP|ALTER|TRUNCATE)\b',
  containerLevels: const [],
  objectKinds: const [],
);

/// Counts the requests the cache lets through, and answers the n-th with the query language `n`.
class _CountingProviderMeta implements IProviderMetaRepository {
  final calls = <String>[];

  /// When true, each request waits until the test answers it through [answer], oldest first.
  bool hold = false;
  final _pending = <Completer<Result<ProviderMeta>>>[];

  /// When set, every request that does not wait fails with it.
  AppError? failWith;

  void answer(Result<ProviderMeta> result) => _pending.removeAt(0).complete(result);

  @override
  Future<Result<ProviderMeta>> providerMeta(String connectionId) async {
    calls.add(connectionId);
    if (hold) {
      final answer = Completer<Result<ProviderMeta>>();
      _pending.add(answer);
      return answer.future;
    }
    final error = failWith;
    return error == null ? Success(_meta('${calls.length}')) : Failure(error);
  }
}

String _language(Result<ProviderMeta> result) => (result as Success<ProviderMeta>).data.queryLanguage;

const _sales = 'seed:sales-db';
const _crm = 'seed:crm-db';

void main() {
  late _CountingProviderMeta inner;
  late CachedProviderMetaRepository cache;

  setUp(() {
    inner = _CountingProviderMeta();
    cache = CachedProviderMetaRepository(inner);
  });

  test('an answer is served for the rest of the session, however long it lasts', () {
    fakeAsync((async) {
      final cache = CachedProviderMetaRepository(inner);
      cache.providerMeta(_sales);
      async.flushMicrotasks();

      async.elapse(const Duration(hours: 8));
      Result<ProviderMeta>? result;
      cache.providerMeta(_sales).then((r) => result = r);
      async.flushMicrotasks();

      expect(_language(result!), '1');
      expect(inner.calls, [_sales]);
    });
  });

  test('each connection has its own entry', () async {
    await cache.providerMeta(_sales);
    await cache.providerMeta(_crm);
    await cache.providerMeta(_sales);

    expect(inner.calls, [_sales, _crm]);
  });

  test('two callers asking while the request is in flight share it', () async {
    inner.hold = true;
    final first = cache.providerMeta(_sales);
    final second = cache.providerMeta(_sales);

    inner.answer(Success(_meta('sql')));

    expect(_language(await first), 'sql');
    expect(_language(await second), 'sql');
    expect(inner.calls, hasLength(1));
  });

  test('a failure, a 429 among them, is returned and not stored', () async {
    inner.failWith = const RateLimitedError('slow down');
    expect(
      await cache.providerMeta(_sales),
      isA<Failure<ProviderMeta>>().having((f) => f.error, 'error', isA<RateLimitedError>()),
    );

    inner.failWith = null;
    expect(_language(await cache.providerMeta(_sales)), '2');
    expect(inner.calls, hasLength(2));
  });

  test('a vanished connection, invalidated, is read afresh and the others are kept', () async {
    await cache.providerMeta(_sales);
    await cache.providerMeta(_crm);

    cache.invalidate(_sales);

    expect(cache.entryCount, 1);
    expect(_language(await cache.providerMeta(_sales)), '3');
    await cache.providerMeta(_crm);
    expect(inner.calls, [_sales, _crm, _sales]);
  });

  test('an answer in flight across an invalidation is returned but not stored, and no later caller joins it', () async {
    inner.hold = true;
    final before = cache.providerMeta(_sales);

    cache.invalidate(_sales);
    final after = cache.providerMeta(_sales);
    expect(inner.calls, hasLength(2));

    inner.answer(Success(_meta('before')));
    inner.answer(Success(_meta('after')));
    expect(_language(await before), 'before');
    expect(_language(await after), 'after');

    inner.hold = false;
    expect(_language(await cache.providerMeta(_sales)), 'after');
  });

  test('the only answer in flight across an invalidation is not stored, so the next read sends a request', () async {
    inner.hold = true;
    final before = cache.providerMeta(_sales);

    cache.invalidate(_sales);
    inner.answer(Success(_meta('before')));
    await before;

    inner.hold = false;
    expect(_language(await cache.providerMeta(_sales)), '2');
    expect(inner.calls, hasLength(2));
  });

  test('the only answer in flight across a clear is not stored, so the next read sends a request', () async {
    inner.hold = true;
    final before = cache.providerMeta(_sales);

    cache.clear();
    inner.answer(Success(_meta('before')));
    await before;

    inner.hold = false;
    expect(_language(await cache.providerMeta(_sales)), '2');
    expect(inner.calls, hasLength(2));
  });

  group('the session end', () {
    test('clears every entry', () async {
      await cache.providerMeta(_sales);
      await cache.providerMeta(_crm);

      await SessionGeneration.wipe(() async {});
      cache.clear();

      expect(cache.entryCount, 0);
      await cache.providerMeta(_sales);
      expect(inner.calls, [_sales, _crm, _sales]);
    });

    test('a wiped session serves no entry stored under it, even before the clear runs', () async {
      await cache.providerMeta(_sales);

      await SessionGeneration.wipe(() async {});

      await cache.providerMeta(_sales);
      expect(inner.calls, hasLength(2));
    });

    test('an answer in flight across it is not stored, and a caller after it gets its own request', () async {
      inner.hold = true;
      final before = cache.providerMeta(_sales);

      await SessionGeneration.wipe(() async {});
      cache.clear();
      final after = cache.providerMeta(_sales);
      expect(inner.calls, hasLength(2));

      inner.answer(Success(_meta('previous user')));
      expect(_language(await before), 'previous user');
      expect(cache.entryCount, 0);

      inner.answer(Success(_meta('next user')));
      expect(_language(await after), 'next user');
      inner.hold = false;
      expect(_language(await cache.providerMeta(_sales)), 'next user');
    });
  });
}
