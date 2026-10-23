@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/top_bar/active_connection_title.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/container_level_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/kind_counts_page.dart';
import 'package:libredb_mobile/shared/models/object_container.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../browse_answers.dart';
import '../browse_harness.dart';

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');

void main() {
  late BrowseHarness harness;

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerCounts(_postgres.id, ['public'], countsAnswer('counts_postgres'));
    harness.answerMeta(_server.id, metaAnswer('meta_postgres_server'));
    harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
    harness.answerContainers(_server.id, ['app'], containersAnswer('containers_postgres_catalog'));
    harness.answerCounts(_server.id, ['app', 'public'], countsAnswer('counts_postgres'));
  });

  Finder backArrow() => find.byType(BackButton);

  /// Where the top bar's title names the active connection.
  Finder titleNaming(String name) => find.descendant(of: find.byType(ActiveConnectionTitle), matching: find.text(name));

  testWidgets('a container path whose names hold /, a space, ( and İ survives the round trip through browseKinds', (
    tester,
  ) async {
    const path = ['sales/eu (q1)', 'İzmir 2026'];
    harness.answerContainers(_server.id, path.sublist(0, 1), const [
      ObjectContainer(path: path, name: 'İzmir 2026', level: 1),
    ]);
    harness.answerCounts(_server.id, path, const {'table': KindCounted(2)});
    harness.active.select(_server);
    await harness.pump(tester);

    openBrowseKinds(tester.element(find.text('Databases')), _server.id, path);
    await tester.pumpAndSettle();

    expect(harness.router.state.pathParameters['connectionId'], _server.id);
    expect(harness.router.state.uri.queryParametersAll['container'], path);
    verify(() => harness.repository.counts(_server.id, container: path, refresh: false)).called(1);
    expect(find.text('İzmir 2026'), findsOneWidget);
  });

  testWidgets('an empty container path leaves the key out of the location', (tester) async {
    harness.answerMeta('seed:sample', metaAnswer('meta'));
    harness.answerCounts('seed:sample', const [], countsAnswer('counts'));
    harness.active.select(_server);
    await harness.pump(tester);

    openBrowseKinds(tester.element(find.text('Databases')), 'seed:sample', const []);
    await tester.pumpAndSettle();

    expect(harness.location, '/browse/seed%3Asample/kinds');
    verify(() => harness.repository.counts('seed:sample', container: const [], refresh: false)).called(1);
  });

  group('back arrow', () {
    testWidgets('is absent on /browse and present on every page below it, returning to the page under it', (
      tester,
    ) async {
      harness.active.select(_server);
      await harness.pump(tester);
      expect(backArrow(), findsNothing);

      await tester.tap(find.text('app'));
      await tester.pumpAndSettle();
      expect(backArrow(), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'the Browse tab stays the visible tab');

      await tester.tap(find.text('public'));
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Adev-postgres-server/kinds?container=app&container=public');
      expect(backArrow(), findsOneWidget);

      await tester.tap(backArrow());
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Adev-postgres-server/containers?container=app');

      await tester.tap(backArrow());
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/browse');
      expect(backArrow(), findsNothing);
    });

    testWidgets('each page left after a pop keeps its own container in the location and on rebuild', (tester) async {
      when(
        () => harness.repository.list(
          _server.id,
          container: const ['app', 'public'],
          kind: 'table',
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answered(objectsAnswer('list_postgres')));
      harness.active.select(_server);
      await harness.pump(tester);
      await tester.tap(find.text('app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('public'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Adev-postgres-server/objects/table?container=app&container=public');

      await tester.tap(backArrow());
      await tester.pumpAndSettle();
      // Going offline and back rebuilds the pages, which read their container from the route again.
      await harness.setOffline(tester, true);
      await harness.setOffline(tester, false);
      expect(harness.location, '/browse/seed%3Adev-postgres-server/kinds?container=app&container=public');
      expect(tester.widget<KindCountsPage>(find.byType(KindCountsPage)).container, ['app', 'public']);

      await tester.tap(backArrow());
      await tester.pumpAndSettle();
      await harness.setOffline(tester, true);
      await harness.setOffline(tester, false);
      expect(harness.location, '/browse/seed%3Adev-postgres-server/containers?container=app');
      expect(tester.widget<ContainerLevelPage>(find.byType(ContainerLevelPage)).parent, ['app']);

      await tester.tap(backArrow());
      await tester.pumpAndSettle();
      expect(harness.location, '/browse');
    });

    testWidgets('returns a page opened by a link with nothing under it to the Browse root', (tester) async {
      harness.active.select(_server);
      await harness.pump(tester, location: '/browse/seed%3Adev-postgres-server/containers?container=app');
      expect(find.text('Schemas'), findsOneWidget);

      await tester.tap(backArrow());
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse');
      expect(find.text('Databases'), findsOneWidget);
    });
  });

  testWidgets('every Browse location shows the active connection\'s title in the shell\'s top bar', (tester) async {
    harness.active.select(_server);
    await harness.pump(tester);
    expect(titleNaming(_server.name), findsOneWidget);

    await tester.tap(find.text('app'));
    await tester.pumpAndSettle();
    expect(titleNaming(_server.name), findsOneWidget);

    await tester.tap(find.text('public'));
    await tester.pumpAndSettle();
    expect(titleNaming(_server.name), findsOneWidget);
  });

  group('connection switch', () {
    testWidgets('from a deep page returns Browse to the new connection\'s first level, with nothing of the old one', (
      tester,
    ) async {
      harness.active.select(_postgres);
      await harness.pump(tester);
      expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');

      harness.active.select(_server);
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse');
      expect(find.text('Databases'), findsOneWidget);
      expect(find.text('archive'), findsOneWidget);
      expect(find.text('Schemas'), findsNothing);
      expect(find.text('public'), findsNothing);
      expect(find.text('Tables'), findsNothing);
      expect(titleNaming(_server.name), findsOneWidget);
      expect(backArrow(), findsNothing);
    });

    testWidgets('opens the new connection as a first entry, its session default included', (tester) async {
      harness.active.select(_server);
      await harness.pump(tester);
      await tester.tap(find.text('app'));
      await tester.pumpAndSettle();

      harness.active.select(_postgres);
      await tester.pumpAndSettle();

      expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');
      expect(find.text('Databases'), findsNothing);

      // Back to the first connection: its first entry starts again.
      harness.active.select(_server);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/browse');
      harness.active.select(_postgres);
      await tester.pumpAndSettle();
      expect(harness.location, '/browse/seed%3Adev-postgres/kinds?container=public');
    });
  });
}
