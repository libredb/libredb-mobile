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
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/key_browser_list.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
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
      '406' => _page('keyscan_next'),
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
    setUp(() => harness.answerMeta(_redis.id, metaAnswer('meta_redis')));

    testWidgets('user:* on db1 pages with Load more and groups its keys into folders with counts and type chips', (
      tester,
    ) async {
      answerRedisWalk();
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=1');

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '*');
      await tester.enterText(find.byType(TextField), 'user:*');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(progress(tester), 'Scanned 497 of the 1207 keys this database holds; more remain');

      await tester.tap(find.text(S.current.keys_load_more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.keys_load_more));
      await tester.pumpAndSettle();

      expect(requests.skip(1), [
        {'pattern': 'user:*', 'database': 1},
        {'cursor': '406', 'pattern': 'user:*', 'database': 1},
        {'cursor': '907', 'pattern': 'user:*', 'database': 1},
      ]);
      expect(progress(tester), 'Scanned 1203 of the 1207 keys this database holds');
      expect(find.text(S.current.keys_load_more), findsNothing, reason: 'the cursor returned to 0');
      final folder = find.widgetWithText(ListTile, 'user:');
      expect(find.descendant(of: folder, matching: find.text('1203')), findsOneWidget);

      await tester.tap(folder);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '2:'));
      await tester.pumpAndSettle();
      final roles = find.widgetWithText(ListTile, 'roles');
      expect(find.descendant(of: roles, matching: find.widgetWithText(KeyTypeChip, 'set')), findsOneWidget);
      expect(tester.widget<ListTile>(roles).onTap, isNull, reason: 'a key opens nothing until M4-07');
    });

    testWidgets('says the counts are one node\'s on a clustered server', (tester) async {
      final clustered = ObjectBrowserJson.keyScanPage(
        File('test/fixtures/studio/handwritten/redis/keyscan_clustered.json').readAsStringSync(),
      );
      answerPages((_) => Success(clustered));
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=0');

      expect(progress(tester), 'Scanned 4 of the 2093 keys this database holds; more remain');
      expect(find.text(S.current.keys_clustered), findsOneWidget);
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
      expect(find.widgetWithText(ListTile, '/'), findsOneWidget, reason: 'grouped by the declared separator');
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

    testWidgets('a folder page opened by a link goes back to the Browse root', (tester) async {
      answerPages((_) => const Success(KeyScanPage(keys: [], cursor: '0', types: {}, total: 0, prefixes: [])));
      await harness.pump(tester, location: '/browse/seed%3Afirestore/keys?prefix=carts%2F');
      expect(requests.single, {'pattern': 'carts/', 'level': true});
      expect(find.text(S.current.keys_empty), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // go_router 18.1.1 keeps the popped page's query on the remaining location after a deep link opened with go
      // (decisions.md, rules from #54); /browse reads no query, so it shows the root as ever.
      expect(harness.location, '/browse?prefix=carts%2F');
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
