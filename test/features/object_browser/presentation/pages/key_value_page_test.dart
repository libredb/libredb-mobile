@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/key_value_page.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/utils/sensitive_clipboard.dart';
import 'package:libredb_mobile/shared/widgets/cells/sensitive_selectable_text.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_table.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';
import '../../result_scroll.dart';

const _redis = StudioConnection(id: 'seed:dev-redis', name: 'Dev Redis', type: 'redis');
const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');

QueryResult _recorded(String name) => QueryResultJson.read(File('test/fixtures/studio/$name.json').readAsStringSync());

QueryResult _single(String text, {int rowCount = 1}) => QueryResult(
  fields: const ['result'],
  rows: [
    {'result': text},
  ],
  rowCount: rowCount,
  executionTime: Duration.zero,
);

String _location(String key, {String? type, List<String> container = const ['1'], String id = 'seed:dev-redis'}) => Uri(
  path: '/browse/${Uri.encodeComponent(id)}/value',
  queryParameters: {'container': container, 'path': key, 'type': ?type},
).toString();

void main() {
  late BrowseHarness harness;

  /// The texts the fake platform channel of the sensitive clipboard received, and Flutter's plain clipboard.
  late List<String> copied;
  late List<Object?> plain;

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_redis.id, metaAnswer('meta_redis'));
    harness.answerContainers(_redis.id, null, containersAnswer('containers_redis'));
    harness.answerCounts(_redis.id, ['0'], countsAnswer('counts_redis'));
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
    copied = [];
    plain = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
      copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') plain.add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void answerRun(
    String sql,
    FutureOr<Result<QueryResult>> Function() answer, {
    String connectionId = 'seed:dev-redis',
  }) => when(
    () => harness.statements.run(
      connectionId,
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      database: any(named: 'database'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).thenAnswer((_) async => answer());

  int runsOf(String sql) => verify(
    () => harness.statements.run(
      _redis.id,
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      database: any(named: 'database'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).callCount;

  Finder text() => find.byKey(const ValueKey('key-value-text'));
  Finder readValue() => find.widgetWithText(FilledButton, 'Read value');

  testWidgets('a read refused with the account runs nothing again by itself once Retry clears the refusal', (
    tester,
  ) async {
    answerRun('GET cache:greeting', () => Failure(AuthError('No role', code: AppErrorCode.studioAccountHasNoRole.key)));
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));
    await harness.refuseAccount(tester, AppErrorCode.studioAccountHasNoRole);

    await harness.retryAccepted(tester);

    expect(find.byKey(accountRefusalRetryKey), findsNothing, reason: 'the page is uncovered');
    expect(find.byType(BrowseFailureView), findsOneWidget);
    expect(runsOf('GET cache:greeting'), 1);
  });

  group('each recorded type of database 1', () {
    testWidgets('a string shows its text, read with GET in database 1 as a number', (tester) async {
      answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
      await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

      expect(find.byType(KeyValuePage), findsOneWidget);
      expect(find.text('cache:greeting'), findsOneWidget);
      expect(find.descendant(of: text(), matching: find.text('hello from db1')), findsOneWidget);
      expect(find.byType(ResultView), findsNothing);
      verify(
        () => harness.statements.run(
          _redis.id,
          'GET cache:greeting',
          queryId: any(named: 'queryId', that: isNotEmpty),
          page: QueryPage.first,
          database: 1,
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).called(1);
    });

    testWidgets('the JSON text of user:2:profile is pretty-printed', (tester) async {
      answerRun('GET user:2:profile', () => Success(_recorded('query_redis_json')));
      await harness.pump(tester, location: _location('user:2:profile', type: 'string'));

      const pretty = '{\n  "name": "Grace Hopper",\n  "languages": [\n    "en"\n  ],\n  "active": true\n}';
      expect(find.descendant(of: text(), matching: find.text(pretty)), findsOneWidget);
    });

    for (final (fixture, key, type, command, shown) in [
      ('query_redis_hash', 'user:2', 'hash', 'HGETALL user:2', ['name', 'Grace Hopper', 'plan']),
      ('query_redis_list', 'session:2:events', 'list', 'LRANGE session:2:events 0 -1', ['login', 'run-query']),
      ('query_redis_set', 'user:2:roles', 'set', 'SMEMBERS user:2:roles', ['analyst', 'viewer']),
      ('query_redis_zset', 'cache:leaderboard', 'zset', 'ZRANGE cache:leaderboard 0 -1 WITHSCORES', ['grace', '42']),
      ('query_redis_stream', 'session:2:log', 'stream', 'XRANGE session:2:log - + COUNT 100', ['1700000000000-0']),
    ]) {
      testWidgets('a $type shows in the result view', (tester) async {
        answerRun(command, () => Success(_recorded(fixture)));
        await harness.pump(tester, location: _location(key, type: type));

        expect(find.byType(ResultView), findsOneWidget);
        for (final value in shown) {
          expect(find.textContaining(value), findsWidgets, reason: value);
        }
        expect(runsOf(command), 1);
      });
    }

    testWidgets('a hash field called email shows in clear, as on the web (S-22)', (tester) async {
      answerRun('HGETALL user:2', () => Success(_recorded('query_redis_hash')));
      await harness.pump(tester, location: _location('user:2', type: 'hash'));

      expect(find.textContaining('grace@example.com'), findsWidgets);
    });
  });

  // The read's request is dropped when the page goes, and no /db/cancel is posted (#116).
  testWidgets('leaving the page during a read drops its request and posts no cancel', (tester) async {
    final signals = <CancelSignal?>[];
    when(
      () => harness.statements.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        database: any(named: 'database'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).thenAnswer((invocation) {
      signals.add(invocation.namedArguments[#cancelSignal] as CancelSignal?);
      return Completer<Result<QueryResult>>().future;
    });
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'), settle: false);
    expect(signals.single!.isCancelled, isFalse);

    harness.router.go(ApplicationRoutesConstants.connectionList);
    await tester.pumpAndSettle();

    expect(find.byType(KeyValuePage), findsNothing);
    expect(signals.single!.isCancelled, isTrue);
    verifyNever(() => harness.statements.cancel(any(), any()));
  });

  testWidgets('a stream field named email is masked', (tester) async {
    answerRun(
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
    );
    await harness.pump(tester, location: _location('events', type: 'stream'));

    expect(find.byType(ResultView), findsOneWidget);
    expect(find.textContaining('1700000000000-0'), findsWidgets);
    expect(find.textContaining('grace@example.com'), findsNothing);
  });

  testWidgets('a container that is not all digits sends no database', (tester) async {
    answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
    await harness.pump(
      tester,
      location: _location('cache:greeting', type: 'string', container: const ['db1']),
    );

    verify(
      () => harness.statements.run(
        _redis.id,
        'GET cache:greeting',
        queryId: any(named: 'queryId'),
        page: QueryPage.first,
        cancelSignal: any(named: 'cancelSignal'),
      ),
    ).called(1);
  });

  group('copy', () {
    testWidgets('Copy value writes the pretty JSON through the sensitive clipboard only', (tester) async {
      answerRun('GET user:2:profile', () => Success(_recorded('query_redis_json')));
      await harness.pump(tester, location: _location('user:2:profile', type: 'string'));

      await tester.tap(find.byKey(const ValueKey('key-value-copy')));
      await tester.pumpAndSettle();

      expect(copied, ['{\n  "name": "Grace Hopper",\n  "languages": [\n    "en"\n  ],\n  "active": true\n}']);
      expect(plain, isEmpty);
      expect(find.widgetWithText(SnackBar, 'Copied'), findsOneWidget);
    });

    testWidgets('Ctrl+A then Ctrl+C goes through the sensitive clipboard only', (tester) async {
      answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
      await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

      await tester.tap(find.text('hello from db1'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(copied, ['hello from db1']);
      expect(plain, isEmpty);
    });

    testWidgets('a selection and the screen reader\'s Copy go through the sensitive clipboard only', (tester) async {
      final handle = tester.ensureSemantics();
      answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
      await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

      expect(find.descendant(of: text(), matching: find.byType(SensitiveSelectableText)), findsOneWidget);
      await tester.longPress(find.text('hello from db1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, ['hello from db1']);

      final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
      final nodes = <SemanticsNode>[];
      bool visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.hasAction(SemanticsAction.copy) && data.label == 'hello from db1') nodes.add(node);
        node.visitChildren(visit);
        return true;
      }

      visit(owner.rootSemanticsNode!);
      expect(nodes, hasLength(1));
      owner.performAction(nodes.single.id, SemanticsAction.copy);
      await tester.pumpAndSettle();

      expect(copied, ['hello from db1', 'hello from db1']);
      expect(plain, isEmpty);
      handle.dispose();
    });
  });

  group('a key without a type', () {
    testWidgets('runs TYPE only, then the typed read after the user\'s tap', (tester) async {
      answerRun('TYPE user:2', () => Success(_single('hash')));
      answerRun('HGETALL user:2', () => Success(_recorded('query_redis_hash')));
      await harness.pump(tester, location: _location('user:2'));

      expect(find.text("Studio says this key's type is hash."), findsOneWidget);
      expect(runsOf('TYPE user:2'), 1);
      verifyNever(
        () => harness.statements.run(
          _redis.id,
          'HGETALL user:2',
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          database: any(named: 'database'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      );

      await tester.tap(readValue());
      await tester.pumpAndSettle();

      expect(find.byType(ResultView), findsOneWidget);
      expect(find.textContaining('Grace Hopper'), findsWidgets);
      expect(runsOf('HGETALL user:2'), 1);
    });

    testWidgets('none says the key no longer exists and offers no read', (tester) async {
      answerRun('TYPE gone', () => Success(_single('none')));
      await harness.pump(tester, location: _location('gone'));

      expect(find.byKey(const ValueKey('key-value-vanished')), findsOneWidget);
      expect(readValue(), findsNothing);
    });

    testWidgets('a type outside the seven is shown with no read', (tester) async {
      answerRun('TYPE vec', () => Success(_single('vectorset')));
      await harness.pump(tester, location: _location('vec'));

      expect(find.text("Studio says this key's type is vectorset."), findsOneWidget);
      expect(find.text('The app has no read for this type.'), findsOneWidget);
      expect(readValue(), findsNothing);
    });

    testWidgets('offline, Read value is disabled with the reason', (tester) async {
      answerRun('TYPE user:2', () => Success(_single('hash')));
      await harness.pump(tester, location: _location('user:2'));

      await harness.setOffline(tester, true);

      expect(tester.widget<FilledButton>(readValue()).onPressed, isNull);
      expect(find.text('Needs an internet connection'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(OfflineStaleMarker), matching: find.byIcon(Icons.history)),
        findsOneWidget,
      );
    });
  });

  for (final marker in ['(nil)', '(empty list)']) {
    testWidgets('$marker with rowCount 0 says the key no longer exists, and a pull reads it again', (tester) async {
      var calls = 0;
      answerRun(
        'LRANGE session:2:events 0 -1',
        () => calls++ == 0 ? Success(_single(marker, rowCount: 0)) : Success(_recorded('query_redis_list')),
      );
      await harness.pump(tester, location: _location('session:2:events', type: 'list'));

      expect(find.byKey(const ValueKey('key-value-vanished')), findsOneWidget);
      expect(find.text(marker), findsNothing);

      await tester.fling(find.byKey(const ValueKey('key-value-vanished')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(ResultView), findsOneWidget);
      expect(runsOf('LRANGE session:2:events 0 -1'), 2);
    });
  }

  testWidgets('offline, a loaded value stays marked stale, and a pull sends nothing', (tester) async {
    answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

    await harness.setOffline(tester, true);

    expect(find.text('hello from db1'), findsOneWidget);
    expect(find.descendant(of: find.byType(OfflineStaleMarker), matching: find.byIcon(Icons.history)), findsOneWidget);
    await tester.fling(find.text('hello from db1'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SnackBar, 'No internet connection'), findsOneWidget);
    expect(runsOf('GET cache:greeting'), 1);
  });

  testWidgets('WRONGTYPE shows the banner with the database\'s words, and runs again only on a retry', (tester) async {
    var calls = 0;
    answerRun(
      'GET cache:greeting',
      () => calls++ == 0
          ? const Failure(
              ValidationError(
                'WRONGTYPE Operation against a key holding the wrong kind of value',
                code: 'studio.query_error',
              ),
            )
          : Success(_recorded('query_redis_string')),
    );
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.text('WRONGTYPE Operation against a key holding the wrong kind of value'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(runsOf('GET cache:greeting'), 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(StudioErrorBanner), findsNothing);
    expect(find.text('hello from db1'), findsOneWidget);
  });

  testWidgets('another failure shows the banner without the error\'s text', (tester) async {
    answerRun(
      'GET cache:greeting',
      () => const Failure(ServerError('connect ECONNREFUSED 10.0.0.1', code: 'studio.database_unreachable')),
    );
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.textContaining('ECONNREFUSED'), findsNothing);
  });

  testWidgets('a vanished connection goes to the active connection\'s vanish flow', (tester) async {
    harness.active.select(_redis);
    answerRun(
      'GET cache:greeting',
      () => const Failure(NotFoundError('gone', code: 'studio.connection_not_available')),
    );
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

    expect(harness.active.state, isA<ActiveConnectionVanished>());
  });

  testWidgets('a connection switch returns Browse to the new connection\'s first entry', (tester) async {
    answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));
    expect(find.byType(KeyValuePage), findsOneWidget);

    harness.active.select(_postgres);
    await tester.pumpAndSettle();

    expect(find.byType(KeyValuePage), findsNothing);
    expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');
  });

  testWidgets('the back arrow returns a page opened by a link to the Browse root', (tester) async {
    answerRun('GET cache:greeting', () => Success(_recorded('query_redis_string')));
    await harness.pump(tester, location: _location('cache:greeting', type: 'string'));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse');
    expect(find.byType(KeyValuePage), findsNothing);
  });

  testWidgets('an engine that is not Redis runs nothing and says so', (tester) async {
    await harness.pump(
      tester,
      location: _location('x', container: const ['public'], id: _postgres.id),
    );

    expect(find.text("Reading a key's value is not available for this engine."), findsOneWidget);
    verifyNever(
      () => harness.statements.run(
        any(),
        any(),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    );
  });

  testWidgets('a key holding /, a space, a quote and İ survives the round trip through browseKeyValue', (tester) async {
    const key = 'sales/eu "q1" İzmir';
    harness.active.select(_redis);
    answerRun(r'{"command":"GET","args":["sales/eu \"q1\" İzmir"]}', () => Success(_recorded('query_redis_string')));
    await harness.pump(tester);

    openBrowseKeyValue(tester.element(find.byType(Scaffold).first), _redis.id, const ['1'], key, type: 'string');
    await tester.pumpAndSettle();

    expect(harness.router.state.pathParameters['connectionId'], _redis.id);
    expect(harness.router.state.uri.queryParametersAll['path'], [key]);
    expect(harness.router.state.uri.queryParametersAll['container'], ['1']);
    expect(harness.router.state.uri.queryParameters['type'], 'string');
    expect(find.text(key), findsOneWidget);
    expect(find.text('hello from db1'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(KeyValuePage), findsNothing);
  });

  testWidgets('a link that names two keys opens no value page and runs nothing', (tester) async {
    await harness.pump(tester, location: '/browse/seed%3Adev-redis/value?container=1&path=a&path=b');

    expect(find.byType(KeyValuePage), findsNothing);
    verifyNever(
      () => harness.statements.run(
        any(),
        any(),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
      ),
    );
  });

  group('scrolling a loaded result', () {
    final platforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});
    const read = 'XRANGE events - + COUNT 100';
    final location = _location('events', type: 'stream');

    Future<void> showTable(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Table'));
      await tester.pumpAndSettle();
    }

    testWidgets('the cards settle at the first and the last row', (tester) async {
      answerRun(read, () => Success(wideResult()));
      await harness.pump(tester, location: location);
      // Offline a pull past the first row reads nothing, so the same list is measured at both ends.
      await harness.setOffline(tester, true);

      await expectSettlesAtEachEnd(tester, cardListScrollable());
    }, variant: platforms);

    testWidgets('the table settles at the first and the last row', (tester) async {
      answerRun(read, () => Success(wideResult()));
      await harness.pump(tester, location: location);
      await showTable(tester);
      await harness.setOffline(tester, true);

      await expectSettlesAtEachEnd(tester, tableRowsScrollable());
    }, variant: platforms);

    testWidgets('the table settles at the first and the last column', (tester) async {
      answerRun(read, () => Success(wideResult()));
      await harness.pump(tester, location: location);
      await showTable(tester);

      await expectSettlesAtEachEnd(tester, tableColumnsScrollable());
    }, variant: platforms);

    testWidgets('a pull on the cards springs back, offline', (tester) async {
      answerRun(read, () => Success(wideResult()));
      await harness.pump(tester, location: location);
      await harness.setOffline(tester, true);

      await pullAndExpectSpringBack(tester, cardListScrollable());
      expect(find.widgetWithText(SnackBar, 'No internet connection'), findsOneWidget);
      expect(runsOf(read), 1);
    }, variant: platforms);

    testWidgets('a one-row result on the cards still pulls to refresh, and springs back', (tester) async {
      answerRun(read, () => Success(wideResult(rows: 1, columns: 2)));
      await harness.pump(tester, location: location);

      await pullAndExpectSpringBack(tester, cardListScrollable());
      expect(runsOf(read), 2);
    }, variant: platforms);

    for (final (rows, name) in [(100, '100 rows'), (1, 'one row')]) {
      testWidgets('a pull on a table of $name refreshes once, and springs back', (tester) async {
        answerRun(read, () => Success(wideResult(rows: rows)));
        await harness.pump(tester, location: location);
        await showTable(tester);

        await pullAndExpectSpringBack(tester, tableRowsScrollable());
        expect(runsOf(read), 2);
      }, variant: platforms);
    }

    testWidgets('a sideways scroll of the table past either end refreshes nothing', (tester) async {
      answerRun(read, () => Success(wideResult()));
      await harness.pump(tester, location: location);
      await showTable(tester);

      await expectSettlesAtEachEnd(tester, tableColumnsScrollable());
      await tester.flingFrom(tester.getCenter(find.byType(ResultTable)), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(runsOf(read), 1);
    }, variant: platforms);
  });
}
