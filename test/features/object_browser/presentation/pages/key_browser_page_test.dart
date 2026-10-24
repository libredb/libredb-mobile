@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/key_value_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_source_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/key_browser_list.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

const _redis = StudioConnection(id: 'seed:dev-redis', name: 'Dev Redis', type: 'redis');
const _etcd = 'seed:etcd';
const _firestore = 'seed:firestore';
const _mqtt = 'seed:mqtt';

KeyScanPage _page(String name) =>
    ObjectBrowserJson.keyScanPage(File('test/fixtures/studio/$name.json').readAsStringSync());

void main() {
  late BrowseHarness harness;

  /// The named arguments of each scanKeys call, leaving out the ones not sent.
  late List<Map<String, Object?>> requests;

  setUp(() {
    harness = BrowseHarness();
    requests = [];
  });

  void answerPages(FutureOr<Result<KeyScanPage>> Function(Map<String, Object?> request) answer) =>
      when(
        () => harness.repository.scanKeys(
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
          'database': invocation.namedArguments[#database],
          if (invocation.namedArguments[#level] == true) 'level': true,
        }..removeWhere((key, value) => value == null);
        requests.add(request);
        return answer(request);
      });

  /// The recorded user:* walk of db1, and the same first page for the default `*`.
  void answerRedisWalk() => answerPages(
    (request) => Success(switch (request['cursor']) {
      null => _page('keyscan_first'),
      '1622' => _page('keyscan_next'),
      _ => _page('keyscan_last'),
    }),
  );

  String progress(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('key-progress'))).data!;

  group('kind screen', () {
    testWidgets('offers Browse keys on an engine that declares keyScan, opening the database it was tapped in', (
      tester,
    ) async {
      harness.answerMeta(_redis.id, metaAnswer('meta_redis'));
      harness.answerContainers(_redis.id, null, containersAnswer('containers_redis'));
      harness.answerCounts(_redis.id, ['1'], countsAnswer('counts_redis'));
      answerRedisWalk();
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/kinds?container=1');

      await tester.tap(find.text(S.current.keys_browse));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Adev-redis/keys?container=1');
      expect(requests.first, {'pattern': '*', 'database': 1});
    });

    testWidgets('names no container on an engine with no container level', (tester) async {
      harness.answerMeta(_firestore, metaAnswer('handwritten/firestore/meta'));
      harness.answerCounts(_firestore, const [], const {'collection': KindCounted(4)});
      answerPages((_) => Success(_page('handwritten/firestore/keyscan_level')));
      await harness.pump(tester, location: '/browse/seed%3Afirestore/kinds');

      await tester.tap(find.text(S.current.keys_browse));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Afirestore/keys');
    });

    testWidgets('has no Browse keys row on an engine without a key walk', (tester) async {
      harness.answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      harness.answerContainers('seed:dev-postgres', null, containersAnswer('containers_postgres'));
      harness.answerCounts('seed:dev-postgres', ['public'], countsAnswer('counts_postgres'));
      await harness.pump(tester, location: '/browse/seed%3Adev-postgres/kinds?container=public');

      expect(find.text('Tables'), findsOneWidget);
      expect(find.text(S.current.keys_browse), findsNothing);
    });
  });

  group('Redis', () {
    setUp(() {
      harness.answerMeta(_redis.id, metaAnswer('meta_redis'));
      when(
        () => harness.statements.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          database: any(named: 'database'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer(
        (_) async =>
            Success(QueryResultJson.read(File('test/fixtures/studio/query_redis_set.json').readAsStringSync())),
      );
    });

    for (final (name, size, beside) in const [
      ('beside the progress line on a phone held sideways', Size(829, 393), true),
      ('under the progress line in portrait', Size(393, 829), false),
    ]) {
      testWidgets('puts Load more and Load all $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        answerRedisWalk();
        await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=1');

        final progressLine = tester.getRect(find.byKey(const ValueKey('key-progress')));
        for (final label in [S.current.keys_load_more, S.current.keys_load_all]) {
          final button = tester.getRect(find.widgetWithText(OutlinedButton, label));
          expect(button.top < progressLine.bottom, beside, reason: label);
        }
      });
    }

    testWidgets('user:* on db1 pages with Load more and groups its keys into folders with counts and type chips', (
      tester,
    ) async {
      answerRedisWalk();
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=1');

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '*');
      await tester.enterText(find.byType(TextField), 'user:*');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(progress(tester), 'Found 499 matching keys; the database holds 1,207; more remain');

      await tester.tap(find.text(S.current.keys_load_more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.keys_load_more));
      await tester.pumpAndSettle();

      expect(requests.skip(1), [
        {'pattern': 'user:*', 'database': 1},
        {'cursor': '1622', 'pattern': 'user:*', 'database': 1},
        {'cursor': '1483', 'pattern': 'user:*', 'database': 1},
      ]);
      expect(progress(tester), 'Found 1,203 matching keys; the database holds 1,207');
      expect(find.text(S.current.keys_load_more), findsNothing, reason: 'the cursor returned to 0');
      final folder = find.widgetWithText(ListTile, 'user:');
      expect(find.descendant(of: folder, matching: find.text('1,203')), findsOneWidget);

      await tester.tap(folder);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '2:'));
      await tester.pumpAndSettle();
      final roles = find.widgetWithText(ListTile, 'roles');
      expect(find.descendant(of: roles, matching: find.widgetWithText(KeyTypeChip, 'set')), findsOneWidget);

      await tester.tap(roles);
      await tester.pumpAndSettle();

      expect(find.byType(KeyValuePage), findsOneWidget);
      expect(harness.location, '/browse/seed%3Adev-redis/value?container=1&path=user%3A2%3Aroles&type=set');
    });

    for (final (locale, found, folderCount) in [
      (const Locale('en'), 'Found 1,203 matching keys; the database holds 1,207', '1,203'),
      (const Locale('tr'), 'Eşleşen 1.203 anahtar bulundu; veritabanında 1.207 anahtar var', '1.203'),
    ]) {
      testWidgets('a finished user:* walk says the keys it found, not scanned, grouped in the locale ($locale)', (
        tester,
      ) async {
        answerRedisWalk();
        await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=1', locale: locale);

        await tester.enterText(find.byType(TextField), 'user:*');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        for (var page = 0; page < 2; page++) {
          await tester.tap(find.text(S.current.keys_load_more));
          await tester.pumpAndSettle();
        }

        expect(progress(tester), found);
        final folder = find.widgetWithText(ListTile, 'user:');
        expect(find.descendant(of: folder, matching: find.text(folderCount)), findsOneWidget);
      });
    }

    testWidgets('a key of a level page opens with its whole key, not the label its row shows', (tester) async {
      answerPages(
        (_) => const Success(
          KeyScanPage(keys: ['cache:greeting'], cursor: '0', types: {'cache:greeting': 'string'}, total: 1),
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0');

      await tester.tap(find.widgetWithText(ListTile, 'cache:'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'greeting'));
      await tester.pumpAndSettle();

      final value = tester.widget<KeyValuePage>(find.byType(KeyValuePage));
      expect(value.keyName, 'cache:greeting');
      expect(value.container, ['0']);
      expect(value.type, 'string');
    });

    testWidgets('a key without a type opens with no type', (tester) async {
      answerPages((_) => const Success(KeyScanPage(keys: ['plain'], cursor: '0', types: {}, total: 1)));
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0');

      await tester.tap(find.widgetWithText(ListTile, 'plain'));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Adev-redis/value?container=0&path=plain');
    });

    testWidgets('says the counts are one node\'s on a clustered server', (tester) async {
      final clustered = ObjectBrowserJson.keyScanPage(
        File('test/fixtures/studio/handwritten/redis/keyscan_clustered.json').readAsStringSync(),
      );
      answerPages((_) => Success(clustered));
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0');

      expect(progress(tester), 'Scanned 4 of the 2,093 keys this database holds; more remain');
      expect(find.text(S.current.keys_clustered), findsOneWidget);
    });

    testWidgets('keeps the limit notice when the trim cuts the last page, and caps the scanned count shown', (
      tester,
    ) async {
      answerPages(
        (_) => Success(
          KeyScanPage(keys: [for (var i = 0; i < 10500; i++) 'k:$i'], cursor: '0', types: const {}, total: 12000),
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0');

      expect(find.text(S.current.keys_cap), findsOneWidget);
      expect(progress(tester), 'Scanned 10,000 of the 12,000 keys this database holds');
      expect(find.text(S.current.keys_load_more), findsNothing);
    });

    testWidgets('Load all shows its progress and a Stop that waits for the page in flight', (tester) async {
      final inFlight = Completer<Result<KeyScanPage>>();
      answerPages(
        (_) => requests.length == 2
            ? inFlight.future
            : const Success(KeyScanPage(keys: ['a:1'], cursor: '5', types: {}, total: 3)),
      );
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0');

      await tester.tap(find.text(S.current.keys_load_all));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text(S.current.keys_stop));
      await tester.pump();
      expect(find.text(S.current.keys_stopping), findsOneWidget);

      inFlight.complete(const Success(KeyScanPage(keys: ['a:2'], cursor: '6', types: {}, total: 3)));
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(S.current.keys_load_more), findsOneWidget);
    });

    testWidgets('shows a failed page in the Browse failure view, over the keys it already holds', (tester) async {
      answerPages(
        (request) => request['cursor'] == null
            ? Success(_page('keyscan_first'))
            : const Failure(ServerError('audit', code: 'studio.governance_unavailable')),
      );
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=1');

      await tester.tap(find.text(S.current.keys_load_more));
      await tester.pumpAndSettle();

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'user:'), findsOneWidget);
    });
  });

  group('etcd', () {
    setUp(() => harness.answerMeta(_etcd, metaAnswer('handwritten/etcd/meta')));

    testWidgets('the pattern starts empty and never gains a star, and the header shows the walk\'s count', (
      tester,
    ) async {
      answerPages((_) => const Success(KeyScanPage(keys: ['/apisix/routes/1'], cursor: '0', types: {}, total: 1)));
      await harness.pump(tester, location: '/browse/seed%3Aetcd/keys');

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.text(S.current.keys_pattern_prefix), findsOneWidget);
      expect(progress(tester), 'Scanned 1 of the 1 keys this walk covers');

      await tester.enterText(find.byType(TextField), '/apisix/routes');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(requests, [
        const <String, Object?>{},
        {'pattern': '/apisix/routes'},
      ]);
      expect(progress(tester), 'Found 1 of the 1 keys this walk covers');
      expect(find.widgetWithText(ListTile, '/'), findsOneWidget, reason: 'grouped by the declared separator');
    });

    testWidgets('a key opens the key kind\'s source for the path [key] and runs no statement', (tester) async {
      when(() => harness.repository.source(_etcd, path: const ['/apisix/routes/1'], kind: 'key'))
          .thenAnswer((_) async => const Failure(NotFoundError('gone', code: 'studio.object_not_found')));
      answerPages((_) => const Success(KeyScanPage(keys: ['/apisix/routes/1'], cursor: '0', types: {}, total: 1)));
      await harness.pump(tester, location: '/browse/seed%3Aetcd/keys');

      await tester.tap(find.widgetWithText(ListTile, '/'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'apisix/'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'routes/'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(ListTile, Icons.key_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ObjectSourcePage), findsOneWidget);
      expect(harness.router.state.pathParameters['kind'], 'key');
      expect(harness.router.state.uri.queryParametersAll['path'], ['/apisix/routes/1']);
      verify(() => harness.repository.source(_etcd, path: const ['/apisix/routes/1'], kind: 'key')).called(1);
      verifyNever(
        () => harness.statements.run(
          any(),
          any(),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      );
    });
  });

  testWidgets('draws each proven loss in the warning style, under the plain read outcome', (tester) async {
    harness.answerMeta(_firestore, metaAnswer('handwritten/firestore/meta'));
    answerPages(
      (_) => const Success(
        KeyScanPage(
          keys: [],
          cursor: '0',
          types: {},
          total: 0,
          prefixes: ['a/'],
          readOutcome: KeyReadOutcome(scope: 'incomplete', endReason: 'the server closed', provenLoss: ['one lost']),
        ),
      ),
    );
    await harness.pump(tester, location: '/browse/seed%3Afirestore/keys');

    final theme = Theme.of(tester.element(find.byType(ListView).last));
    final outcome = tester.widget<Text>(find.text(S.current.keys_read_incomplete('the server closed')));
    expect(outcome.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(tester.widget<Text>(find.text('one lost')).style?.color, theme.colorScheme.error);
  });

  testWidgets('shows no total under totalScope none', (tester) async {
    harness.answerMeta(
      _mqtt,
      const ProviderMeta(
        queryLanguage: 'mqtt',
        schemaRefreshPattern: 'x',
        containerLevels: [],
        objectKinds: [],
        keyScan: KeyScanSpec(defaultCount: 100, maxCount: 500, separator: '/', pattern: 'prefix', totalScope: 'none'),
      ),
    );
    answerPages((_) => const Success(KeyScanPage(keys: ['a/b', 'a/c'], cursor: '0', types: {}, total: 0)));
    await harness.pump(tester, location: '/browse/seed%3Amqtt/keys');

    expect(progress(tester), 'Scanned 2 keys');
    await tester.enterText(find.byType(TextField), 'a/');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(progress(tester), 'Found 2 matching keys');
    await tester.tap(find.widgetWithText(ListTile, 'a/'));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'b')).onTap, isNull, reason: 'no key kind, not Redis');
  });

  group('Turkish grouping', () {
    const tr = Locale('tr');
    final many = [for (var i = 0; i < 1500; i++) 'k$i'];

    testWidgets('the scanned line and the database total', (tester) async {
      harness.answerMeta(_redis.id, metaAnswer('meta_redis'));
      answerPages((_) => Success(KeyScanPage(keys: many, cursor: '0', types: const {}, total: 12000)));
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0', locale: tr);

      expect(progress(tester), 'Bu veritabanının tuttuğu 12.000 anahtardan 1.500 tanesi tarandı');
    });

    testWidgets('the scanned line without a total, the keys left out and a folder count', (tester) async {
      harness.answerMeta(
        _mqtt,
        const ProviderMeta(
          queryLanguage: 'mqtt',
          schemaRefreshPattern: 'x',
          containerLevels: [],
          objectKinds: [],
          keyScan: KeyScanSpec(defaultCount: 100, maxCount: 500, separator: '/', pattern: 'prefix', totalScope: 'none'),
        ),
      );
      answerPages(
        (_) => Success(
          KeyScanPage(
            keys: [for (final key in many) 'a/$key'],
            cursor: '0',
            types: const {},
            total: 0,
            skipped: const KeyScanSkipped(count: 2500, reason: 'r'),
          ),
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Amqtt/keys', locale: tr);

      expect(progress(tester), '1.500 anahtar tarandı');
      expect(find.text('Bu taramada 2.500 anahtar dışarıda kaldı: r'), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(ListTile, 'a/'), matching: find.text('1.500')), findsOneWidget);
    });

    testWidgets('the listed line of a level page', (tester) async {
      harness.answerMeta(_firestore, metaAnswer('handwritten/firestore/meta'));
      answerPages((_) => Success(KeyScanPage(keys: many, prefixes: const [], cursor: '0', types: const {}, total: 0)));
      await harness.pump(tester, location: '/browse/seed%3Afirestore/keys', locale: tr);

      expect(progress(tester), '1.500 öğe listelendi');
    });
  });

  group('Firestore level pages', () {
    setUp(() => harness.answerMeta(_firestore, metaAnswer('handwritten/firestore/meta')));

    testWidgets('shows the folders from prefixes, the keys left out and the read outcome in Studio\'s words', (
      tester,
    ) async {
      answerPages((_) => Success(_page('handwritten/firestore/keyscan_level')));
      await harness.pump(tester, location: '/browse/seed%3Afirestore/keys');

      expect(progress(tester), 'Listed 3 entries; more remain');
      for (final folder in ['audit_log/', 'carts/', 'coupons/']) {
        expect(find.widgetWithText(ListTile, folder), findsOneWidget);
      }
      expect(
        find.text(
          S.current.keys_skipped(
            1,
            '1',
            "Ids that break Firestore's id rules cannot be shown or opened, so they are counted here and not listed.",
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          S.current.keys_read_incomplete(
            'Studio stops after 10 id listing requests at one level, so ids past the ones those requests returned '
            'are not listed.',
          ),
        ),
        findsOneWidget,
      );
      final outcome = tester.widget<Text>(find.textContaining(S.current.keys_read_incomplete('')));
      final theme = Theme.of(tester.element(find.byType(ListView).last));
      expect(outcome.style?.color, theme.colorScheme.onSurfaceVariant, reason: 'a plain line, as Studio draws it');
    });

    testWidgets('a folder opens its own level as a page, asked with level true, its prefix and no database', (
      tester,
    ) async {
      answerPages(
        (request) => Success(
          request['pattern'] == 'carts/'
              ? const KeyScanPage(keys: ['carts/c1'], cursor: '0', types: {}, total: 0, prefixes: ['carts/c1/'])
              : _page('handwritten/firestore/keyscan_level'),
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Afirestore/keys');

      await tester.tap(find.widgetWithText(ListTile, 'carts/'));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Afirestore/keys?prefix=carts%2F');
      expect(requests.last, {'pattern': 'carts/', 'level': true});
      expect(find.text('carts/'), findsOneWidget, reason: 'the heading names the folder');
      expect(find.widgetWithText(ListTile, 'c1/'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'c1'), findsWidgets);
      expect(progress(tester), 'Listed 2 entries');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Afirestore/keys');
      expect(find.widgetWithText(ListTile, 'audit_log/'), findsOneWidget);
    });

    testWidgets('a document key opens the document kind\'s source and runs no statement', (tester) async {
      when(() => harness.repository.source(_firestore, path: const ['carts/c1'], kind: 'document'))
          .thenAnswer((_) async => Success(sourceAnswer('handwritten/firestore/source_document')));
      answerPages(
        (request) => Success(
          request['pattern'] == 'carts/'
              ? const KeyScanPage(keys: ['carts/c1'], cursor: '0', types: {}, total: 0, prefixes: [])
              : _page('handwritten/firestore/keyscan_level'),
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Afirestore/keys?prefix=carts%2F');

      await tester.tap(find.widgetWithText(ListTile, 'c1'));
      await tester.pumpAndSettle();

      expect(find.byType(ObjectSourcePage), findsOneWidget);
      expect(harness.router.state.uri.queryParametersAll['path'], ['carts/c1']);
      verify(() => harness.repository.source(_firestore, path: const ['carts/c1'], kind: 'document')).called(1);
      verifyNever(
        () => harness.statements.run(
          any(),
          any(),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      );
    });

    testWidgets('a folder page opened by a link goes back to the Browse root', (tester) async {
      answerPages((_) => const Success(KeyScanPage(keys: [], cursor: '0', types: {}, total: 0, prefixes: [])));
      await harness.pump(tester, location: '/browse/seed%3Afirestore/keys?prefix=carts%2F');
      expect(requests.single, {'pattern': 'carts/', 'level': true});
      expect(find.text(S.current.keys_empty), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse');
      expect(find.byType(PickConnectionFirst), findsOneWidget, reason: 'the Browse root, with no connection open');
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
