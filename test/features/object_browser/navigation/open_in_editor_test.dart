@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../browse_answers.dart';
import '../browse_harness.dart';

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev (PostgreSQL)', type: 'postgres');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');

const _tables = '/browse/seed%3Adev-postgres/objects/table?container=public';

/// 'Open in editor' hands the object's preview statement to the SQL tab as an open request, in memory, and sends
/// nothing to Studio: the editor's own Run, check and confirmation decide what runs.
void main() {
  late BrowseHarness harness;

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres'));
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres'));
    harness.answerMeta(_server.id, metaAnswer('meta_postgres_server'));
    harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
    harness.answerContainers(_server.id, ['app'], containersAnswer('containers_postgres_catalog'));
    when(
      () => harness.repository.list(
        _postgres.id,
        container: ['public'],
        kind: 'table',
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async => answered(objectsAnswer('list_postgres')));
    when(
      () => harness.repository.describe(
        _server.id,
        path: ['app', 'public', 'orders'],
        kind: 'table',
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async => answered(detailAnswer('describe_postgres_orders')));
    when(
      () => harness.repository.list(
        _server.id,
        container: ['app', 'public'],
        kind: 'table',
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer(
      (_) async => answered([
        for (final object in objectsAnswer('list_postgres'))
          DatabaseObject(path: ['app', ...object.path], name: object.name, kind: object.kind),
      ]),
    );
  });

  /// Forgets what loading the page asked, so a check after the tap sees only what the tap sent.
  void forgetLoading() {
    clearInteractions(harness.repository);
    clearInteractions(harness.statements);
  }

  void expectNothingSent() {
    verifyZeroInteractions(harness.repository);
    verifyZeroInteractions(harness.statements);
  }

  Future<void> openFromLongPress(WidgetTester tester, String name) async {
    await tester.longPress(find.text(name));
    await tester.pumpAndSettle();
    forgetLoading();
    await tester.tap(find.text('Open in editor'));
    await tester.pumpAndSettle();
  }

  testWidgets('on public.customers of seed:dev-postgres opens the SQL tab with its SELECT, no catalog, not run', (
    tester,
  ) async {
    await harness.pump(tester, location: _tables);

    await openFromLongPress(tester, 'customers');

    expect(harness.router.state.uri.path, ApplicationRoutesConstants.sql);
    expect(harness.router.state.uri.query, isEmpty, reason: 'the statement never travels in the location');
    expect(harness.editorRequests, [
      const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: 'SELECT * FROM public.customers;'),
    ]);
    expect(find.text('Open in editor'), findsNothing, reason: 'the menu closes');
    expectNothingSent();
  });

  testWidgets('on seed:dev-postgres-server, app.public.orders from its detail heading sets the catalog app', (
    tester,
  ) async {
    await harness.pump(
      tester,
      location: Uri(
        path: '/browse/${Uri.encodeComponent(_server.id)}/detail/table',
        queryParameters: {
          'path': ['app', 'public', 'orders'],
        },
      ).toString(),
    );
    forgetLoading();

    await tester.tap(find.widgetWithText(TextButton, 'Open in editor'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, ApplicationRoutesConstants.sql);
    expect(harness.editorRequests, [
      const EditorOpenRequest(
        connectionId: 'seed:dev-postgres-server',
        text: 'SELECT * FROM app.public.orders;',
        catalog: 'app',
      ),
    ]);
    expectNothingSent();
  });

  testWidgets('offline, it still opens the SQL tab with the statement', (tester) async {
    await harness.pump(tester, location: _tables, offline: true);

    await openFromLongPress(tester, 'orders');

    expect(harness.router.state.uri.path, ApplicationRoutesConstants.sql);
    expect(harness.editorRequests, [
      const EditorOpenRequest(connectionId: 'seed:dev-postgres', text: 'SELECT * FROM public.orders;'),
    ]);
    expectNothingSent();
  });
}
