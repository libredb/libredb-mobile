@Tags(['widget'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/browse_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_detail_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_source_view.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

/// A server-level connection, whose Browse root lists its databases and opens none by itself.
const _postgres = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');
const _documents = 'seed:documents';

ObjectDetail _handwritten(String name) =>
    ObjectBrowserJson.detail(File('test/fixtures/studio/handwritten/$name.json').readAsStringSync());

/// A document engine with one collection kind that has columns and no source, for the hand-written answers of engines
/// whose provider-meta no fixture records.
const _documentMeta = ProviderMeta(
  queryLanguage: 'json',
  schemaRefreshPattern: '',
  containerLevels: [],
  objectKinds: [
    ObjectKind(id: 'collection', role: 'relation', label: 'Collection', labelPlural: 'Collections', hasColumns: true),
  ],
);

/// The recorded tables of the public schema, as the server-level connection lists them, under its database `app`.
List<DatabaseObject> _tables() => [
  for (final object in objectsAnswer('list_postgres'))
    DatabaseObject(path: ['app', ...object.path], name: object.name, kind: object.kind, sizeBytes: object.sizeBytes),
];

String _location(String connectionId, String kind, List<String> path) =>
    Uri(path: '/browse/${Uri.encodeComponent(connectionId)}/detail/$kind', queryParameters: {'path': path}).toString();

void main() {
  late BrowseHarness harness;

  const orders = ['app', 'public', 'orders'];
  const customersPath = ['app', 'public', 'customers'];
  final ordersLocation = _location(_postgres.id, 'table', orders);

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_postgres.id, metaAnswer('meta_postgres_server'));
    harness.answerMeta(_documents, _documentMeta);
    harness.answerContainers(_postgres.id, null, containersAnswer('containers_postgres_server'));
    harness.answerContainers(_postgres.id, ['app'], containersAnswer('containers_postgres_catalog'));
    harness.active.select(_postgres);
  });

  void answerDescribe(String connectionId, List<String> path, String kind, Result<ObjectDetail> Function() answer) =>
      when(
        () => harness.repository.describe(
          connectionId,
          path: path,
          kind: kind,
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async => answer());

  void answerList(String kind, List<DatabaseObject> objects) => when(
    () => harness.repository.list(
      _postgres.id,
      container: ['app', 'public'],
      kind: kind,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => Success(objects));

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
  }

  group('the recorded orders table', () {
    setUp(() {
      answerDescribe(_postgres.id, orders, 'table', () => Success(detailAnswer('describe_postgres_orders')));
      answerList('table', _tables());
    });

    testWidgets('shows its name under the kind, and the tabs of a kind without source', (tester) async {
      await harness.pump(tester, location: ordersLocation);

      expect(find.byType(ObjectDetailPage), findsOneWidget);
      expect(find.text('orders'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Columns'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Indexes'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Foreign keys'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Source'), findsNothing);
    });

    testWidgets('the Columns tab marks the primary key, the declared type, nullable and the default', (tester) async {
      final semantics = tester.ensureSemantics();
      await harness.pump(tester, location: ordersLocation);

      expect(find.bySemanticsLabel(RegExp('^Primary key')), findsOneWidget);
      semantics.dispose();
      final idRow = find.ancestor(of: find.text('id'), matching: find.byType(ListTile));
      expect(find.descendant(of: idRow, matching: find.byIcon(Icons.key)), findsOneWidget);
      final customerRow = find.ancestor(of: find.text('customer_id'), matching: find.byType(ListTile));
      expect(find.descendant(of: customerRow, matching: find.byIcon(Icons.key)), findsNothing);
      expect(find.descendant(of: customerRow, matching: find.text('Nullable')), findsNothing);
      expect(find.text('numeric(20,2)'), findsOneWidget, reason: 'the declaration, not the base name numeric');
      final totalRow = find.ancestor(of: find.text('total'), matching: find.byType(ListTile));
      expect(find.descendant(of: totalRow, matching: find.text('Nullable')), findsOneWidget);
      expect(find.text("Default: 'new'::text"), findsOneWidget);
      expect(find.text('Columns inferred from sampled documents'), findsNothing);
    });

    testWidgets('the Indexes tab lists both indexes and marks the unique one', (tester) async {
      await harness.pump(tester, location: ordersLocation);
      await openTab(tester, 'Indexes');

      expect(find.text('orders_pkey'), findsOneWidget);
      expect(find.text('orders_customer_id_idx'), findsOneWidget);
      final pkey = find.ancestor(of: find.text('orders_pkey'), matching: find.byType(ListTile));
      expect(find.descendant(of: pkey, matching: find.text('Unique')), findsOneWidget);
      final byCustomer = find.ancestor(of: find.text('orders_customer_id_idx'), matching: find.byType(ListTile));
      expect(find.descendant(of: byCustomer, matching: find.text('Unique')), findsNothing);
      expect(find.text('Exclusion constraints'), findsNothing);
    });

    testWidgets('the customer_id foreign key opens customers, and back returns to orders', (tester) async {
      answerDescribe(
        _postgres.id,
        customersPath,
        'table',
        () => Success(detailAnswer('describe_postgres_orders_readonly')),
      );
      await harness.pump(tester, location: ordersLocation);
      await openTab(tester, 'Foreign keys');

      expect(find.text('customer_id'), findsOneWidget);
      expect(find.text('References customers.id'), findsOneWidget);
      await tester.tap(find.text('References customers.id'));
      await tester.pumpAndSettle();

      expect(harness.router.state.name, BrowseRouteNames.detail);
      expect(harness.router.state.pathParameters['kind'], 'table');
      expect(harness.router.state.uri.queryParametersAll['path'], customersPath);
      expect(find.text('customers'), findsOneWidget);
      verify(() => harness.repository.describe(_postgres.id, path: customersPath, kind: 'table', refresh: false))
          .called(1);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.queryParametersAll['path'], orders);
      expect(find.text('orders'), findsOneWidget);
    });

    testWidgets('the back arrow returns a detail opened by a link to the Browse root', (tester) async {
      await harness.pump(tester, location: ordersLocation);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/browse');
      expect(find.text('Databases'), findsOneWidget);
    });
  });

  testWidgets('a foreign key whose table the container does not list is plain text', (tester) async {
    answerDescribe(_postgres.id, orders, 'table', () => Success(detailAnswer('describe_postgres_orders')));
    answerList('table', _tables().where((object) => object.name != 'customers').toList());
    for (final kind in ['view', 'materialized_view', 'sequence']) {
      answerList(kind, const []);
    }
    await harness.pump(tester, location: ordersLocation);
    await openTab(tester, 'Foreign keys');

    final row = find.ancestor(of: find.text('References customers.id'), matching: find.byType(ListTile));
    expect(tester.widget<ListTile>(row).onTap, isNull);
    expect(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)), findsNothing);
  });

  testWidgets('the read-only answer, without keys, shows no key and says there is no foreign key', (tester) async {
    answerDescribe(_postgres.id, orders, 'table', () => Success(detailAnswer('describe_postgres_orders_readonly')));
    await harness.pump(tester, location: ordersLocation);

    expect(find.byIcon(Icons.key), findsNothing);
    await openTab(tester, 'Foreign keys');
    expect(find.text('No foreign keys'), findsOneWidget);
  });

  group('the sampled caption', () {
    testWidgets('shows over the columns of the Firestore collection, beside each sampled type', (tester) async {
      answerDescribe(
        _documents,
        ['customers'],
        'collection',
        () => Success(_handwritten('firestore/describe_collection')),
      );
      await harness.pump(tester, location: _location(_documents, 'collection', ['customers']));

      expect(find.text('Columns inferred from sampled documents'), findsOneWidget);
      expect(find.text('mixed(double|integer) (sampled)'), findsOneWidget);
      expect(find.text('reference'), findsOneWidget, reason: "a document's name is not sampled");
    });

    testWidgets('does not show on the MongoDB collection, which Studio marks unsampled', (tester) async {
      const path = ['app', 'customers'];
      answerDescribe(_documents, path, 'collection', () => Success(_handwritten('mongodb/describe_collection')));
      await harness.pump(tester, location: _location(_documents, 'collection', path));

      expect(find.text('email'), findsOneWidget);
      expect(find.text('Columns inferred from sampled documents'), findsNothing);
      expect(find.textContaining('(sampled)'), findsNothing);
    });
  });

  testWidgets('an index list the engine could not read shows Studio\'s sentence', (tester) async {
    const path = ['analytics', 'events'];
    final detail = _handwritten('clickhouse/describe_indexes_unavailable');
    answerDescribe(_documents, path, 'collection', () => Success(detail));
    await harness.pump(tester, location: _location(_documents, 'collection', path));
    await openTab(tester, 'Indexes');

    expect(find.text(detail.indexesUnavailable!), findsOneWidget);
    expect(find.text('No indexes'), findsNothing);
  });

  testWidgets('the exclusion constraint shows on the Indexes tab, after the indexes, in monospace', (tester) async {
    const path = ['app', 'public', 'reservations'];
    final detail = _handwritten('postgres/describe_exclusion');
    answerDescribe(_postgres.id, path, 'table', () => Success(detail));
    await harness.pump(tester, location: _location(_postgres.id, 'table', path));
    await openTab(tester, 'Indexes');

    final constraint = detail.exclusionConstraints.single;
    expect(find.text('Exclusion constraints'), findsOneWidget);
    final definition = find.text(constraint.definition);
    expect(definition, findsOneWidget);
    expect(tester.widget<Text>(definition).style?.fontFamily, 'monospace');
    expect(find.text(constraint.name), findsWidgets, reason: 'the constraint and its backing index share the name');
    expect(
      tester.getTopLeft(find.text('reservations_pkey')).dy,
      lessThan(tester.getTopLeft(find.text('Exclusion constraints')).dy),
    );
  });

  group('a view, whose kind has source', () {
    const view = ['app', 'public', 'order_totals'];
    final viewLocation = _location(_postgres.id, 'view', view);

    setUp(() {
      answerDescribe(_postgres.id, view, 'view', () => Success(detailAnswer('describe_postgres_orders_readonly')));
      when(() => harness.repository.source(_postgres.id, path: view, kind: 'view'))
          .thenAnswer((_) async => Success(sourceAnswer('source_postgres_view')));
    });

    testWidgets('has a Source tab that embeds the viewer, read only once the tab opens', (tester) async {
      await harness.pump(tester, location: viewLocation);

      expect(find.widgetWithText(Tab, 'Source'), findsOneWidget);
      verifyNever(
        () => harness.repository.source(
          any(),
          path: any(named: 'path'),
          kind: any(named: 'kind'),
        ),
      );

      await openTab(tester, 'Source');

      expect(find.byType(ObjectSourceView), findsOneWidget);
      expect(find.textContaining('LEFT JOIN order_items', findRichText: true), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Details'), findsNothing, reason: 'the tab is the detail page itself');

      await openTab(tester, 'Columns');
      await openTab(tester, 'Source');
      verify(() => harness.repository.source(_postgres.id, path: view, kind: 'view')).called(1);
    });

    testWidgets('its Source page opens its detail, and back returns to the source', (tester) async {
      final sourceLocation = Uri(
        path: '/browse/${Uri.encodeComponent(_postgres.id)}/source/view',
        queryParameters: {'path': view},
      ).toString();
      await harness.pump(tester, location: sourceLocation);

      await tester.tap(find.widgetWithText(TextButton, 'Details'));
      await tester.pumpAndSettle();

      expect(harness.router.state.name, BrowseRouteNames.detail);
      expect(harness.router.state.uri.queryParametersAll['path'], view);
      expect(find.widgetWithText(Tab, 'Columns'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(harness.router.state.name, BrowseRouteNames.source);
      expect(harness.router.state.uri.queryParametersAll['path'], view);
    });
  });

  testWidgets('the Source page of a kind without columns offers no detail', (tester) async {
    const function = ['app', 'public', 'order_total'];
    when(() => harness.repository.source(_postgres.id, path: function, kind: 'function'))
        .thenAnswer((_) async => Success(sourceAnswer('source_postgres_function')));
    await harness.pump(
      tester,
      location: '/browse/seed%3Adev-postgres-server/source/function?path=app&path=public&path=order_total',
    );

    expect(find.byType(ObjectSourceView), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Details'), findsNothing);
  });

  testWidgets('a failure shows in the Browse failure view, and a retry describes again', (tester) async {
    var calls = 0;
    answerDescribe(
      _postgres.id,
      orders,
      'table',
      () => calls++ == 0 ? const Failure(ServerError('down')) : Success(detailAnswer('describe_postgres_orders')),
    );
    answerList('table', _tables());
    await harness.pump(tester, location: ordersLocation);

    expect(find.byType(BrowseFailureView), findsOneWidget);
    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.text('orders'), findsOneWidget, reason: 'the heading names the object from its route');

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(BrowseFailureView), findsNothing);
    expect(find.text('customer_id'), findsOneWidget);
  });

  testWidgets('a vanished connection goes to the active connection\'s vanish flow', (tester) async {
    answerDescribe(
      _postgres.id,
      orders,
      'table',
      () => const Failure(ServerError('gone', code: 'studio.connection_not_available')),
    );

    await harness.pump(tester, location: ordersLocation);

    expect(harness.active.state, isA<ActiveConnectionVanished>());
  });

  testWidgets('an object path whose names hold /, a space, ( , & and İ survives the round trip through browseDetail', (
    tester,
  ) async {
    const path = ['sales/eu (q1)', 'İzmir & co'];
    answerDescribe(_postgres.id, path, 'table', () => Success(detailAnswer('describe_postgres_orders_readonly')));
    await harness.pump(tester);

    openBrowseDetail(tester.element(find.byType(BrowsePage)), _postgres.id, path, 'table');
    await tester.pumpAndSettle();

    expect(harness.router.state.pathParameters['connectionId'], _postgres.id);
    expect(harness.router.state.uri.queryParametersAll['path'], path);
    verify(() => harness.repository.describe(_postgres.id, path: path, kind: 'table', refresh: false)).called(1);
    expect(find.text('İzmir & co'), findsOneWidget);
  });
}
