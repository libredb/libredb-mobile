@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

const _sample = StudioConnection(id: 'seed:sample', name: 'Sample (SQLite)', type: 'sqlite');
const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');
const _mssql = StudioConnection(id: 'seed:mssql', name: 'MSSQL', type: 'mssql');

void main() {
  late BrowseHarness harness;

  setUp(() => harness = BrowseHarness());

  void answerPostgres() {
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
    harness.answerCounts(_postgres.id, ['sales'], const {'table': KindCounted(1)});
  }

  /// Opens [connection] as one whose first entry is already used, so its levels open nothing by themselves.
  Future<void> seen(WidgetTester tester, StudioConnection connection) async {
    harness.active.select(connection);
    // The entry hears of the switch on the cubit's stream, after this frame's microtasks.
    await tester.pump();
    harness.entry.take(connection.id, const [], const []);
  }

  /// The trailing text of the row of [label].
  Finder countOf(String label) =>
      find.descendant(of: find.widgetWithText(ListTile, label), matching: find.byType(Text)).last;

  testWidgets('asks the user to pick a connection while none is open', (tester) async {
    await harness.pump(tester);

    expect(find.byType(PickConnectionFirst), findsOneWidget);
  });

  testWidgets('asks for a connection again once the open one vanishes', (tester) async {
    answerPostgres();
    harness.active.select(_postgres);
    await harness.pump(tester);

    harness.active.connectionsListed(const []);
    await tester.pumpAndSettle();
    harness.router.go('/browse');
    await tester.pumpAndSettle();

    expect(find.byType(PickConnectionFirst), findsOneWidget);
  });

  group('first level', () {
    testWidgets('SQLite opens directly on its kinds, with no container level', (tester) async {
      harness.answerMeta(_sample.id, metaAnswer('meta'));
      harness.answerCounts(_sample.id, const [], countsAnswer('counts'));
      harness.active.select(_sample);

      await harness.pump(tester);

      expect(harness.location, '/browse');
      expect(find.text(S.current.browse_objects), findsOneWidget);
      expect(countOf('Tables'), isA<Finder>());
      expect(tester.widget<Text>(countOf('Tables')).data, '6');
      expect(tester.widget<Text>(countOf('Views')).data, '2');
      verifyNever(
        () => harness.repository.containers(
          any(),
          parent: any(named: 'parent'),
          refresh: any(named: 'refresh'),
        ),
      );
    });

    testWidgets('seed:dev-postgres-server shows its databases and then the schemas of the one tapped', (tester) async {
      harness.answerMeta(_server.id, metaAnswer('meta_postgres_server'));
      harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
      harness.answerContainers(_server.id, ['app'], containersAnswer('containers_postgres_catalog'));
      harness.answerCounts(_server.id, ['app', 'sales'], const {'table': KindCounted(3)});
      harness.active.select(_server);
      await harness.pump(tester);

      expect(find.text('Databases'), findsOneWidget);
      expect(find.text('archive'), findsOneWidget);
      expect(harness.location, '/browse', reason: 'no database is the session default');

      await tester.tap(find.text('app'));
      await tester.pumpAndSettle();

      expect(find.text('Schemas'), findsOneWidget);
      expect(harness.location, '/browse/seed%3Adev-postgres-server/containers?container=app');
      expect(find.text('Databases'), findsNothing);

      await tester.tap(find.text('sales'));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Adev-postgres-server/kinds?container=app&container=sales');
      expect(find.text('sales'), findsOneWidget);
      expect(find.text('Schema'), findsOneWidget);
      expect(tester.widget<Text>(countOf('Tables')).data, '3');
    });

    testWidgets('MSSQL shows two levels, opening the default database and schema on the first entry', (tester) async {
      harness.answerMeta(_mssql.id, metaAnswer('handwritten/mssql/meta'));
      harness.answerContainers(_mssql.id, null, containersAnswer('handwritten/mssql/containers_database'));
      harness.answerContainers(_mssql.id, ['app'], containersAnswer('handwritten/mssql/containers_schema'));
      harness.answerCounts(_mssql.id, ['app', 'dbo'], const {'table': KindCounted(5)});
      harness.active.select(_mssql);

      await harness.pump(tester);

      expect(harness.location, '/browse/seed%3Amssql/kinds?container=app&container=dbo');
      expect(find.text('dbo'), findsOneWidget);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Schemas'), findsOneWidget);
      expect(find.text('guest'), findsOneWidget);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Databases'), findsOneWidget);
      expect(find.text('tempdb'), findsOneWidget);
    });
  });

  group('session default', () {
    testWidgets('opens on the first entry only, not after the user goes back', (tester) async {
      answerPostgres();
      harness.active.select(_postgres);
      await harness.pump(tester);

      expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');
      expect(find.text('public'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse');
      expect(find.text('Schemas'), findsOneWidget);
      expect(find.text('sales'), findsOneWidget);

      // Opening the tab again for the same connection is no first entry either.
      harness.router.go('/connections');
      await tester.pumpAndSettle();
      harness.router.go('/browse');
      await tester.pumpAndSettle();
      expect(harness.location, '/browse');
      expect(find.text('Schemas'), findsOneWidget);
    });
  });

  group('kind screen', () {
    const vhost = ObjectContainer(path: ['/'], name: '/', level: 0);
    const meta = ProviderMeta(
      queryLanguage: 'json',
      schemaRefreshPattern: 'x',
      containerLevels: [ContainerLevel(id: 'schema', label: 'Virtual host', labelPlural: 'Virtual hosts')],
      objectKinds: [
        ObjectKind(id: 'queue', role: 'relation', label: 'Queue', labelPlural: 'Queues'),
        ObjectKind(
          id: 'stream',
          role: 'relation',
          label: 'Stream',
          labelPlural: 'Streams',
          countIsListing: true,
          group: ObjectKindGroup(id: 'streaming', label: 'Streaming'),
        ),
        ObjectKind(id: 'exchange', role: 'relation', label: 'Exchange', labelPlural: 'Exchanges'),
        ObjectKind(id: 'key', role: 'relation', label: 'Key', labelPlural: 'Keys', keyBrowserOnly: true),
      ],
    );
    const rabbit = StudioConnection(id: 'seed:rabbit', name: 'Rabbit', type: 'rabbitmq');

    setUp(() {
      harness.answerMeta(rabbit.id, meta);
      harness.answerContainers(rabbit.id, null, const [vhost]);
      harness.answerCounts(
        rabbit.id,
        ['/'],
        {...countsAnswer('handwritten/rabbitmq/counts'), 'key': const KindCounted(9)},
      );
      harness.active.select(rabbit);
    });

    testWidgets('shows a floor as n+, an exact count as it is and Studio\'s sentence for an unavailable one', (
      tester,
    ) async {
      await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F');

      expect(tester.widget<Text>(countOf('Queues')).data, '380+');
      expect(find.text('380'), findsNothing);
      expect(tester.widget<Text>(countOf('Exchanges')).data, '7');
      expect(find.textContaining('Other queue types fill this virtual host'), findsOneWidget);
    });

    for (final (locale, floor, exact) in [
      (const Locale('en'), '12,000+', '1,207'),
      (const Locale('tr'), '12.000+', '1.207'),
    ]) {
      testWidgets('groups each count and floor in the locale\'s way ($locale)', (tester) async {
        harness.answerCounts(
          rabbit.id,
          ['/'],
          const {'queue': KindCounted(12000, sampledFrom: 'one page'), 'exchange': KindCounted(1207)},
        );

        await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F', locale: locale);

        expect(tester.widget<Text>(countOf('Queues')).data, floor);
        expect(tester.widget<Text>(countOf('Exchanges')).data, exact);
      });
    }

    testWidgets('draws a kind under its group label and leaves out a kind only the key browser lists', (tester) async {
      await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F');

      expect(find.text('Streaming'), findsOneWidget);
      final streaming = tester.getTopLeft(find.text('Streaming')).dy;
      expect(tester.getTopLeft(find.text('Streams')).dy, greaterThan(streaming));
      expect(find.text('Keys'), findsNothing);
    });

    testWidgets('opens a kind\'s objects on a tap, with the container in the location', (tester) async {
      when(
        () => harness.repository.list(
          rabbit.id,
          container: ['/'],
          kind: 'queue',
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => const Success([]));
      await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F');

      await tester.tap(find.text('Queues'));
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Arabbit/objects/queue?container=%2F');
    });

    testWidgets('opens a countIsListing kind whose count Studio answered', (tester) async {
      harness.answerMeta(
        rabbit.id,
        const ProviderMeta(
          queryLanguage: 'json',
          schemaRefreshPattern: 'x',
          containerLevels: [ContainerLevel(id: 'schema', label: 'Virtual host', labelPlural: 'Virtual hosts')],
          objectKinds: [
            ObjectKind(id: 'queue', role: 'config', label: 'Queue', labelPlural: 'Queues', countIsListing: true),
          ],
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F');

      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Queues')).onTap, isNotNull);
    });

    testWidgets('opens a kind whose count Studio refused when the kind does not declare countIsListing', (
      tester,
    ) async {
      harness.answerMeta(
        rabbit.id,
        const ProviderMeta(
          queryLanguage: 'json',
          schemaRefreshPattern: 'x',
          containerLevels: [ContainerLevel(id: 'schema', label: 'Virtual host', labelPlural: 'Virtual hosts')],
          objectKinds: [ObjectKind(id: 'stream', role: 'relation', label: 'Stream', labelPlural: 'Streams')],
        ),
      );
      await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F');

      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Streams')).onTap, isNotNull);
    });

    testWidgets('carries no tap on a kind whose refused count is a refused listing', (tester) async {
      await harness.pump(tester, location: '/browse/seed%3Arabbit/kinds?container=%2F');

      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Streams')).onTap, isNull);
      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Exchanges')).onTap, isNotNull);
    });
  });

  group('offline', () {
    testWidgets('keeps a loaded level on screen marked stale, and a pull to refresh says the device is offline', (
      tester,
    ) async {
      answerPostgres();
      await seen(tester, _postgres);
      await harness.pump(tester);
      expect(find.text('Schemas'), findsOneWidget);

      await harness.setOffline(tester, true);

      expect(find.byType(OfflineStaleMarker), findsOneWidget);
      expect(find.textContaining('Offline: showing what was loaded at'), findsOneWidget);
      expect(find.text('public'), findsOneWidget);

      await tester.fling(find.text('Schemas'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBar, S.current.connectivity_offline), findsOneWidget);
      verifyNever(() => harness.repository.containers(_postgres.id, parent: null, refresh: true));
      expect(find.text('public'), findsOneWidget);
    });
  });

  group('failure', () {
    testWidgets('shows Studio\'s error with a retry that reads the level again', (tester) async {
      harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
      var calls = 0;
      when(() => harness.repository.containers(_postgres.id, parent: null, refresh: false)).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Failure(ServerError('down', code: 'studio.database_unreachable'))
            : Success(containersAnswer('containers_postgres'));
      });
      harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
      await seen(tester, _postgres);
      await harness.pump(tester);

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.text(S.current.error_studio_database_unreachable), findsOneWidget);

      await tester.tap(find.text(S.current.retry));
      await tester.pumpAndSettle();

      expect(find.byType(StudioErrorBanner), findsNothing);
      expect(find.text('Schemas'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the level under the error', (tester) async {
      answerPostgres();
      when(() => harness.repository.containers(_postgres.id, parent: null, refresh: true))
          .thenAnswer((_) async => const Failure(ServerError('down', code: 'studio.database_unreachable')));
      await seen(tester, _postgres);
      await harness.pump(tester);

      await tester.fling(find.text('Schemas'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.text('sales'), findsOneWidget);
    });

    testWidgets('hands studio.connection_not_available to the vanish flow, which closes Browse for the list', (
      tester,
    ) async {
      harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
      when(() => harness.repository.containers(_postgres.id, parent: null, refresh: false))
          .thenAnswer((_) async => const Failure(ServerError('gone', code: 'studio.connection_not_available')));
      harness.active.select(_postgres);
      await harness.pump(tester);

      expect(harness.active.state, const ActiveConnectionVanished(_postgres));
      expect(find.text(S.current.connection_vanished(_postgres.name)), findsOneWidget);
      expect(harness.location, '/connections');
    });
  });

  testWidgets('a schema change reloads the visible level', (tester) async {
    answerPostgres();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    await seen(tester, _postgres);
    await harness.pump(tester);
    expect(find.text('sales'), findsOneWidget);

    harness.answerContainers(_postgres.id, null, const [
      ObjectContainer(path: ['audit'], name: 'audit', level: 0),
    ]);
    await harness.schemaChanges.statementSucceeded(_postgres.id, 'CREATE SCHEMA audit');
    await tester.pumpAndSettle();

    expect(find.text('audit'), findsOneWidget);
    expect(find.text('sales'), findsNothing);
  });
}
