import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/application/key_browser_bloc.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../browse_answers.dart';

KeyScanPage _page(String name) =>
    ObjectBrowserJson.keyScanPage(File('test/fixtures/studio/$name.json').readAsStringSync());

const _redis = 'seed:dev-redis';

void main() {
  late MockIObjectBrowserRepository repository;
  late MockIProviderMetaRepository providerMeta;

  /// The named arguments of each scanKeys call, leaving out the ones not sent.
  late List<Map<String, Object?>> requests;

  setUp(() {
    repository = MockIObjectBrowserRepository();
    providerMeta = MockIProviderMetaRepository();
    requests = [];
  });

  void answerMeta(ProviderMeta meta) =>
      when(() => providerMeta.providerMeta(any())).thenAnswer((_) async => Success(meta));

  void answerPages(FutureOr<Result<KeyScanPage>> Function(Map<String, Object?> request) answer) =>
      when(
        () => repository.scanKeys(
          any(),
          cursor: any(named: 'cursor'),
          pattern: any(named: 'pattern'),
          count: any(named: 'count'),
          database: any(named: 'database'),
          level: any(named: 'level'),
        ),
      ).thenAnswer((invocation) async {
        final request = <String, Object?>{
          'cursor': invocation.namedArguments[#cursor],
          'pattern': invocation.namedArguments[#pattern],
          'count': invocation.namedArguments[#count],
          'database': invocation.namedArguments[#database],
          if (invocation.namedArguments[#level] == true) 'level': true,
        }..removeWhere((key, value) => value == null);
        requests.add(request);
        return answer(request);
      });

  KeyBrowserBloc build({List<String> container = const [], String? prefix}) {
    final bloc = KeyBrowserBloc(
      repository: repository,
      providerMeta: providerMeta,
      connectionId: _redis,
      container: container,
      prefix: prefix,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// Adds [event] and waits until the bloc is idle again, with no page in flight.
  Future<KeyBrowserState> settle(KeyBrowserBloc bloc, KeyBrowserEvent event) async {
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        KeyBrowserLoaded(:final load) => load == KeyPageLoad.idle,
        KeyBrowserFailure() || KeyBrowserUnavailable() => true,
        KeyBrowserLoading() => false,
      },
    );
    bloc.add(event);
    return done;
  }

  /// [count] distinct keys starting at [from], and the cursor [next].
  KeyScanPage keysPage(int from, int count, {String next = '1'}) => KeyScanPage(
    keys: [for (var i = from; i < from + count; i++) 'k:$i'],
    cursor: next,
    types: const {},
    total: 50000,
  );

  group('Redis, the default shape', () {
    setUp(() => answerMeta(metaAnswer('meta_redis')));

    test('user:* on db1 pages by the cursor of the page before until it returns to 0', () async {
      answerPages(
        (request) => Success(switch ((request['pattern'], request['cursor'])) {
          ('*', null) => keysPage(0, 3, next: '0'),
          ('user:*', null) => _page('keyscan_first'),
          ('user:*', '1622') => _page('keyscan_next'),
          ('user:*', '1483') => _page('keyscan_last'),
          _ => throw StateError('unexpected request $request'),
        }),
      );
      final bloc = build(container: const ['1']);

      final opened = await settle(bloc, const KeyBrowserStarted()) as KeyBrowserLoaded;
      expect(opened.pattern, '*');

      await settle(bloc, const KeyBrowserPatternSubmitted('user:*'));
      await settle(bloc, const KeyBrowserMoreRequested());
      final last = await settle(bloc, const KeyBrowserMoreRequested()) as KeyBrowserLoaded;

      expect(requests, [
        {'pattern': '*', 'database': 1},
        {'pattern': 'user:*', 'database': 1},
        {'cursor': '1622', 'pattern': 'user:*', 'database': 1},
        {'cursor': '1483', 'pattern': 'user:*', 'database': 1},
      ]);
      expect(last.hasMore, isFalse);
      expect(last.keys, hasLength(1203));
      expect(last.scanned, 1203);
      expect(last.total, 1207);
      expect(last.clustered, isFalse);
      expect(last.types['user:2:roles'], 'set');
    });

    test('the pattern starts at * and an emptied glob is left out of the request', () async {
      answerPages((_) => Success(keysPage(0, 1, next: '0')));
      final bloc = build(container: const ['0']);

      await settle(bloc, const KeyBrowserStarted());
      await settle(bloc, const KeyBrowserPatternSubmitted(''));

      expect(requests, [
        {'pattern': '*', 'database': 0},
        {'database': 0},
      ]);
    });

    test('sends database only for a container named by digits', () async {
      answerPages((_) => Success(keysPage(0, 1, next: '0')));

      await settle(build(container: const ['12']), const KeyBrowserStarted());
      await settle(build(container: const ['db0']), const KeyBrowserStarted());
      await settle(build(container: const ['1a']), const KeyBrowserStarted());
      await settle(build(), const KeyBrowserStarted());

      expect(requests.map((r) => r['database']), [12, null, null, null]);
    });

    test('keeps a key once when a page repeats it, and counts every key it was handed', () async {
      var calls = 0;
      answerPages(
        (_) => Success(
          calls++ == 0
              ? const KeyScanPage(keys: ['a', 'b'], cursor: '5', types: {'a': 'string'}, total: 9)
              : const KeyScanPage(keys: ['b', 'c'], cursor: '0', types: {'c': 'hash'}, total: 9),
        ),
      );
      final bloc = build(container: const ['0']);

      await settle(bloc, const KeyBrowserStarted());
      final state = await settle(bloc, const KeyBrowserMoreRequested()) as KeyBrowserLoaded;

      expect(state.keys, ['a', 'b', 'c']);
      expect(state.scanned, 4);
      expect(state.types, {'a': 'string', 'c': 'hash'});
    });

    test('a page from one node of a cluster says so', () async {
      final clustered = ObjectBrowserJson.keyScanPage(
        File('test/fixtures/studio/handwritten/redis/keyscan_clustered.json').readAsStringSync(),
      );
      answerPages((_) => Success(clustered));

      final state = await settle(build(container: const ['0']), const KeyBrowserStarted()) as KeyBrowserLoaded;

      expect(state.clustered, isTrue);
      expect(state.total, 2093);
    });
  });

  test('takes clustered from each page, so a page that says nothing clears it', () async {
    answerMeta(metaAnswer('meta_redis'));
    var calls = 0;
    answerPages(
      (_) => Success(
        calls++ == 0
            ? const KeyScanPage(keys: ['a'], cursor: '5', types: {}, total: 9, clustered: true)
            : const KeyScanPage(keys: ['b'], cursor: '0', types: {}, total: 9),
      ),
    );
    final bloc = build(container: const ['0']);

    final first = await settle(bloc, const KeyBrowserStarted()) as KeyBrowserLoaded;
    final second = await settle(bloc, const KeyBrowserMoreRequested()) as KeyBrowserLoaded;

    expect(first.clustered, isTrue);
    expect(second.clustered, isNull);
  });

  group('etcd, a counted prefix walk', () {
    setUp(() => answerMeta(metaAnswer('handwritten/etcd/meta')));

    test('the pattern starts empty and is left out, then sent as typed with no star', () async {
      answerPages((_) => Success(keysPage(0, 1, next: '0')));
      final bloc = build();

      final opened = await settle(bloc, const KeyBrowserStarted()) as KeyBrowserLoaded;
      await settle(bloc, const KeyBrowserPatternSubmitted('/apisix/routes'));
      await settle(bloc, const KeyBrowserPatternSubmitted(' a/'));

      expect(opened.pattern, '');
      expect(requests, [
        const <String, Object?>{},
        {'pattern': '/apisix/routes'},
        {'pattern': ' a/'},
      ]);
    });

    test('hands the opaque cursor back exactly and takes each page\'s total as the walk\'s count', () async {
      const opaque = 'k:L2E:42:7:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      answerPages(
        (request) => Success(
          request['cursor'] == null
              ? const KeyScanPage(keys: ['/a/1'], cursor: opaque, types: {}, total: 7)
              : const KeyScanPage(keys: ['/a/2'], cursor: '0', types: {}, total: 6),
        ),
      );
      final bloc = build();

      final first = await settle(bloc, const KeyBrowserStarted()) as KeyBrowserLoaded;
      final last = await settle(bloc, const KeyBrowserMoreRequested()) as KeyBrowserLoaded;

      expect(requests.last, {'cursor': opaque});
      expect(first.total, 7);
      expect(last.total, 6);
    });

    test('adds up the keys each page left out', () async {
      var calls = 0;
      answerPages(
        (_) => Success(
          KeyScanPage(
            keys: const ['/a'],
            cursor: calls++ == 0 ? 'k:x' : '0',
            types: const {},
            total: 3,
            skipped: KeyScanSkipped(count: calls, reason: 'they are not UTF-8 text'),
          ),
        ),
      );
      final bloc = build();

      await settle(bloc, const KeyBrowserStarted());
      final state = await settle(bloc, const KeyBrowserMoreRequested()) as KeyBrowserLoaded;

      expect(state.skipped, const KeyScanSkipped(count: 3, reason: 'they are not UTF-8 text'));
    });
  });

  group('a walk with no total', () {
    test('reads no total under totalScope none', () async {
      answerMeta(
        const ProviderMeta(
          queryLanguage: 'mqtt',
          schemaRefreshPattern: 'x',
          containerLevels: [],
          objectKinds: [],
          keyScan: KeyScanSpec(defaultCount: 100, maxCount: 500, pattern: 'prefix', totalScope: 'none'),
        ),
      );
      answerPages((_) => Success(keysPage(0, 2, next: '0')));

      final state = await settle(build(), const KeyBrowserStarted()) as KeyBrowserLoaded;

      expect(state.total, isNull);
    });
  });

  group('Firestore, level pages', () {
    setUp(() => answerMeta(metaAnswer('handwritten/firestore/meta')));

    KeyScanPage level() => ObjectBrowserJson.keyScanPage(
      File('test/fixtures/studio/handwritten/firestore/keyscan_level.json').readAsStringSync(),
    );

    test('the root asks for its level with no pattern and no database, and its folders come from prefixes', () async {
      answerPages((_) => Success(level()));

      final state = await settle(build(), const KeyBrowserStarted()) as KeyBrowserLoaded;

      expect(requests, [
        {'level': true},
      ]);
      expect(state.folders, ['audit_log/', 'carts/', 'coupons/']);
      expect(state.keys, isEmpty);
      expect(state.skipped?.count, 1);
      expect(state.readOutcome?.isIncomplete, isTrue);
      expect(state.total, isNull);
      expect(state.hasMore, isTrue);
    });

    test('a folder asks for its own level with its prefix as the pattern, and a typed id narrows it', () async {
      answerPages((_) => Success(keysPage(0, 1, next: '0')));
      final bloc = build(prefix: 'users/');

      await settle(bloc, const KeyBrowserStarted());
      await settle(bloc, const KeyBrowserPatternSubmitted('al'));

      expect(requests, [
        {'pattern': 'users/', 'level': true},
        {'pattern': 'users/al', 'level': true},
      ]);
    });

    test('the next page of a level sends the opaque cursor with the same pattern and level', () async {
      answerPages((request) => Success(request['cursor'] == null ? level() : keysPage(0, 0, next: '0')));
      final bloc = build();

      await settle(bloc, const KeyBrowserStarted());
      await settle(bloc, const KeyBrowserMoreRequested());

      expect(requests.last, {'cursor': level().cursor, 'level': true});
    });
  });

  group('Load all', () {
    setUp(() => answerMeta(metaAnswer('meta_redis')));

    test('stops at 10,000 held keys, and Load more is not sent past it', () async {
      answerPages((_) => Success(keysPage(requests.length * 1000, 1000)));
      final bloc = build(container: const ['0']);

      await settle(bloc, const KeyBrowserStarted());
      final state = await settle(bloc, const KeyBrowserAllRequested()) as KeyBrowserLoaded;

      expect(requests, hasLength(10));
      expect(state.keys, hasLength(KeyBrowserBloc.heldKeyLimit));
      expect(state.atCap, isTrue);
      expect(state.hasMore, isTrue);

      bloc.add(const KeyBrowserMoreRequested());
      bloc.add(const KeyBrowserAllRequested());
      await pumpEventQueue();
      expect(requests, hasLength(10));
    });

    test('trims the page that crosses the limit to exactly 10,000 held keys, keeping the first it names', () async {
      answerPages((_) => Success(keysPage(requests.length * 1500, 1500)));
      final bloc = build(container: const ['0']);

      await settle(bloc, const KeyBrowserStarted());
      final state = await settle(bloc, const KeyBrowserAllRequested()) as KeyBrowserLoaded;

      expect(requests, hasLength(7));
      expect(state.keys, hasLength(KeyBrowserBloc.heldKeyLimit));
      expect(state.keys.last, 'k:${1500 + KeyBrowserBloc.heldKeyLimit - 1}');
      expect(state.atCap, isTrue);
    });

    test('a level page that crosses the limit keeps its folders first, then its keys, up to 10,000 entries', () async {
      answerMeta(metaAnswer('handwritten/firestore/meta'));
      answerPages(
        (_) => Success(
          KeyScanPage(
            keys: [for (var i = 0; i < 600; i++) 'k$i'],
            prefixes: [for (var i = 0; i < 9600; i++) 'f$i/'],
            cursor: 'next',
            types: const {},
            total: 0,
          ),
        ),
      );

      final state = await settle(build(), const KeyBrowserStarted()) as KeyBrowserLoaded;

      expect(state.folders, hasLength(9600));
      expect(state.keys, hasLength(400));
      expect(state.held, KeyBrowserBloc.heldKeyLimit);
    });

    test('ends when the cursor returns to 0, reporting its progress after each page', () async {
      answerPages((_) => Success(keysPage(requests.length * 10, 10, next: requests.length == 3 ? '0' : '9')));
      final bloc = build(container: const ['0']);
      await settle(bloc, const KeyBrowserStarted());
      final progress = <int>[];
      final sub = bloc.stream.listen((s) {
        if (s case KeyBrowserLoaded(load: KeyPageLoad.all, :final keys)) progress.add(keys.length);
      });

      final state = await settle(bloc, const KeyBrowserAllRequested()) as KeyBrowserLoaded;
      await sub.cancel();

      expect(requests, hasLength(3));
      expect(state.hasMore, isFalse);
      expect(progress, [10, 20, 30]);
    });

    test('Stop takes effect after the page in flight, whose keys are kept', () async {
      final inFlight = Completer<Result<KeyScanPage>>();
      answerPages((_) => requests.length == 2 ? inFlight.future : Success(keysPage(requests.length * 10, 10)));
      final bloc = build(container: const ['0']);
      await settle(bloc, const KeyBrowserStarted());

      final done = settle(bloc, const KeyBrowserAllRequested());
      await pumpEventQueue();
      expect(requests, hasLength(2));
      bloc.add(const KeyBrowserStopped());
      await pumpEventQueue();
      expect(bloc.state, isA<KeyBrowserLoaded>().having((s) => s.stopping, 'stopping', isTrue));

      inFlight.complete(Success(keysPage(100, 10)));
      final state = await done as KeyBrowserLoaded;

      expect(requests, hasLength(2));
      expect(state.keys, hasLength(20));
      expect(state.stopping, isFalse);
      expect(state.hasMore, isTrue);
    });
  });

  group('droppable page loads', () {
    setUp(() => answerMeta(metaAnswer('meta_redis')));

    test('a second Load more while a page is in flight is ignored', () async {
      final inFlight = Completer<Result<KeyScanPage>>();
      answerPages((_) => requests.length == 2 ? inFlight.future : Success(keysPage(0, 10)));
      final bloc = build(container: const ['0']);
      await settle(bloc, const KeyBrowserStarted());

      final done = settle(bloc, const KeyBrowserMoreRequested());
      await pumpEventQueue();
      bloc.add(const KeyBrowserMoreRequested());
      bloc.add(const KeyBrowserAllRequested());
      bloc.add(const KeyBrowserPatternSubmitted('x*'));
      await pumpEventQueue();
      inFlight.complete(Success(keysPage(10, 10)));
      await done;
      await pumpEventQueue();

      expect(requests, hasLength(2));
    });
  });

  group('failure', () {
    test('a provider-meta failure leaves nothing on screen, and a retry starts again', () async {
      when(() => providerMeta.providerMeta(any()))
          .thenAnswer((_) async => const Failure(NetworkError('down', code: 'network.offline')));
      final bloc = build();

      final state = await settle(bloc, const KeyBrowserStarted());

      expect(state, isA<KeyBrowserFailure>().having((s) => s.previous, 'previous', isNull));

      answerMeta(metaAnswer('meta_redis'));
      answerPages((_) => Success(keysPage(0, 1, next: '0')));
      expect(await settle(bloc, const KeyBrowserMoreRequested()), isA<KeyBrowserLoaded>());
      expect(requests, [
        {'pattern': '*'},
      ]);
    });

    test('a failed later page keeps the keys under the error, and Load more resumes from the same cursor', () async {
      answerMeta(metaAnswer('meta_redis'));
      var fail = false;
      answerPages((request) {
        if (fail) return const Failure(ServerError('audit', code: 'studio.governance_unavailable'));
        return Success(keysPage(0, 5, next: '77'));
      });
      final bloc = build(container: const ['0']);
      await settle(bloc, const KeyBrowserStarted());

      fail = true;
      final failed = await settle(bloc, const KeyBrowserMoreRequested());
      expect(
        failed,
        isA<KeyBrowserFailure>()
            .having((s) => s.error.code, 'code', 'studio.governance_unavailable')
            .having((s) => s.previous?.keys, 'previous keys', hasLength(5))
            .having((s) => s.previous?.load, 'load', KeyPageLoad.idle),
      );

      fail = false;
      final resumed = await settle(bloc, const KeyBrowserMoreRequested());
      expect(requests.last, {'cursor': '77', 'pattern': '*', 'database': 0});
      expect(resumed, isA<KeyBrowserLoaded>());
    });

    test('an engine that declares no key walk is unavailable and sends no page', () async {
      answerMeta(metaAnswer('meta_postgres'));

      final state = await settle(build(container: const ['public']), const KeyBrowserStarted());

      expect(state, isA<KeyBrowserUnavailable>());
      expect(requests, isEmpty);
    });
  });
}
