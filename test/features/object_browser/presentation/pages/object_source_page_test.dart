@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_source_view.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../browse_answers.dart';
import '../../browse_harness.dart';

const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev server', type: 'postgres');

void main() {
  late BrowseHarness harness;

  setUp(() {
    harness = BrowseHarness();
    harness.answerMeta(_server.id, metaAnswer('meta_postgres_server'));
    harness.answerContainers(_server.id, null, containersAnswer('containers_postgres_server'));
    harness.answerContainers(_server.id, ['app'], containersAnswer('containers_postgres_catalog'));
    harness.active.select(_server);
  });

  void answerSource(List<String> path, String kind, Result<ObjectSource> result) =>
      when(() => harness.repository.source(_server.id, path: path, kind: kind)).thenAnswer((_) async => result);

  const viewPath = ['app', 'sales', 'order_totals'];
  const viewLocation = '/browse/seed%3Adev-postgres-server/source/view?path=app&path=sales&path=order_totals';

  testWidgets('a link opens the source of the object it names, under the object\'s name', (tester) async {
    answerSource(viewPath, 'view', Success(sourceAnswer('source_postgres_view')));

    await harness.pump(tester, location: viewLocation);

    verify(() => harness.repository.source(_server.id, path: viewPath, kind: 'view')).called(1);
    expect(find.text('order_totals'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.byType(ObjectSourceView), findsOneWidget);
    expect(find.textContaining('LEFT JOIN order_items', findRichText: true), findsOneWidget);
  });

  testWidgets('the back arrow returns a page opened by a link to the Browse root', (tester) async {
    answerSource(viewPath, 'view', Success(sourceAnswer('source_postgres_view')));
    await harness.pump(tester, location: viewLocation);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/browse');
    expect(find.text('Databases'), findsOneWidget);
  });

  testWidgets('an object path whose names hold /, a space, ( , & and İ survives the round trip through browseSource', (
    tester,
  ) async {
    const path = ['sales/eu (q1)', 'İzmir & co', 'order_total(bigint)'];
    answerSource(path, 'function', Success(sourceAnswer('source_postgres_function')));
    await harness.pump(tester);

    openBrowseSource(tester.element(find.text('Databases')), _server.id, path, 'function');
    await tester.pumpAndSettle();

    expect(harness.router.state.pathParameters['connectionId'], _server.id);
    expect(harness.router.state.pathParameters['kind'], 'function');
    expect(harness.router.state.uri.queryParametersAll['path'], path);
    verify(() => harness.repository.source(_server.id, path: path, kind: 'function')).called(1);
    expect(find.text('order_total(bigint)'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/browse');
  });

  testWidgets('a failure shows in the Browse failure view, and a retry reads the source again', (tester) async {
    var calls = 0;
    when(() => harness.repository.source(_server.id, path: viewPath, kind: 'view')).thenAnswer(
      (_) async => calls++ == 0 ? const Failure(ServerError('down')) : Success(sourceAnswer('source_postgres_view')),
    );
    await harness.pump(tester, location: viewLocation);

    expect(find.byType(BrowseFailureView), findsOneWidget);
    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.byType(ObjectSourceView), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(BrowseFailureView), findsNothing);
    expect(find.byType(ObjectSourceView), findsOneWidget);
    verify(() => harness.repository.source(_server.id, path: viewPath, kind: 'view')).called(2);
  });

  testWidgets('a vanished connection goes to the active connection\'s vanish flow', (tester) async {
    answerSource(viewPath, 'view', const Failure(ServerError('gone', code: 'studio.connection_not_available')));

    await harness.pump(tester, location: viewLocation);

    expect(harness.active.state, isA<ActiveConnectionVanished>());
  });
}
